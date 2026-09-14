import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'domain.dart';
import 'screens/map_tab.dart';
import 'screens/monitor_tab.dart';
import 'screens/profile_tab.dart';
import 'screens/recents_tab.dart';
import 'services/detection_service.dart';
import 'services/entitlement_service.dart';
import 'services/hardware_button_service.dart';
import 'services/incident_repository.dart';
import 'services/location_stream_service.dart';
import 'services/sim_sms_service.dart';
import 'theme/aura_theme.dart';
import 'widgets/threat_alert_overlay.dart';

const _dispatchThreshold = 0.80;
const _countdownDuration = Duration(seconds: 20);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: AuraConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AuraConfig.supabaseAnonKey,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[AURA] Supabase initialization fallback: $e');
    }
  }
  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AURA',
        theme: AuraTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const SafetyHome(),
      );
}

class SafetyHome extends StatefulWidget {
  const SafetyHome({super.key});

  @override
  State<SafetyHome> createState() => _SafetyHomeState();
}

class _SafetyHomeState extends State<SafetyHome> {
  int _currentTab = 0;

  final IncidentRepository _repository = SupabaseIncidentRepository();
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
  StreamSubscription<IncidentSyncUpdate>? _incidentSyncSubscription;
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
    _incidentSyncSubscription?.cancel();
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

