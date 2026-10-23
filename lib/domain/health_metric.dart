import 'package:flutter/material.dart';

class HealthMetric {
  final String title;
  final String value;
  final String unit;
  final String status;
  final IconData icon;
  final Color color;

  HealthMetric({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.icon,
    required this.color,
  });
}
