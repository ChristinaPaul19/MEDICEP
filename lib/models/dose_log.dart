import 'package:cloud_firestore/cloud_firestore.dart';

class DoseLog {
  final String id;
  final String medId;
  final String medName;
  final DateTime timestamp;
  final String status; // 'taken' or 'missed'

  DoseLog({
    required this.id,
    required this.medId,
    required this.medName,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'medId': medId,
      'medName': medName,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }

  factory DoseLog.fromMap(String id, Map<String, dynamic> map) {
    return DoseLog(
      id: id,
      medId: map['medId'] ?? '',
      medName: map['medName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: map['status'] ?? 'missed',
    );
  }
}
