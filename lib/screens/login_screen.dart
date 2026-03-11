import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added this import
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  String? _verificationId;
  bool _isLoading = false;
  bool _otpSent = false;

  void _sendOTP() async {
    if (_phoneController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _auth.sendOTP(
        _phoneController.text,
        (vid) {
          setState(() {
            _verificationId = vid;
            _otpSent = true;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _verifyOTP() async {
    if (_otpController.text.isEmpty || _verificationId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _auth.verifyOTP(
        _verificationId!,
        _otpController.text,
      );
      // Auth state stream will handle navigation
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Hero(
                tag: 'logo',
                child: Icon(Icons.medication_rounded, size: 80, color: Color(0xFF58A6FF)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Medicep',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your phone number to continue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF8B949E)),
              ),
              const SizedBox(height: 48),
              
              if (!_otpSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '+91 9876543210',
                    hintStyle: const TextStyle(color: Color(0xFF30363D)),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF30363D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                    ),
                    prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF8B949E)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send OTP', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 4),
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: const TextStyle(color: Color(0xFF30363D)),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF30363D)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify & Login', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                TextButton(
                  onPressed: () => setState(() => _otpSent = false),
                  child: const Text('Edit Phone Number', style: TextStyle(color: Color(0xFF58A6FF))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
