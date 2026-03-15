class MedicineDose {
  final String? medId;
  final String name;
  final String dosage;
  final String color;
  final bool taken;
  final DateTime? takenAt;

  const MedicineDose({
    this.medId,
    required this.name,
    required this.dosage,
    this.color = '#FFFFFF',
    this.taken = false,
    this.takenAt,
  });

  MedicineDose copyWith({bool? taken, DateTime? takenAt}) {
    return MedicineDose(
      medId: medId,
      name: name,
      dosage: dosage,
      color: color,
      taken: taken ?? this.taken,
      takenAt: takenAt ?? this.takenAt,
    );
  }
}
