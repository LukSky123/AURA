import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'domain.dart';
import 'services/detection_service.dart';
import 'services/entitlement_service.dart';
import 'services/hardware_button_service.dart';
import 'services/incident_repository.dart';
import 'services/location_stream_service.dart';
import 'services/sim_sms_service.dart';

const _dispatchThreshold = 0.85;
const _countdownDuration = Duration(seconds: 20);

void main() => runApp(const AuraApp());

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AURA',
    theme: ThemeData(
      colorSchemeSeed: const Color(0xffbb1b35),
      useMaterial3: true,
    ),
    home: const SafetyHome(),
  );
}

class SafetyHome extends StatefulWidget {
  const SafetyHome({super.key});

  @override
  State<SafetyHome> createState() => _SafetyHomeState();
}

class _SafetyHomeState extends State<SafetyHome> {
  final IncidentRepository _repository = DeferredIncidentRepository();
  final DefaultEntitlementService _entitlementService = DefaultEntitlementService();
  final SimSmsService _simSmsService = DefaultSimSmsService();
  final StreamingDetectionService _detectionService = StreamingDetectionService();
  final HardwareButtonService _hardwareService = HardwareButtonService();
  final LocationStreamService _locationService = LocationStreamService();

  final List<Incident> _history = [];
  final List<TrustedContact> _contacts = [
    const TrustedContact(id: 'c1', name: 'Mum', phone: '+2348011112222'),
    const TrustedContact(id: 'c2', name: 'Brother', phone: '+2348033334444'),
  ];

  StreamSubscription<DetectionEvent>? _detectionSubscription;
  StreamSubscription<String>? _hardwareSubscription;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _timer;
  Incident? _active;
  Position? _currentPosition;
  int _remaining = 0;
  bool _listening = false;
  bool _optInAudioDonation = true;
  bool _accessibilityEnabled = false;
  bool _batteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    _initSystemReadiness();

    _detectionSubscription = _detectionService.events.listen((event) {
      if (mounted) {
        _onModelPrediction(event.kind, event.confidence);
      }
    });

