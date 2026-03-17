import 'package:flutter/material.dart';
import '../theme/tabys_theme.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  static const _labels = {
    'low': 'Низкий',
    'medium': 'Средний',
    'high': 'Высокий',
  };

  static const _colors = {
    'low': TColors.muted,
    'medium': TColors.gold,
    'high': TColors.red,
  };

  static const _bgs = {
    'low': TColors.card2,
    'medium': TColors.goldBg,
    'high': TColors.redBg,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[priority] ?? priority;
    final color = _colors[priority] ?? TColors.muted;
    final bg = _bgs[priority] ?? TColors.card2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
