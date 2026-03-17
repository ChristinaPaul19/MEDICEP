import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../main.dart';

class AuthService extends ChangeNotifier {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Flag to persist mock state
  static bool _isMockLoggedIn = false;
  static bool get isMockLoggedIn => _isMockLoggedIn;

  FirebaseAuth get _auth {
    if (!isFirebaseInitialized) throw Exception('Firebase not initialized');
    return FirebaseAuth.instance;
  }

  // Stream of auth state changes for real Firebase
  Stream<User?> get user {
    if (!isFirebaseInitialized) return Stream.value(null); 
    return _auth.authStateChanges();
  }

  // --- Anonymous Auth (Guest) ---
  Future<UserCredential?> signInAnonymously() async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Signing in anonymously');
      await Future.delayed(const Duration(seconds: 1));
      _isMockLoggedIn = true;
      notifyListeners();
      return null;
    }
    final cred = await _auth.signInAnonymously();
    notifyListeners();
    return cred;
  }

  // --- Email/Password Auth ---

  // Sign up with Email
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Signing up with $email');
      await Future.delayed(const Duration(seconds: 1));
      _isMockLoggedIn = true;
      notifyListeners();
      return null;
    }
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    notifyListeners();
    return cred;
  }

  // Sign in with Email
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Signing in with $email');
      await Future.delayed(const Duration(seconds: 1));
      _isMockLoggedIn = true;
      notifyListeners();
      return null;
    }
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    notifyListeners();
    return cred;
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Sending password reset to $email');
      return;
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- Legacy Phone/OTP (Keep for compatibility if needed) ---
  
  // Step 1: Send OTP
  Future<void> sendOTP(String phoneNumber, Function(String) codeSent) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Sending OTP to $phoneNumber');
      await Future.delayed(const Duration(seconds: 1));
      codeSent('mock-auth-id');
      return;
    }
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) => debugPrint(e.message),
      codeSent: (String vid, int? resendToken) => codeSent(vid),
      codeAutoRetrievalTimeout: (String vid) {},
    );
  }

  // Step 2: Verify OTP
  Future<UserCredential?> verifyOTP(String vid, String code) async {
    if (!isFirebaseInitialized) {
      debugPrint('MOCK: Verifying code $code');
      await Future.delayed(const Duration(seconds: 1));
      _isMockLoggedIn = true;
      notifyListeners();
      return null;
    }
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: vid,
      smsCode: code,
    );
    final cred = await _auth.signInWithCredential(credential);
    notifyListeners();
    return cred;
  }

  // Sign out
  Future<void> signOut() async {
    if (!isFirebaseInitialized) {
      _isMockLoggedIn = false;
      notifyListeners();
      return;
    }
    await _auth.signOut();
    notifyListeners();
  }
}
