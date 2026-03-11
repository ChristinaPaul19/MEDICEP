import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../models/user_profile.dart';
import '../main.dart';

// =============================================================
// Medicep — Home Screen (Elderly Mode)
// =============================================================
// Design principles:
//   • Min touch target: 56dp
//   • Min font: 20sp body, 28sp headers
//   • Max 2 actions per screen
//   • WCAG AAA contrast (≥7:1)
//   • Voice readout on screen enter
// =============================================================

/// Data model for a single medicine dose
class MedicineDose {
  final String name;
  final String dosage;
  final String color;
  final bool taken;
  final DateTime? takenAt;

  const MedicineDose({
    required this.name,
    required this.dosage,
    this.color = '#FFFFFF',
    this.taken = false,
    this.takenAt,
  });

  MedicineDose copyWith({bool? taken, DateTime? takenAt}) {
    return MedicineDose(
      name: name,
      dosage: dosage,
      color: color,
      taken: taken ?? this.taken,
      takenAt: takenAt ?? this.takenAt,
    );
  }
}

/// Data model for a time slot (morning/afternoon/night)
class TimeSlot {
  final String label;
  final IconData icon;
  final TimeOfDay time;
  final List<MedicineDose> medicines;
  final Color accentColor;

  const TimeSlot({
    required this.label,
    required this.icon,
    required this.time,
    required this.medicines,
    required this.accentColor,
  });

  bool get allTaken => medicines.every((m) => m.taken);
  int get takenCount => medicines.where((m) => m.taken).length;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Demo data (replace with Isar/BLE data in production) ──
  final String userName = 'Kamala';
  List<TimeSlot> timeSlots = [];

