import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

class RadarVisualizer extends StatefulWidget {
  const RadarVisualizer({
    super.key,
    required this.isListening,
    required this.onToggle,
    this.statusText = 'Scanning 16 kHz ambient window',
  });

  final bool isListening;
  final VoidCallback onToggle;
  final String statusText;

  @override
  State<RadarVisualizer> createState() => _RadarVisualizerState();
}

class _RadarVisualizerState extends State<RadarVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient radial glow
              if (widget.isListening)
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AuraColors.cyan.withValues(alpha: 0.15),
                        AuraColors.background.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),

              // Animated concentric pulse rings
              if (widget.isListening)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: List.generate(3, (index) {
                        final progress = (_controller.value + (index * 0.33)) % 1.0;
                        final size = 180.0 + (progress * 90.0);
                        final opacity = (1.0 - progress).clamp(0.0, 0.7);

                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AuraColors.cyan.withValues(alpha: opacity),
                              width: (1.5 * (1.0 - progress)).clamp(0.5, 2.0),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),

              // Central interactive button
              GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 175,
                  height: 175,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AuraColors.surface.withValues(alpha: 0.85),
                    border: Border.all(
                      color: widget.isListening
                          ? AuraColors.cyan.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.12),
                      width: 2,
                    ),
                    boxShadow: widget.isListening
                        ? [
                            BoxShadow(
                              color: AuraColors.cyan.withValues(alpha: 0.3),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AuraColors.surfaceLow,
                        border: Border.all(
                          color: widget.isListening
                              ? AuraColors.cyan.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isListening
                                ? Icons.graphic_eq_rounded
                                : Icons.mic_off_rounded,
                            size: 54,
                            color: widget.isListening
                                ? AuraColors.cyan
                                : AuraColors.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isListening ? 'AURA ACTIVE' : 'PAUSED',
                            style: TextStyle(
                              color: widget.isListening
                                  ? AuraColors.cyan
                                  : AuraColors.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.isListening ? widget.statusText : 'Tap central radar to activate protection',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AuraColors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
