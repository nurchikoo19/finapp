import 'package:flutter/material.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  static const _labels = {
    'low': 'Низкий',
    'medium': 'Средний',
    'high': 'Высокий',
  };

  static const _colors = {
    'low': Colors.green,
    'medium': Colors.orange,
    'high': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[priority] ?? priority;
    final color = _colors[priority] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
