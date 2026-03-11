import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _guardianPhoneController = TextEditingController();

  String _gender = 'Male';
  String _bloodGroup = 'A+';
  bool _isLoading = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = UserProfile(
        name: _nameController.text,
        age: int.parse(_ageController.text),
        gender: _gender,
        bloodGroup: _bloodGroup,
        medicalConditions: _conditionsController.text.split(',').map((e) => e.trim()).toList(),
        emergencyContact: _emergencyContactController.text,
        guardianPhone: _guardianPhoneController.text,
      );

      await DatabaseService(user.uid).updateProfile(profile);
      // AuthWrapper will rebuild and navigate to MainShell
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Complete Profile'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about the patient',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'This information helps in emergencies.',
                style: TextStyle(fontSize: 16, color: Color(0xFF8B949E)),
              ),
              const SizedBox(height: 32),
              
              _buildTextField('Full Name', _nameController, Icons.person_rounded),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: _buildTextField('Age', _ageController, Icons.calendar_today_rounded, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDropdown('Gender', _gender, _genders, (v) => setState(() => _gender = v!))),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildDropdown('Blood Group', _bloodGroup, _bloodGroups, (v) => setState(() => _bloodGroup = v!)),
              const SizedBox(height: 16),
              
              _buildTextField('Medical Conditions (split by comma)', _conditionsController, Icons.health_and_safety_rounded),
              const SizedBox(height: 16),
              
              _buildTextField('Emergency Contact Name', _emergencyContactController, Icons.contact_phone_rounded),
              const SizedBox(height: 16),
              
              _buildTextField('Guardian Phone Number', _guardianPhoneController, Icons.supervisor_account_rounded, isNumber: true),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save and Continue', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8B949E)),
        filled: true,
        fillColor: const Color(0xFF161B22),
        prefixIcon: Icon(icon, color: const Color(0xFF58A6FF)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      dropdownColor: const Color(0xFF161B22),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8B949E)),
        filled: true,
        fillColor: const Color(0xFF161B22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
