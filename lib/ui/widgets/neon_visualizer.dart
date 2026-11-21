import 'dart:math';
import 'package:flutter/material.dart';

class NeonVisualizer extends StatefulWidget {
  final Color neonColor;
  final bool isPulsing;
  final double size;

  const NeonVisualizer({
    super.key,
    required this.neonColor,
    this.isPulsing = false,
    this.size = 200,
  });

  @override
  State<NeonVisualizer> createState() => _NeonVisualizerState();
}

class _NeonVisualizerState extends State<NeonVisualizer> with SingleTickerProviderStateMixin {
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _AuraCometPainter(
            color: widget.neonColor,
            angle: _controller.value * 2 * pi,
            isPulsing: widget.isPulsing,
          ),
        );
      },
    );
  }
}

class _AuraCometPainter extends CustomPainter {
  final Color color;
  final double angle;
  final bool isPulsing;

  _AuraCometPainter({
    required this.color,
    required this.angle,
    required this.isPulsing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    // Glowing base ring
    final basePaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius, basePaint);

    // Inner core ring
    final corePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, corePaint);

    // Rotating Comet Head & Trail (from Stonic overlay_hud.py)
    final cometPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(0.2),
          color,
        ],
        stops: const [0.0, 0.7, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isPulsing ? 5.5 : 4.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      angle,
      pi * 0.75,
      false,
      cometPaint,
    );

    // Glowing orb head
    final headX = center.dx + radius * cos(angle + pi * 0.75);
    final headY = center.dy + radius * sin(angle + pi * 0.75);
    final headPaint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(headX, headY), 5.0, headPaint);
  }

  @override
  bool shouldRepaint(covariant _AuraCometPainter oldDelegate) => true;
}
