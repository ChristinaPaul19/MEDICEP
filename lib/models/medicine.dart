import 'package:flutter/material.dart';

class Medicine {
  final String id;
  final String name;
  final String dosage;
  final String frequency; // e.g., "Daily", "Weekly", "As needed"
  final List<String> times; // e.g., ["08:00 AM", "08:00 PM"]
  final String icon;
  final String color;
  final DateTime? startDate;
  final bool isActive;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.icon,
    required this.color,
    this.startDate,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'times': times,
      'icon': icon,
      'color': color,
      'startDate': startDate?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory Medicine.fromMap(String id, Map<String, dynamic> map) {
    return Medicine(
      id: id,
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? 'Daily',
      times: List<String>.from(map['times'] ?? []),
      icon: map['icon'] ?? 'medication',
      color: map['color'] ?? '0xFF58A6FF',
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      isActive: map['isActive'] ?? true,
    );
  }
}
