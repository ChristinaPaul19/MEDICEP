import 'package:cloud_firestore/cloud_firestore.dart';

class DoseLog {
  final String id;
  final String medId;
  final String medName;
  final DateTime timestamp;
  final String status; // 'taken' or 'missed'
  final String? dosage;
  final String? scheduledTime;
  final String? takenBy; // 'app' or 'device'

  DoseLog({
    required this.id,
    required this.medId,
    required this.medName,
    required this.timestamp,
    required this.status,
    this.dosage,
    this.scheduledTime,
    this.takenBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'medId': medId,
      'medicineName': medName, // Match ESP32
      'medName': medName,      // Keep for compatibility
      'dosage': dosage,
      'scheduledTime': scheduledTime,
      'takenAt': timestamp.toIso8601String(), // Match ESP32
      'timestamp': Timestamp.fromDate(timestamp), // Keep for app queries
      'status': status,
      'takenBy': takenBy ?? 'app',
    };
  }

  factory DoseLog.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
      return DateTime.now();
    }

    return DoseLog(
      id: id,
      medId: map['medId'] ?? '',
      medName: map['medicineName'] ?? map['medName'] ?? '',
      timestamp: parseTimestamp(map['takenAt'] ?? map['timestamp']),
      status: map['status'] ?? 'missed',
      dosage: map['dosage'],
      scheduledTime: map['scheduledTime'],
      takenBy: map['takenBy'],
    );
  }
}
