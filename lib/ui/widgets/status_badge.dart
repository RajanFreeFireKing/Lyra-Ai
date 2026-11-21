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
        badgeColor = const Color(0xFF00FF88);
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
        badgeColor = const Color(0xFFB026FF);
        label = "AGENT WORKING";
        icon = Icons.touch_app_rounded;
        break;
      case AssistantStatus.idle:
      default:
        badgeColor = Colors.white.withOpacity(0.4);
        label = "READY";
        icon = Icons.circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