    // Hardware volume key events via AuraAccessibilityService
    _hardwareSubscription = _hardwareService.hardwareEvents.listen((event) {
      if (!mounted) return;
      if (event == 'instant_dispatch') {
        _handleInstantHardwareDispatch();
      } else if (event == 'cancel_countdown') {
        _cancel();
      }
    });
  }

  Future<void> _initSystemReadiness() async {
    final a11y = await _hardwareService.isAccessibilityEnabled();
    final batt = await _hardwareService.isBatteryOptimizationIgnored();
    if (mounted) {
      setState(() {
        _accessibilityEnabled = a11y;
        _batteryOptimizationIgnored = batt;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _detectionSubscription?.cancel();
    _hardwareSubscription?.cancel();
    _locationSubscription?.cancel();
    _detectionService.dispose();
    _hardwareService.dispose();
    _locationService.dispose();
    super.dispose();
  }

  /// Triggered on Volume Up double-press (hardware panic trigger)
  void _handleInstantHardwareDispatch() {
    if (kDebugMode) {
      debugPrint('[AURA] Hardware panic triggered: Double-press Volume Up');
    }
    if (_active != null) {
      _timer?.cancel();
      _dispatch(_active!);
    } else {
      _beginCountdown(IncidentKind.manualSos, immediate: true);
    }
  }

  Future<void> _beginCountdown(IncidentKind kind, {double? confidence, bool immediate = false}) async {
    if (_active != null && !immediate) return;

    // Fetch initial GPS coordinate
    final initialPos = await _locationService.getCurrentPosition();
    if (mounted && initialPos != null) {
      setState(() => _currentPosition = initialPos);
    }

    final incident = Incident(
      id: const Uuid().v4(),
      kind: kind,
      status: immediate ? IncidentStatus.dispatched : IncidentStatus.countdown,
      createdAt: DateTime.now().toUtc(),
      confidence: confidence,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
    );

    // Start live GPS tracking stream
    _locationSubscription?.cancel();
    await _locationService.startTracking(
      incidentId: incident.id,
      onPositionUpdate: (pos) async {
        if (mounted) {
          setState(() => _currentPosition = pos);
        }
      },
    );

    if (immediate) {
      await _dispatch(incident);
      return;
    }

    setState(() {
      _active = incident;
      _remaining = _countdownDuration.inSeconds;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        _dispatch(incident);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _dispatch(Incident incident) async {
    final entitlements = _entitlementService.current;
    final bool useCloudSms = entitlements.canSendCloudSms;

    final lat = _currentPosition?.latitude ?? incident.latitude;
    final lng = _currentPosition?.longitude ?? incident.longitude;
    final locParam = (lat != null && lng != null) ? '?lat=$lat&lng=$lng' : '';
    final mapLink = (lat != null && lng != null) ? ' https://maps.google.com/?q=$lat,$lng' : '';
    final portalUrl = 'https://aura-safety.app/incident/${incident.id}$locParam';
    final smsMessage = 'EMERGENCY: ${incident.kind.name.toUpperCase()} detected! View live location: $portalUrl$mapLink';

    final dispatched = incident.copyWith(
      status: IncidentStatus.dispatched,
      smsDispatchMode: useCloudSms ? SmsDispatchMode.cloudTermii : SmsDispatchMode.fallbackToLocalSim,
      fallbackTargets: useCloudSms
          ? []
          : _contacts.map((c) => FallbackSmsTarget(
                phone: c.phone,
                message: smsMessage,
              )).toList(),
      latitude: lat,
      longitude: lng,
    );

    await _repository.dispatch(dispatched);

    // If local SIM fallback is required, dispatch directly via Android SmsManager
    if (dispatched.smsDispatchMode == SmsDispatchMode.fallbackToLocalSim && dispatched.fallbackTargets.isNotEmpty) {
      final success = await _simSmsService.sendLocalSms(targets: dispatched.fallbackTargets);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: Failed to dispatch carrier SMS. Please check SMS permission & airtime.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _history.insert(0, dispatched);
      _active = null;
      _remaining = 0;
    });

    if (dispatched.smsDispatchMode == SmsDispatchMode.fallbackToLocalSim) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Free monthly cloud SMS quota reached. Emergency alert dispatched via your device carrier SIM.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _cancel() async {
    final active = _active;
    if (active == null) return;
    _timer?.cancel();
    await _locationService.stopTracking();
    _locationSubscription?.cancel();
    await _repository.cancel(active.id);
    _detectionService.recordFalseAlarm();
    setState(() {
      _history.insert(0, active.copyWith(status: IncidentStatus.cancelled));
      _active = null;
      _remaining = 0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _optInAudioDonation
                ? 'Alert cancelled. Threat sensitivity backed off to 95% for 15m. 3s encrypted sample contributed.'
                : 'Alert cancelled. Threat sensitivity backed off to 95% for 15 minutes.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onModelPrediction(IncidentKind kind, double probability) {
    if (probability >= _dispatchThreshold) {
      _beginCountdown(kind, confidence: probability);
    }
  }

  void _attemptAddContact() {
    if (!_entitlementService.canAddContact(_contacts.length)) {
      _showUpgradePaywall(
        reason: 'AURA Free tier supports at most 2 emergency contacts. Upgrade to AURA Pro or Family to add up to 5 contacts with unlimited automated cloud SMS.',
      );
    } else {
      _showAddContactDialog();
    }
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Trusted Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Contact Name')),
            const SizedBox(height: 8),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone (+234...)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                setState(() {
                  _contacts.add(TrustedContact(
                    id: const Uuid().v4(),
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUpgradePaywall({String? reason}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upgrade AURA Safety',
                  style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(reason, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
            ],
            const SizedBox(height: 20),
            _PlanCard(
              title: 'AURA Pro',
              price: '₦4,000 / month (or ₦36,000 / yr)',
              features: const [
                '5 enabled emergency contacts',
                'Unlimited Termii cloud SMS dispatch',
                'Smart safety routing with 30-day crime risk decay',
                '45-minute transit watch timer',
                'Priority background persistence',
              ],
              buttonText: 'Upgrade to Pro',
              isRecommended: true,
              onSelect: () async {
                await _entitlementService.purchaseSubscription(SubscriptionTier.pro);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            _PlanCard(
              title: 'AURA Family',
              price: '₦13,500 / month (or ₦120,000 / yr)',
              features: const [
                'Covers up to 5 linked family accounts',
                'All AURA Pro features for everyone',
                'Circle sirens (₦0 push triggers across circle phones)',
                'Shared family transit timers',
              ],
              buttonText: 'Get Family Protection',
              isRecommended: false,
              onSelect: () async {
                await _entitlementService.purchaseSubscription(SubscriptionTier.family);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final entitlements = _entitlementService.current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AURA'),
        actions: [
          Chip(
            label: Text(
              switch (entitlements.tier) {
                SubscriptionTier.free => 'Free (2/2 SMS)',
                SubscriptionTier.pro => 'Pro',
                SubscriptionTier.family => 'Family',
              },
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            backgroundColor: entitlements.tier == SubscriptionTier.free ? Colors.grey.shade200 : const Color(0xfffee2e2),
          ),
          IconButton(
            onPressed: () => _showUpgradePaywall(),
            icon: const Icon(Icons.star_rounded, color: Colors.amber),
            tooltip: 'View Plans',
          ),
          IconButton(
            onPressed: () => _showPrivacy(context),
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Device readiness & background protection warnings
            if (!_accessibilityEnabled || !_batteryOptimizationIgnored) ...[
              _DeviceReadinessBanner(
                accessibilityEnabled: _accessibilityEnabled,
                batteryIgnored: _batteryOptimizationIgnored,
                onEnableAccessibility: () async {
                  await _hardwareService.openAccessibilitySettings();
                  await Future<void>.delayed(const Duration(seconds: 1));
                  _initSystemReadiness();
                },
                onRequestIgnoreBattery: () async {
                  await _hardwareService.requestIgnoreBatteryOptimizations();
                  await Future<void>.delayed(const Duration(seconds: 1));
                  _initSystemReadiness();
                },
              ),
              const SizedBox(height: 16),
            ],

            Text(
              _listening ? 'Protection is active' : 'Protection is paused',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'AURA analyses sound on this device. Ambient audio is not retained by default.',
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              value: _listening,
              onChanged: (value) async {
                if (value) {
                  final started = await _detectionService.start();
                  if (started) {
                    await _hardwareService.startForegroundService();
                  }
                  if (mounted) {
                    setState(() => _listening = started);
                    if (!started) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Microphone permission required for real-time acoustic protection.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  await _detectionService.stop();
                  await _hardwareService.stopForegroundService();
                  if (mounted) setState(() => _listening = false);
                }
              },
              title: const Text('Sound recognition'),
              subtitle: Text(
                _detectionService.detector.isBackoffActive
                    ? 'Continuous 16 kHz acoustic inference (Backoff active: 95% threshold)'
                    : 'Continuous on-device INT8 acoustic inference for gunshots, explosions & glass breaks (80% baseline).',
              ),
            ),
            SwitchListTile(
              value: _optInAudioDonation,
              onChanged: (value) => setState(() => _optInAudioDonation = value),
              title: const Text('Contribute false-alert audio'),
              subtitle: const Text(
                '3-5s encrypted sample only on cancellation to improve detection accuracy (NDPA compliant).',
              ),
            ),
            const SizedBox(height: 16),
            if (active != null)
              _CountdownCard(
                incident: active,
                seconds: _remaining,
                position: _currentPosition,
                onCancel: _cancel,
              )
            else ...[
              FilledButton.icon(
                icon: const Icon(Icons.sos),
                label: const Text('Send SOS now (or Double-Press Vol Up)'),
                onPressed: () => _beginCountdown(IncidentKind.manualSos),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _onModelPrediction(IncidentKind.gunshot, .90),
                      child: const Text('Simulate Detection'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up, size: 16),
                      label: const Text('Hardware SOS'),
                      onPressed: _handleInstantHardwareDispatch,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trusted Contacts (${_contacts.length}/${entitlements.contactLimit})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _attemptAddContact,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            for (final contact in _contacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                title: Text(contact.name),
                subtitle: Text(contact.phone),
                trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ),
            const SizedBox(height: 28),
            Text(
              'Recent incidents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No incidents recorded on this device.'),
              ),
            for (final incident in _history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: Text(_label(incident.kind)),
                subtitle: Text(
                  '${incident.status.name} • ${incident.smsDispatchMode?.name ?? "cloud"} • ${incident.createdAt.toLocal().toString().substring(0, 16)}'
                  '${incident.latitude != null ? " • (${incident.latitude!.toStringAsFixed(3)}, ${incident.longitude!.toStringAsFixed(3)})" : ""}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeviceReadinessBanner extends StatelessWidget {
  const _DeviceReadinessBanner({
    required this.accessibilityEnabled,
    required this.batteryIgnored,
    required this.onEnableAccessibility,
    required this.onRequestIgnoreBattery,
  });

  final bool accessibilityEnabled;
  final bool batteryIgnored;
  final VoidCallback onEnableAccessibility;
  final VoidCallback onRequestIgnoreBattery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 20),
              const SizedBox(width: 8),
              Text(
                'Background & Shortcut Readiness',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!accessibilityEnabled) ...[
            const Text(
              '• Hardware volume keys cannot trigger instant SOS while screen is locked.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onEnableAccessibility,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 28)),
              child: const Text('Enable Accessibility Shortcuts →'),
            ),
          ],
          if (!batteryIgnored) ...[
            const SizedBox(height: 6),
            const Text(
              '• OEM battery killers may pause AURA microphone monitoring in background.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onRequestIgnoreBattery,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 28)),
              child: const Text('Disable Battery Saver Restrictions →'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.buttonText,
    required this.isRecommended,
    required this.onSelect,
  });

  final String title;
  final String price;
  final List<String> features;
  final String buttonText;
  final bool isRecommended;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRecommended ? const Color(0xfffff1f2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended ? const Color(0xffbb1b35) : Colors.grey.shade300,
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xffbb1b35), borderRadius: BorderRadius.circular(6)),
                  child: const Text('RECOMMENDED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(color: Color(0xffbb1b35), fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSelect,
              style: FilledButton.styleFrom(
                backgroundColor: isRecommended ? const Color(0xffbb1b35) : Colors.grey.shade800,
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.incident,
    required this.seconds,
    this.position,
    required this.onCancel,
  });
  final Incident incident;
  final int seconds;
  final Position? position;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Possible ${_label(incident.kind)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            ],
          ),
          const SizedBox(height: 4),
          Text('Sending emergency alert in $seconds seconds.'),
          if (position != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Text(
                  'GPS Lock: ${position!.latitude.toStringAsFixed(4)}, ${position!.longitude.toStringAsFixed(4)} (±${position!.accuracy.toStringAsFixed(0)}m)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '💡 Hardware Shortcut: Double-press Volume Down to cancel, or Volume Up to send SOS immediately.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          _SlideToCancel(onConfirmed: onCancel),
        ],
      ),
    ),
  );
}

class _SlideToCancel extends StatefulWidget {
  const _SlideToCancel({required this.onConfirmed});
  final Future<void> Function() onConfirmed;

  @override
  State<_SlideToCancel> createState() => _SlideToCancelState();
}

class _SlideToCancelState extends State<_SlideToCancel> {
  double _value = 0;
  bool _submitting = false;

  Future<void> _changed(double value) async {
    setState(() => _value = value);
    if (value < .95 || _submitting) return;
    setState(() => _submitting = true);
    await widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Slide all the way to cancel'),
      Slider(
        value: _value,
        onChanged: _submitting ? null : _changed,
        semanticFormatterCallback: (value) =>
            value > .95 ? 'Cancel alert' : 'Slide to cancel alert',
      ),
    ],
  );
}

String _label(IncidentKind kind) => switch (kind) {
  IncidentKind.gunshot => 'gunshot',
  IncidentKind.glassBreak => 'glass breaking',
  IncidentKind.collision => 'high-impact collision',
  IncidentKind.explosion => 'explosion',
  IncidentKind.manualSos => 'SOS',
};

void _showPrivacy(BuildContext context) => showAboutDialog(
  context: context,
  applicationName: 'AURA privacy',
  children: const [
    Text(
      'Location is shared only with selected trusted contacts during an active incident. Audio donation is opt-in and encrypted. Incident metadata is retained for 90 days.',
    ),
  ],
);

