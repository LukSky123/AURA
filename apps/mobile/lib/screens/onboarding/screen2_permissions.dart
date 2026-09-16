import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/hardware_button_service.dart';
import '../../theme/aura_theme.dart';

class Screen2Permissions extends StatefulWidget {
  const Screen2Permissions({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  State<Screen2Permissions> createState() => _Screen2PermissionsState();
}

class _Screen2PermissionsState extends State<Screen2Permissions> with WidgetsBindingObserver {
  final HardwareButtonService _hardwareService = HardwareButtonService();

  bool _micGranted = false;
  bool _locationGranted = false;
  bool _smsGranted = false;
  bool _batteryIgnored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hardwareService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.isGranted;
    final loc = await Permission.location.isGranted;
    final sms = await Permission.sms.isGranted;
    final batt = await _hardwareService.isBatteryOptimizationIgnored();

    if (mounted) {
      setState(() {
        _micGranted = mic;
        _locationGranted = loc;
        _smsGranted = sms;
        _batteryIgnored = batt;
      });
    }
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    if (mounted) setState(() => _micGranted = status.isGranted);
  }

  Future<void> _requestLocation() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await Permission.locationAlways.request();
    }
    if (mounted) setState(() => _locationGranted = status.isGranted);
  }

  Future<void> _requestSms() async {
    final status = await Permission.sms.request();
    if (mounted) setState(() => _smsGranted = status.isGranted);
  }

  Future<void> _requestBattery() async {
    await _hardwareService.requestIgnoreBatteryOptimizations();
    await Future<void>.delayed(const Duration(seconds: 1));
    _checkPermissions();
  }

  Future<void> _requestAll() async {
    await _requestMic();
    await _requestLocation();
    await _requestSms();
    await _requestBattery();
  }

  @override
  Widget build(BuildContext context) {
    final bool allCriticalGranted = _micGranted && _locationGranted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AuraColors.surface,
                        border: Border.all(
                          color: AuraColors.cyan.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.security_rounded,
                          color: AuraColors.cyan,
                          size: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'System Protection Priming',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AURA requires device permissions to listen for danger sounds and dispatch alerts without internet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AuraColors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 1. Microphone
                    _PermissionCard(
                      icon: Icons.mic_rounded,
                      title: 'Microphone (Acoustic AI)',
                      subtitle: 'Scans 16 kHz audio locally in RAM for gunshot, explosion, and glass break signatures.',
                      isGranted: _micGranted,
                      onGrant: _requestMic,
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),

                    // 2. Location
                    _PermissionCard(
                      icon: Icons.location_on_rounded,
                      title: 'Emergency Location',
                      subtitle: 'Attaches precise GPS coordinates to the distress SMS sent to your trusted contacts.',
                      isGranted: _locationGranted,
                      onGrant: _requestLocation,
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),

                    // 3. SMS
                    _PermissionCard(
                      icon: Icons.sms_rounded,
                      title: 'Direct SIM SMS Fallback',
                      subtitle: 'Autonomously fires carrier SMS directly from your device if cellular data is offline.',
                      isGranted: _smsGranted,
                      onGrant: _requestSms,
                      isRequired: false,
                    ),
                    const SizedBox(height: 12),

                    // 4. Battery Optimization
                    _PermissionCard(
                      icon: Icons.battery_charging_full_rounded,
                      title: 'Battery Whitelist',
                      subtitle: 'Prevents Android from freezing background acoustic listening when the phone is locked.',
                      isGranted: _batteryIgnored,
                      onGrant: _requestBattery,
                      isRequired: false,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Actions
            Column(
              children: [
                if (!allCriticalGranted)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _requestAll,
                      icon: const Icon(Icons.bolt_rounded, color: AuraColors.cyan),
                      label: const Text(
                        'GRANT ALL PERMISSIONS',
                        style: TextStyle(
                          color: AuraColors.cyan,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AuraColors.cyan.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                if (!allCriticalGranted) const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allCriticalGranted ? AuraColors.cyan : AuraColors.surfaceHigh,
                      foregroundColor: allCriticalGranted ? AuraColors.background : Colors.white60,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'CONTINUE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onGrant,
    required this.isRequired,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onGrant;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isGranted ? Colors.green : AuraColors.cyan).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? Colors.greenAccent : AuraColors.cyan,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AuraColors.crimson.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'REQUIRED',
                          style: TextStyle(
                            color: AuraColors.crimson,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AuraColors.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isGranted)
            TextButton(
              onPressed: onGrant,
              style: TextButton.styleFrom(
                foregroundColor: AuraColors.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: const Text(
                'GRANT',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            )
          else
            const Icon(Icons.check, color: Colors.greenAccent, size: 20),
        ],
      ),
    );
  }
}
