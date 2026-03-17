import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../models/user_profile.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../main.dart'; // To access isFirebaseInitialized

// ── Demo-mode in-memory store ──────────────────────────────────────
// Shared across all DatabaseService instances so data added on one
// screen immediately reflects on another without Firebase.
final List<Medicine> _demoMedicines = [
  Medicine(id: '1', name: 'Metformin', dosage: '500mg', frequency: 'Daily', times: ['8:00 AM', '8:00 PM'], icon: 'medication', color: '#FAFAFA'),
  Medicine(id: '2', name: 'Amlodipine', dosage: '5mg', frequency: 'Daily', times: ['9:00 AM'], icon: 'medication', color: '#FFEB3B'),
];
final StreamController<List<Medicine>> _demoMedicinesController =
    StreamController<List<Medicine>>.broadcast();

// Demo dose logs — grows as user marks doses taken.
final List<DoseLog> _demoDoseLogs = [];
final StreamController<List<DoseLog>> _demoDoseLogsController =
    StreamController<List<DoseLog>>.broadcast();

class DatabaseService {
  FirebaseFirestore get _db {
    if (!isFirebaseInitialized) throw Exception('Firebase not initialized');
    return FirebaseFirestore.instance;
  }
  final String uid;

  DatabaseService(this.uid);

  // Helper getters
  DocumentReference get _userDoc => _db.collection('users').doc(uid);
  CollectionReference get _medicinesColl => _userDoc.collection('medicines');
  CollectionReference get _logsColl => _userDoc.collection('logs');

  // --- Profile Operations ---

  Future<void> updateProfile(UserProfile profile) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Updating profile for $uid');
      return;
    }
    await _userDoc.set({
      'profile': profile.toMap(),
    }, SetOptions(merge: true));
  }

  Future<UserProfile?> getProfile() async {
    if (!isFirebaseInitialized) {
      return UserProfile(
        name: 'Kamala (Demo)',
        age: 65,
        gender: 'Female',
        bloodGroup: 'O+',
        emergencyContact: 'Guardian (911)',
        guardianPhone: '911',
        medicalConditions: ['Diabetes', 'Hypertension'],
      );
    }
    final doc = await _userDoc.get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data() as Map<String, dynamic>;
    if (!data.containsKey('profile')) return null;
    return UserProfile.fromMap(data['profile']);
  }

  Stream<UserProfile?> get profileStream {
    if (!isFirebaseInitialized) {
      // Mock stream for demo mode
      return Stream.value(UserProfile(
        name: 'Kamala (Demo)',
        age: 65,
        gender: 'Female',
        bloodGroup: 'O+',
        emergencyContact: 'Guardian (911)',
        guardianPhone: '911',
        medicalConditions: ['Diabetes', 'Hypertension'],
      ));
    }
    return _userDoc.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data() as Map<String, dynamic>;
      if (!data.containsKey('profile')) return null;
      return UserProfile.fromMap(data['profile']);
    });
  }

  // --- Medicine Operations ---

  Future<DocumentReference?> addMedicine(Medicine medicine) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Adding medicine ${medicine.name}');
      // Give the medicine a fake id and add to the in-memory list.
      final newMed = Medicine(
        id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        name: medicine.name,
        dosage: medicine.dosage,
        frequency: medicine.frequency,
        times: medicine.times,
        icon: medicine.icon,
        color: medicine.color,
      );
      _demoMedicines.add(newMed);
      _demoMedicinesController.add(List.unmodifiable(_demoMedicines));
      return null;
    }
    return await _medicinesColl.add(medicine.toMap());
  }

  Stream<List<Medicine>> get medicinesStream {
    if (!isFirebaseInitialized) {
      // Emit the current snapshot immediately, then relay every future update.
      return _demoCombinedStream();
    }
    return _medicinesColl.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Medicine.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  /// Yields the current demo list right away, then keeps emitting broadcast
  /// events whenever [addMedicine] is called in demo mode.
  Stream<List<Medicine>> _demoCombinedStream() async* {
    yield List.unmodifiable(_demoMedicines);
    yield* _demoMedicinesController.stream;
  }

  // --- Dose Log Operations ---

  Future<void> logDose(DoseLog log) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Logging dose for ${log.medName}');
      // Avoid duplicate logs for the same medicine today.
      final alreadyLogged = _demoDoseLogs.any(
        (l) => l.medId == log.medId &&
            l.timestamp.year == log.timestamp.year &&
            l.timestamp.month == log.timestamp.month &&
            l.timestamp.day == log.timestamp.day,
      );
      if (!alreadyLogged) {
        // Give a stable id based on medId + timestamp.
        final newLog = DoseLog(
          id: 'demo-${log.medId}-${log.timestamp.millisecondsSinceEpoch}',
          medId: log.medId,
          medName: log.medName,
          timestamp: log.timestamp,
          status: log.status,
        );
        _demoDoseLogs.add(newLog);
        _demoDoseLogsController.add(List.unmodifiable(_demoDoseLogs));
      }
      return;
    }
    // Firebase path — deduplicate by checking existing docs today.
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final existing = await _logsColl
        .where('medId', isEqualTo: log.medId)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .get();
    if (existing.docs.isEmpty) {
      await _logsColl.add(log.toMap());
    } else {
      debugPrint('Dose already logged for ${log.medName} today');
    }
  }

  /// Stream of today's dose logs.
  Stream<List<DoseLog>> get todayLogsStream {
    if (!isFirebaseInitialized) {
      return _demoTodayLogsStream();
    }
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _logsColl
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DoseLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<DoseLog>> _demoTodayLogsStream() async* {
    // Filter to just today from the master list.
    List<DoseLog> _todayOnly() {
      final today = DateTime.now();
      return _demoDoseLogs
          .where((l) =>
              l.timestamp.year == today.year &&
              l.timestamp.month == today.month &&
              l.timestamp.day == today.day)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    yield _todayOnly();
    // Re-emit every time the master list changes, filtering to today.
    yield* _demoDoseLogsController.stream.map((_) => _todayOnly());
  }

  /// Stream of all dose logs (for History screen).
  Stream<List<DoseLog>> get logsStream {
    if (!isFirebaseInitialized) {
      return _demoAllLogsStream();
    }
    return _logsColl
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DoseLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<DoseLog>> _demoAllLogsStream() async* {
    List<DoseLog> _sorted() => List.of(_demoDoseLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    yield _sorted();
    yield* _demoDoseLogsController.stream.map((_) => _sorted());
  }
}
