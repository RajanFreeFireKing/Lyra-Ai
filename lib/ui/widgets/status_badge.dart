import 'package:flutter/material.dart';
import '../../services/voice_conversation_controller.dart';

class StatusBadge extends StatelessWidget {
  final AssistantStatus status;
  final Color neonColor;

  const StatusBadge({
    super.key,
    required this.status,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String label;
    IconData icon;

    switch (status) {
      case AssistantStatus.listening:
        badgeColor = const Color(0xFF00FF9D);
        label = "LISTENING";
        icon = Icons.mic_rounded;
        break;
      case AssistantStatus.thinking:
        badgeColor = const Color(0xFFFFB800);
        label = "THINKING";
        icon = Icons.psychology_rounded;
        break;
      case AssistantStatus.speaking:
        badgeColor = neonColor;
        label = "SPEAKING";
        icon = Icons.volume_up_rounded;
        break;
      case AssistantStatus.working:
        badgeColor = const Color(0xFFBD00FF);
        label = "AGENT WORKING";
        icon = Icons.touch_app_rounded;
        break;
      case AssistantStatus.idle:
      default:
        badgeColor = Colors.white.withOpacity(0.5);
        label = "READY";
        icon = Icons.circle;
        break;
    }

    final isLive = status != AssistantStatus.idle;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6.5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(isLive ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: badgeColor.withOpacity(isLive ? 0.6 : 0.25),
          width: 1.2,
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: badgeColor.withOpacity(0.3),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: badgeColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
