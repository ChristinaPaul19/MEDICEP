class UserProfile {
  final String name;
  final int age;
  final String gender;
  final String bloodGroup;
  final List<String> medicalConditions;
  final String emergencyContact;
  final String guardianPhone;

  UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.medicalConditions,
    required this.emergencyContact,
    required this.guardianPhone,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'medicalConditions': medicalConditions,
      'emergencyContact': emergencyContact,
      'guardianPhone': guardianPhone,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      medicalConditions: List<String>.from(map['medicalConditions'] ?? []),
      emergencyContact: map['emergencyContact'] ?? '',
      guardianPhone: map['guardianPhone'] ?? '',
    );
  }
}
