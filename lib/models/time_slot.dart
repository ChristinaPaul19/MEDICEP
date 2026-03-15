import 'package:flutter/material.dart';
import 'medicine_dose.dart';

class TimeSlot {
  final String label;
  final IconData icon;
  final TimeOfDay time;
  final List<MedicineDose> medicines;
  final Color accentColor;

  const TimeSlot({
    required this.label,
    required this.icon,
    required this.time,
    required this.medicines,
    required this.accentColor,
  });

  bool get allTaken => medicines.every((m) => m.taken);
  int get takenCount => medicines.where((m) => m.taken).length;
}
