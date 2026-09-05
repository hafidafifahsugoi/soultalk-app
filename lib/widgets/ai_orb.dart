import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A breathing, glowing orb that represents the AI companion.
/// When [speaking] is true the glow pulses more energetically.
class AiOrb extends StatefulWidget {
  const AiOrb({
    super.key,
    this.size = 160,
    this.speaking = false,
  });

  final double size;
  final bool speaking;

  @override
  State<AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<AiOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final pulse = widget.speaking ? 0.10 : 0.04;
        final scale = 1 + math.sin(t * math.pi * 2) * pulse;
        final glow = widget.speaking ? 0.5 : 0.3;

        return SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.5,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer soft halo rings
                _halo(widget.size * 1.45, glow * 0.25),
                _halo(widget.size * 1.2, glow * 0.4),
                // Core orb
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFFEAF0FF),
                          AppColors.primary,
                          AppColors.accent,
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: glow),
                          blurRadius: widget.size * 0.5,
                          spreadRadius: widget.size * 0.05,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: widget.size * 0.32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _halo(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: opacity * 0.5),
      ),
    );
  }
}