  @override
  void initState() {
    super.initState();

    timeSlots = [
      TimeSlot(
        label: 'MORNING',
        icon: Icons.wb_sunny_rounded,
        time: const TimeOfDay(hour: 8, minute: 0),
        accentColor: const Color(0xFFFFA726),
        medicines: [
          const MedicineDose(
              name: 'Metformin', dosage: '500 mg', color: '#FFFFFF', taken: true),
          const MedicineDose(
              name: 'Amlodipine', dosage: '5 mg', color: '#FFEB3B', taken: true),
        ],
      ),
      TimeSlot(
        label: 'AFTERNOON',
        icon: Icons.wb_cloudy_rounded,
        time: const TimeOfDay(hour: 13, minute: 0),
        accentColor: const Color(0xFF42A5F5),
        medicines: [
          const MedicineDose(
              name: 'Metformin', dosage: '500 mg', color: '#FFFFFF', taken: false),
          const MedicineDose(
              name: 'Glimepiride', dosage: '2 mg', color: '#F48FB1', taken: false),
        ],
      ),
      TimeSlot(
        label: 'NIGHT',
        icon: Icons.nights_stay_rounded,
        time: const TimeOfDay(hour: 21, minute: 0),
        accentColor: const Color(0xFF7E57C2),
        medicines: [
          const MedicineDose(
              name: 'Amlodipine', dosage: '5 mg', color: '#FFEB3B', taken: false),
        ],
      ),
    ];

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.03).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  List<TimeSlot> _mapMedicinesToSlots(List<Medicine> medicines) {
    // Basic slot mapping logic for demo:
    // Split medicines into Morning (before 12), Afternoon (12-17), Night (after 17)
    final morningMeds = <MedicineDose>[];
    final afternoonMeds = <MedicineDose>[];
    final nightMeds = <MedicineDose>[];

    for (var med in medicines) {
      final dose = MedicineDose(
        name: med.name,
        dosage: med.dosage,
        color: med.color,
        taken: false, // In reality, check DoseLogs
      );

      // Simple heuristic based on first time entry
      if (med.times.isNotEmpty) {
        final timeStr = med.times.first.toUpperCase();
        if (timeStr.contains('AM')) {
          morningMeds.add(dose);
        } else if (timeStr.contains('PM')) {
          final hour = int.tryParse(timeStr.split(':').first) ?? 0;
          if (hour < 5 || hour == 12) {
            afternoonMeds.add(dose);
          } else {
            nightMeds.add(dose);
          }
        }
      }
    }

    return [
      TimeSlot(
        label: 'MORNING',
        icon: Icons.wb_sunny_rounded,
        time: const TimeOfDay(hour: 8, minute: 0),
        accentColor: const Color(0xFFFFA726),
        medicines: morningMeds,
      ),
      TimeSlot(
        label: 'AFTERNOON',
        icon: Icons.wb_cloudy_rounded,
        time: const TimeOfDay(hour: 13, minute: 0),
        accentColor: const Color(0xFF42A5F5),
        medicines: afternoonMeds,
      ),
      TimeSlot(
        label: 'NIGHT',
        icon: Icons.nights_stay_rounded,
        time: const TimeOfDay(hour: 21, minute: 0),
        accentColor: const Color(0xFF7E57C2),
        medicines: nightMeds,
      ),
    ];
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _timeUntil(TimeOfDay target) {
    final now = TimeOfDay.now();
    int diffMinutes =
        (target.hour * 60 + target.minute) - (now.hour * 60 + now.minute);
    if (diffMinutes < 0) return 'Earlier today';
    final hours = diffMinutes ~/ 60;
    final mins = diffMinutes % 60;
    if (hours > 0 && mins > 0) return 'In $hours hr $mins min';
    if (hours > 0) return 'In $hours hours';
    if (mins == 0) return 'Right now!';
    return 'In $mins minutes';
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  bool _isCurrentSlot(TimeSlot slot) {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final slotMinutes = slot.time.hour * 60 + slot.time.minute;
    return (nowMinutes - slotMinutes).abs() < 120;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: DatabaseService(isFirebaseInitialized ? (FirebaseAuth.instance.currentUser?.uid ?? '') : 'demo-uid').getProfile().asStream(),
      builder: (context, profileSnap) {
        final profileName = profileSnap.data?.name ?? 'Kamala';
        
        return StreamBuilder<List<Medicine>>(
          stream: DatabaseService(isFirebaseInitialized ? (FirebaseAuth.instance.currentUser?.uid ?? '') : 'demo-uid').medicinesStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              timeSlots = _mapMedicinesToSlots(snapshot.data!);
            }

            final totalDoses =
                timeSlots.fold<int>(0, (sum, s) => sum + s.medicines.length);
            final takenDoses =
                timeSlots.fold<int>(0, (sum, s) => sum + s.takenCount);

            return Scaffold(
              backgroundColor: const Color(0xFF0D1117),
              body: SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Header ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()},',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFF8B949E),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$profileName! 👋',
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formattedDate(),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8B949E),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildProgressCard(takenDoses, totalDoses),
                          ],
                        ),
                      ),
                    ),

                    // ── Time Slot Cards ──
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildTimeSlotCard(timeSlots[index], index),
                            );
                          },
                          childCount: timeSlots.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Top progress card showing today's adherence
  Widget _buildProgressCard(int taken, int total) {
    final percentage = total > 0 ? (taken / total * 100).round() : 0;
    final allDone = taken == total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: allDone
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFF1A1F2E), const Color(0xFF252D3D)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: allDone
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : const Color(0xFF30363D),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: total > 0 ? taken / total : 0,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: const Color(0xFF30363D),
                    valueColor: AlwaysStoppedAnimation(
                      allDone
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF58A6FF),
                    ),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone ? 'All Done! 🎉' : "Today's Progress",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$taken of $total doses taken',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF8B949E),
                  ),
                ),
                if (allDone) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Great job staying on track!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Individual time slot card
  Widget _buildTimeSlotCard(TimeSlot slot, int slotIndex) {
    final isCurrent = _isCurrentSlot(slot);
    final isPast = slot.allTaken;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isCurrent && !isPast ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrent && !isPast
                ? slot.accentColor.withValues(alpha: 0.5)
                : const Color(0xFF30363D),
            width: isCurrent && !isPast ? 2 : 1,
          ),
          boxShadow: isCurrent && !isPast
              ? [
                  BoxShadow(
                    color: slot.accentColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: slot.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(slot.icon, color: slot.accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatTime(slot.time)}  —  ${slot.label}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPast ? '✅ All taken' : _timeUntil(slot.time),
                        style: TextStyle(
                          fontSize: 15,
                          color: isPast
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF8B949E),
                          fontWeight:
                              isPast ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPast
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${slot.takenCount}/${slot.medicines.length}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPast
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF58A6FF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF30363D), height: 1),
            const SizedBox(height: 16),
            ...List.generate(slot.medicines.length, (medIndex) {
              return _buildMedicineRow(
                  slot.medicines[medIndex], slotIndex, medIndex);
            }),
          ],
        ),
      ),
    );
  }

  /// Single medicine row inside a time slot card
  Widget _buildMedicineRow(MedicineDose medicine, int slotIndex, int medIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          if (!medicine.taken) {
            HapticFeedback.heavyImpact();
            setState(() {
              final slot = timeSlots[slotIndex];
              final updatedMeds = List<MedicineDose>.from(slot.medicines);
              updatedMeds[medIndex] = medicine.copyWith(
                taken: true,
                takenAt: DateTime.now(),
              );
              timeSlots[slotIndex] = TimeSlot(
                label: slot.label,
                icon: slot.icon,
                time: slot.time,
                medicines: updatedMeds,
                accentColor: slot.accentColor,
              );
            });

            // Log to Firestore
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              DatabaseService(user.uid).logDose(
                DoseLog(
                  id: '',
                  medId: 'dynamic_id', // Would come from real model mapping
                  medName: medicine.name,
                  timestamp: DateTime.now(),
                  status: 'taken',
                ),
              );
            }
          }
        },
        child: Semantics(
          label:
              '${medicine.name} ${medicine.dosage}, ${medicine.taken ? "taken" : "pending"}. Tap to mark as taken.',
          button: !medicine.taken,
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _hexToColor(medicine.color),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: medicine.taken
                            ? const Color(0xFF8B949E)
                            : Colors.white,
                        decoration:
                            medicine.taken ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      medicine.dosage,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: medicine.taken
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: medicine.taken
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                        : const Color(0xFF30363D),
                  ),
                ),
                child: Icon(
                  medicine.taken
                      ? Icons.check_rounded
                      : Icons.circle_outlined,
                  color: medicine.taken
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF58A6FF),
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
