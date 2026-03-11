import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../models/user_profile.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../main.dart'; // To access isFirebaseInitialized

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

  // --- Medicine Operations ---

  Future<void> addMedicine(Medicine medicine) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Adding medicine ${medicine.name}');
      return;
    }
    await _medicinesColl.add(medicine.toMap());
  }

  Stream<List<Medicine>> get medicinesStream {
    if (!isFirebaseInitialized) {
      return Stream.value([
        Medicine(id: '1', name: 'Metformin', dosage: '500mg', frequency: 'Daily', times: ['8:00 AM', '8:00 PM'], icon: 'medication', color: '#FAFAFA'),
        Medicine(id: '2', name: 'Amlodipine', dosage: '5mg', frequency: 'Daily', times: ['9:00 AM'], icon: 'medication', color: '#FFEB3B'),
      ]);
    }
    return _medicinesColl.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Medicine.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // --- Dose Log Operations ---

  Future<void> logDose(DoseLog log) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Logging dose for ${log.medName}');
      return;
    }
    await _logsColl.add(log.toMap());
  }

  Stream<List<DoseLog>> get logsStream {
    if (!isFirebaseInitialized) {
      return Stream.value([
        DoseLog(id: '1', medId: '1', medName: 'Metformin', timestamp: DateTime.now(), status: 'taken'),
      ]);
    }
    return _logsColl
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DoseLog.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
}
