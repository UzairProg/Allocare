import 'dart:math' as math;
import 'package:flutter/material.dart';

class SyncCoreAnimation extends StatefulWidget {
  const SyncCoreAnimation({super.key, this.isPulsing = true});

  final bool isPulsing;

  @override
  State<SyncCoreAnimation> createState() => _SyncCoreAnimationState();
}

class _SyncCoreAnimationState extends State<SyncCoreAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
        return Stack(
          alignment: Alignment.center,
          children: [
            // Central core
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.8),
                    Colors.purple.withValues(alpha: 0.8),
                    Colors.blue.withValues(alpha: 0.8),
                  ],
                  transform: GradientRotation(_controller.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: widget.isPulsing ? 2 + math.sin(_controller.value * 2 * math.pi) * 2 : 2,
                  ),
                ],
              ),
              child: const Icon(Icons.sync, color: Colors.white, size: 20),
            ),
            // Converging icons
            ...List.generate(6, (index) {
              final angle = (index * 60) * (math.pi / 180) + (_controller.value * 0.5 * math.pi);
              final radius = 28 + math.sin(_controller.value * 2 * math.pi + index) * 4;
              
              return Transform.translate(
                offset: Offset(
                  math.cos(angle) * radius,
                  math.sin(angle) * radius,
                ),
                child: Opacity(
                  opacity: 0.6 + math.sin(_controller.value * 2 * math.pi + index) * 0.4,
                  child: Icon(
                    _getIconForIndex(index),
                    size: 10,
                    color: Colors.blueGrey,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  IconData _getIconForIndex(int index) {
    const icons = [
      Icons.person,
      Icons.data_usage,
      Icons.location_on,
      Icons.bolt,
      Icons.hub,
      Icons.analytics,
    ];
    return icons[index % icons.length];
  }
}
