import 'package:flutter/material.dart';

class EmployeeAvatar extends StatelessWidget {
  final String name;
  final int colorValue;
  final double radius;

  const EmployeeAvatar({
    super.key,
    required this.name,
    required this.colorValue,
    this.radius = 20,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(colorValue),
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
