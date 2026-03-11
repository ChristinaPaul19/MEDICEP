class Medicine {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final List<String> times;
  final String icon;
  final String color;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'times': times,
      'icon': icon,
      'color': color,
    };
  }

  factory Medicine.fromMap(String id, Map<String, dynamic> map) {
    return Medicine(
      id: id,
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      times: List<String>.from(map['times'] ?? []),
      icon: map['icon'] ?? 'medication',
      color: map['color'] ?? '0xFF58A6FF',
    );
  }
}
