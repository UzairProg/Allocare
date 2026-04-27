import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../application/home_live_data_providers.dart';

class MicroVisualization extends StatelessWidget {
  const MicroVisualization({
    super.key,
    required this.type,
    required this.color,
  });

  final ActivityVizType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (type == ActivityVizType.none) return const SizedBox.shrink();

    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _VizPainter(type: type, color: color),
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  _VizPainter({required this.type, required this.color});

  final ActivityVizType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case ActivityVizType.heatmap:
        _paintHeatmap(canvas, size);
        break;
      case ActivityVizType.vectorLine:
        _paintVectorLine(canvas, size);
        break;
      case ActivityVizType.windPattern:
        _paintWindPattern(canvas, size);
        break;
      case ActivityVizType.none:
        break;
    }
  }

  void _paintHeatmap(Canvas canvas, Size size) {
    final paint = Paint();
    final center = Offset(size.width * 0.6, size.height * 0.5);
    
    // Simple radial gradient to mimic heatmap
    paint.shader = RadialGradient(
      colors: [
        color.withValues(alpha: 0.8),
        color.withValues(alpha: 0.4),
        color.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.4));
    
    canvas.drawCircle(center, size.width * 0.4, paint);
  }

  void _paintVectorLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.8);
    path.lineTo(size.width * 0.3, size.height * 0.6);
    path.lineTo(size.width * 0.5, size.height * 0.7);
    path.lineTo(size.width * 0.9, size.height * 0.2);

    canvas.drawPath(path, paint);

    // Draw dots at points
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.8), 2, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.2), 2.5, paint);
  }

  void _paintWindPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.3 + i * 0.25);
      final path = Path();
      path.moveTo(size.width * 0.1, y);
      
      // Sine wave-ish wind lines
      for (var x = 0.1; x <= 0.9; x += 0.1) {
        path.lineTo(
          size.width * x,
          y + math.sin(x * 10 + i) * 3,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