  Future<void> _beginCountdown(IncidentKind kind,
      {double? confidence, bool immediate = false}) async {
    if (_active != null && !immediate) return;

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
        await _repository.ingestLocation(
          incidentId: incident.id,
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracyM: pos.accuracy,
        );
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
    final mapLink =
        (lat != null && lng != null) ? ' https://maps.google.com/?q=$lat,$lng' : '';
    final portalUrl =
        'https://aura-safety.app/incident/${incident.id}$locParam';
    final smsMessage =
        'EMERGENCY: ${incident.kind.name.toUpperCase()} detected! View live location: $portalUrl$mapLink';

    final dispatched = incident.copyWith(
      status: IncidentStatus.dispatched,
      smsDispatchMode: useCloudSms
          ? SmsDispatchMode.cloudTermii
          : SmsDispatchMode.fallbackToLocalSim,
      fallbackTargets: useCloudSms
          ? []
          : _contacts
              .map((c) => FallbackSmsTarget(
                    phone: c.phone,
                    message: smsMessage,
                  ))
              .toList(),
      latitude: lat,
      longitude: lng,
    );

    final dispatchResult = await _repository.dispatch(dispatched);
    final effectiveTargets = dispatchResult.fallbackTargets.isNotEmpty
        ? dispatchResult.fallbackTargets
        : dispatched.fallbackTargets;

    // If local SIM fallback is required, dispatch directly via Android SmsManager
    if (dispatchResult.mode == SmsDispatchMode.fallbackToLocalSim &&
        effectiveTargets.isNotEmpty) {
      final success =
          await _simSmsService.sendLocalSms(targets: effectiveTargets);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Warning: Failed to dispatch carrier SMS. Please check SMS permission & airtime.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Subscribe to real-time incident status and contact acknowledgements
    _incidentSyncSubscription?.cancel();
    _incidentSyncSubscription =
        _repository.subscribeToIncident(dispatched.id).listen((update) {
      if (!mounted) return;
      if (update.acknowledgedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Contact acknowledged your emergency alert ( acknowledged).'),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    if (!mounted) return;
    setState(() {
      _history.insert(0, dispatchResult.incident);
      _active = null;
      _remaining = 0;
    });

    if (dispatchResult.mode == SmsDispatchMode.fallbackToLocalSim) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dispatchResult.isQueuedOffline
                ? 'Device is offline. Emergency alert queued locally and dispatched via carrier SIM.'
                : 'Free monthly cloud SMS quota reached. Emergency alert dispatched via your device carrier SIM.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _cancel() async {
    final active = _active;
    if (active == null) return;
    _timer?.cancel();
    _incidentSyncSubscription?.cancel();
    await _locationService.stopTracking();
    _locationSubscription?.cancel();
    await _repository.cancel(active.id, reason: 'false_alarm');
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
        reason:
            'AURA Free tier supports at most 2 emergency contacts. Upgrade to AURA Pro or Family to add up to 5 contacts with unlimited automated cloud SMS.',
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
        backgroundColor: AuraColors.surface,
        title: const Text('Add Trusted Contact', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Contact Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone (+234...)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
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
      backgroundColor: AuraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upgrade AURA Safety',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(reason,
                  style: const TextStyle(color: AuraColors.crimson, fontSize: 13)),
            ],
            const SizedBox(height: 16),
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
                await _entitlementService
                    .purchaseSubscription(SubscriptionTier.pro);
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
                'Circle sirens (push triggers across circle phones)',
                'Shared family transit timers',
              ],
              buttonText: 'Get Family Protection',
              isRecommended: false,
              onSelect: () async {
                await _entitlementService
                    .purchaseSubscription(SubscriptionTier.family);
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

  Future<void> _toggleListening() async {
    if (!_listening) {
      final started = await _detectionService.start();
      if (started) {
        await _hardwareService.startForegroundService();
      }
      if (mounted) {
        setState(() => _listening = started);
        if (!started) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Microphone permission required for real-time acoustic protection.'),
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
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = _entitlementService.current;
    final active = _active;

    return Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: AuraColors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(
            Icons.security_rounded,
            color: _listening ? AuraColors.cyan : AuraColors.onSurfaceVariant,
            size: 24,
          ),
        ),
        title: Column(
          children: [
            const Text(
              'AURA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AuraColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_listening ? AuraColors.cyan : Colors.grey)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening ? AuraColors.cyan : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _listening ? 'Active • Monitoring' : 'Standby • Paused',
                    style: TextStyle(
                      color: _listening
                          ? AuraColors.cyan
                          : AuraColors.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _showUpgradePaywall,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AuraColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: entitlements.tier == SubscriptionTier.free
                        ? Colors.white12
                        : AuraColors.cyan.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: entitlements.tier == SubscriptionTier.free
                          ? Colors.grey
                          : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entitlements.tier.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Active Tab Screen
          IndexedStack(
            index: _currentTab,
            children: [
              MonitorTab(
                isListening: _listening,
                isDynamicBackoffActive:
                    _detectionService.detector.isBackoffActive,
                accessibilityEnabled: _accessibilityEnabled,
                batteryOptimizationIgnored: _batteryOptimizationIgnored,
                onToggleListening: _toggleListening,
                onInstantSos: () => _beginCountdown(IncidentKind.manualSos),
                onOpenAccessibilitySettings: () async {
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
              RecentsTab(history: _history),
              MapTab(
                currentPosition: _currentPosition,
                incidents: _history,
                onRequestLocation: () async {
                  final pos = await _locationService.getCurrentPosition();
                  if (mounted && pos != null) {
                    setState(() => _currentPosition = pos);
                  }
                },
              ),
              ProfileTab(
                entitlementService: _entitlementService,
                contacts: _contacts,
                accessibilityEnabled: _accessibilityEnabled,
                batteryOptimizationIgnored: _batteryOptimizationIgnored,
                optInAudioDonation: _optInAudioDonation,
                onAddContact: _attemptAddContact,
                onShowUpgradePaywall: _showUpgradePaywall,
                onToggleAudioDonation: (val) =>
                    setState(() => _optInAudioDonation = val),
                onOpenAccessibilitySettings: () async {
                  await _hardwareService.openAccessibilitySettings();
                  await Future<void>.delayed(const Duration(seconds: 1));
                  _initSystemReadiness();
                },
                onRequestIgnoreBattery: () async {
                  await _hardwareService.requestIgnoreBatteryOptimizations();
                  await Future<void>.delayed(const Duration(seconds: 1));
                  _initSystemReadiness();
                },
                onShowPrivacy: () => _showPrivacy(context),
              ),
            ],
          ),

          // High Priority Alert HUD Overlay (When Threat is Active)
          if (active != null)
            ThreatAlertOverlay(
              incident: active,
              remainingSeconds: _remaining,
              onDispatchNow: () => _dispatch(active),
              onCancel: _cancel,
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AuraColors.surface.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentTab,
          onDestinationSelected: (idx) => setState(() => _currentTab = idx),
          backgroundColor: Colors.transparent,
          indicatorColor: AuraColors.cyan.withValues(alpha: 0.15),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.graphic_eq_rounded, color: AuraColors.onSurfaceVariant),
              selectedIcon: Icon(Icons.graphic_eq_rounded, color: AuraColors.cyan),
              label: 'Monitor',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded, color: AuraColors.onSurfaceVariant),
              selectedIcon: Icon(Icons.history_rounded, color: AuraColors.cyan),
              label: 'Recents',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined, color: AuraColors.onSurfaceVariant),
              selectedIcon: Icon(Icons.map_rounded, color: AuraColors.cyan),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AuraColors.onSurfaceVariant),
              selectedIcon: Icon(Icons.person_rounded, color: AuraColors.cyan),
              label: 'Profile',
            ),
          ],
        ),
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
        color: AuraColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended ? AuraColors.cyan : Colors.white12,
          width: isRecommended ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (isRecommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AuraColors.cyan,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: AuraColors.background,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              color: AuraColors.cyan,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: AuraColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: AuraColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSelect,
              style: FilledButton.styleFrom(
                backgroundColor:
                    isRecommended ? AuraColors.cyan : AuraColors.surface,
                foregroundColor:
                    isRecommended ? AuraColors.background : Colors.white,
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

void _showPrivacy(BuildContext context) => showAboutDialog(
      context: context,
      applicationName: 'AURA Privacy Architecture',
      applicationVersion: 'v1.0.0 (Protective Intelligence)',
      children: const [
        Text(
          '1. Microphone stream is analyzed exclusively on-device in volatile RAM; ambient audio is never uploaded or saved.\n'
          '2. High-precision GPS is shared with emergency contacts only during active threat dispatches.\n'
          '3. Offline resilience ensures emergency SMS alerting functions even without cellular data.\n'
          '4. Audio donation is strictly opt-in, encrypted, and isolated to 3-second false-alarm calibration samples.',
          style: TextStyle(fontSize: 12, height: 1.5),
        ),
      ],
    );
