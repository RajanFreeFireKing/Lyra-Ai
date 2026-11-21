import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/voice_conversation_controller.dart';

class CyberAiCore extends StatefulWidget {
  final AssistantStatus status;
  final Color neonColor;
  final VoidCallback onTap;
  final double size;
  final double audioRms;

  const CyberAiCore({
    super.key,
    required this.status,
    required this.neonColor,
    required this.onTap,
    this.size = 280,
    this.audioRms = 0.0,
  });

  @override
  State<CyberAiCore> createState() => _CyberAiCoreState();
}

class _CyberAiCoreState extends State<CyberAiCore> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Color _getStatusGlowColor() {
    switch (widget.status) {
      case AssistantStatus.listening:
        return const Color(0xFF00FF9D); // Neon Emerald
      case AssistantStatus.thinking:
        return const Color(0xFFFFB800); // Solar Amber
      case AssistantStatus.speaking:
        return widget.neonColor;
      case AssistantStatus.working:
        return const Color(0xFFBD00FF); // Cyber Violet
      case AssistantStatus.idle:
      default:
        return widget.neonColor.withOpacity(0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getStatusGlowColor();
    final isActive = widget.status != AssistantStatus.idle;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Orbital Gyro Rings & Particle Stars
                AnimatedBuilder(
                  animation: Listenable.merge([_rotationController, _pulseController]),
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _OrbitalGyroPainter(
                        color: activeColor,
                        rotationAngle: _rotationController.value * 2 * pi,
                        pulse: _pulseController.value,
                        isActive: isActive,
                      ),
                    );
                  },
                ),

                // 2. Interactive Tactile Core (Center Button with solid hit testing)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _isPressed = true),
                  onTapUp: (_) => setState(() => _isPressed = false),
                  onTapCancel: () => setState(() => _isPressed = false),
                  onTap: widget.onTap,
                  child: AnimatedScale(
                    scale: _isPressed ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutBack,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final pulseVal = _pulseController.value;
                        final glowSpread = isActive ? 14.0 + (pulseVal * 20.0) : 6.0;

                        return Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                activeColor.withOpacity(isActive ? 0.45 : 0.22),
                                const Color(0xFF131722).withOpacity(0.9),
                                const Color(0xFF090C14),
                              ],
                              stops: const [0.0, 0.65, 1.0],
                            ),
                            border: Border.all(
                              color: activeColor.withOpacity(isActive ? 0.95 : 0.45),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withOpacity(isActive ? 0.6 : 0.2),
                                blurRadius: glowSpread * 2,
                                spreadRadius: glowSpread * 0.4,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.7),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: widget.status == AssistantStatus.listening
                                  ? Container(
                                      key: const ValueKey("stop_icon"),
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: activeColor,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: activeColor.withOpacity(0.85),
                                            blurRadius: 16,
                                          )
                                        ],
                                      ),
                                    )
                                  : Icon(
                                      widget.status == AssistantStatus.thinking
                                          ? Icons.psychology_rounded
                                          : widget.status == AssistantStatus.speaking
                                              ? Icons.volume_up_rounded
                                              : widget.status == AssistantStatus.working
                                                  ? Icons.touch_app_rounded
                                                  : Icons.mic_rounded,
                                      key: ValueKey(widget.status),
                                      size: 46,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Real-Time Audio Frequency Sound Wave Visualizer Bars
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return _buildSoundWaveBars(activeColor, isActive);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSoundWaveBars(Color color, bool active) {
    const barCount = 19;
    final progress = _waveController.value;
    final normRms = (widget.audioRms / 200.0).clamp(0.0, 2.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(barCount, (i) {
        final distFromCenter = (i - (barCount / 2)).abs();
        final maxH = 28.0 - (distFromCenter * 1.5);

        double height;
        if (active) {
          final wave = sin(progress * 2 * pi + (i * 0.55)).abs();
          final ampBoost = 0.5 + (0.9 * normRms);
          height = 5.0 + (wave * maxH * ampBoost).clamp(3.0, 36.0);
        } else {
          height = 4.0;
        }

        return Container(
          width: 3.5,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 2.2),
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.75 + (0.25 * (height / maxH).clamp(0.0, 1.0)))
                : Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(4),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _OrbitalGyroPainter extends CustomPainter {
  final Color color;
  final double rotationAngle;
  final double pulse;
  final bool isActive;

  _OrbitalGyroPainter({
    required this.color,
    required this.rotationAngle,
    required this.pulse,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 - 12;

    // 1. Ambient Outer Halo
    final haloPaint = Paint()
      ..color = color.withOpacity(isActive ? 0.14 : 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, baseRadius - 16, haloPaint);

    // 2. Outer Counter-Rotating Segmented Gyro Ring
    final ringPaint1 = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(0.2),
          color.withOpacity(0.85),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
        transform: GradientRotation(rotationAngle),
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isActive ? 3.8 : 2.2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: baseRadius),
      rotationAngle,
      pi * 1.25,
      false,
      ringPaint1,
    );

    // 3. Inner Reverse Orbital Track
    final innerRadius = baseRadius - 26;
    final ringPaint2 = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.9),
          Colors.transparent,
          color.withOpacity(0.3),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(-rotationAngle * 1.5),
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      -rotationAngle * 1.5,
      pi * 0.9,
      false,
      ringPaint2,
    );

    // 4. Orbital Satellites / Cosmic Nodes
    final nodeAngle = rotationAngle;
    final nodeX = center.dx + baseRadius * cos(nodeAngle);
    final nodeY = center.dy + baseRadius * sin(nodeAngle);

    final nodePaint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(nodeX, nodeY), isActive ? 5.5 : 4.0, nodePaint);

    final oppNodeX = center.dx + innerRadius * cos(-nodeAngle * 1.5 + pi);
    final oppNodeY = center.dy + innerRadius * sin(-nodeAngle * 1.5 + pi);
    canvas.drawCircle(Offset(oppNodeX, oppNodeY), 3.5, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalGyroPainter oldDelegate) => true;
}
