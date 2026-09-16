import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../../theme/aura_theme.dart';

class Screen5Drill extends StatefulWidget {
  const Screen5Drill({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  State<Screen5Drill> createState() => _Screen5DrillState();
}

class _Screen5DrillState extends State<Screen5Drill>
    with TickerProviderStateMixin {
  late final AnimationController _disarmController;
  Timer? _drillTimer;
  int _secondsRemaining = 15;
  bool _isDisarmed = false;

  @override
  void initState() {
    super.initState();
    _disarmController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _disarmController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleDisarmSuccess();
      }
    });

    _startDrill();
  }

  @override
  void dispose() {
    _drillTimer?.cancel();
    _disarmController.dispose();
    super.dispose();
  }

  Future<void> _triggerHaptics() async {
    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 250, 100, 250]);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  void _startDrill() {
    _triggerHaptics();
    _drillTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
          if (_secondsRemaining % 3 == 0) {
            _triggerHaptics();
          }
        } else {
          // Drill countdown completed without disarm
          _secondsRemaining = 0;
          timer.cancel();
        }
      });
    });
  }

  void _handleDisarmSuccess() {
    _drillTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _isDisarmed = true;
    });
  }

  void _onHoldStart() {
    if (_isDisarmed) return;
    _disarmController.forward();
    HapticFeedback.selectionClick();
  }

  void _onHoldEnd() {
    if (_isDisarmed) return;
    if (_disarmController.status != AnimationStatus.completed) {
      _disarmController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Drill mode safety banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shield_outlined, color: Colors.amber, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'DRILL MODE — REAL SMS STRICTLY BYPASSED',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _isDisarmed ? _buildSuccessView() : _buildActiveDrillView(),
            ),

            // Bottom CTA
            if (_isDisarmed)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraColors.cyan,
                    foregroundColor: AuraColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: AuraColors.cyan.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'PROCEED TO MEMBERSHIP PLANS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDrillView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Threat Alert Visual Header
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.warning_amber_rounded, color: AuraColors.crimson, size: 24),
            SizedBox(width: 8),
            Text(
              'SIMULATED THREAT DRILL',
              style: TextStyle(
                color: AuraColors.crimson,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AuraColors.crimsonContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AuraColors.crimson.withValues(alpha: 0.5)),
          ),
          child: const Text(
            'GUNSHOT SIGNATURE DETECTED (91% MATCH)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Animated Central Threat Visual
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AuraColors.crimson.withValues(alpha: 0.3), width: 2),
              ),
            ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraColors.crimsonContainer,
                boxShadow: [
                  BoxShadow(
                    color: AuraColors.crimson.withValues(alpha: 0.5),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 54),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Countdown timer readout
        Text(
          '${_secondsRemaining}s',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Emergency SMS dispatch simulation in progress...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AuraColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 36),

        // 2-Second Hold-to-Cancel Disarm Button
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _onHoldStart(),
          onPointerUp: (_) => _onHoldEnd(),
          onPointerCancel: (_) => _onHoldEnd(),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: AuraColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
              ),
              // Animated filling progress fill
              AnimatedBuilder(
                animation: _disarmController,
                builder: (context, child) {
                  return FractionallySizedBox(
                    widthFactor: _disarmController.value,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(
                height: 56,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'HOLD 2 SECONDS TO DISARM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Text(
          'Hold down to disarm and prevent false alarms.',
          style: TextStyle(
            color: AuraColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.15),
                border: Border.all(color: Colors.greenAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.3),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 56),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Drill Disarmed Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'You successfully practiced canceling an alert.\nIn a real emergency, you can also press Volume Down on your phone rocker to disarm immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AuraColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
