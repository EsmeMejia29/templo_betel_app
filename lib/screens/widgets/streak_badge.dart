import 'package:flutter/material.dart';


class StreakBadge extends StatelessWidget {
  final int streakCount;

  const StreakBadge({super.key, required this.streakCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔥', // Ícono de fuego tipo Duolingo
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(
            '$streakCount días seguidos',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}