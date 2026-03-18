import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../models/user_profile.dart';
import '../models/medicine_dose.dart';
import '../models/time_slot.dart';
import '../main.dart';
import 'profile_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timer;

  // ── Demo data (replace with Isar/BLE data in production) ──
  final String userName = 'Kamala';
  List<TimeSlot> timeSlots = [];

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

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

  List<TimeSlot> _mapMedicinesToSlots(List<Medicine> medicines, List<DoseLog> logs) {
    final morningMeds = <MedicineDose>[];
    final afternoonMeds = <MedicineDose>[];
    final nightMeds = <MedicineDose>[];

    for (var med in medicines) {
      final isTaken = logs.any((log) => log.medId == med.id);
      final takenAt = isTaken ? logs.firstWhere((log) => log.medId == med.id).timestamp : null;

      final dose = MedicineDose(
        medId: med.id,
        name: med.name,
        dosage: med.dosage,
        color: med.color,
        taken: isTaken,
        takenAt: takenAt,
      );

      // Map to slots based on med.times
      for (var timeStr in med.times) {
        if (timeStr.toUpperCase().contains('AM')) {
          morningMeds.add(dose);
        } else if (timeStr.toUpperCase().contains('PM')) {
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

  Future<void> _toggleDose(MedicineDose dose) async {
    if (dose.taken) return; // For now, only allow marking as taken

    HapticFeedback.mediumImpact();
    
    final uid = isFirebaseInitialized ? (FirebaseAuth.instance.currentUser?.uid ?? '') : 'demo-uid';
    final log = DoseLog(
      id: '',
      medId: dose.medId ?? '',
      medName: dose.name,
      timestamp: DateTime.now(),
      status: 'taken',
    );

    await DatabaseService(uid).logDose(log);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked ${dose.name} as taken!'),
          backgroundColor: const Color(0xFF238636),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
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
    if (hex.startsWith('0xFF')) {
      return Color(int.parse(hex));
    }
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _formattedLiveTime() {
    final now = DateTime.now();
    final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
    final uid = isFirebaseInitialized ? (FirebaseAuth.instance.currentUser?.uid ?? '') : 'demo-uid';
    
    return StreamBuilder<UserProfile?>(
      stream: DatabaseService(uid).getProfile().asStream(),
      builder: (context, profileSnap) {
        final profileName = profileSnap.data?.name ?? 'Kamala';
        
        return StreamBuilder<List<Medicine>>(
          stream: DatabaseService(uid).medicinesStream,
          builder: (context, medSnapshot) {
            return StreamBuilder<List<DoseLog>>(
              stream: DatabaseService(uid).todayLogsStream,
              builder: (context, logSnapshot) {
                if (medSnapshot.hasData && logSnapshot.hasData) {
                  timeSlots = _mapMedicinesToSlots(medSnapshot.data!, logSnapshot.data!);
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
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
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161B22),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF30363D)),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.settings_outlined, color: Color(0xFF58A6FF)),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF8B949E)),
                                const SizedBox(width: 6),
                                Text(
                                  _formattedDate(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8B949E),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF8B949E)),
                                const SizedBox(width: 6),
                                Text(
                                  _formattedLiveTime(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8B949E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: uid));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Device ID (UID) copied to clipboard!'),
                                    backgroundColor: Color(0xFF238636),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161B22),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF30363D)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy_rounded, color: Color(0xFF58A6FF), size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'UID: $uid',
                                      style: const TextStyle(
                                        color: Color(0xFF58A6FF),
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildProgressCard(takenDoses, totalDoses),
                          ],
                        ),
                      ),
                    ),

                    // ── Time Slot Cards ──
                    if (timeSlots.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No medications scheduled for today.',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 18),
                          ),
                        ),
                      )
                    else
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
      },
    );
  }

  /// Top progress card showing today's adherence
  Widget _buildProgressCard(int taken, int total) {
    final percentage = total > 0 ? (taken / total * 100).round() : 0;
    final allDone = total > 0 && taken == total;

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
              ? const Color(0xFF4CAF50).withOpacity(0.3)
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
    if (slot.medicines.isEmpty) return const SizedBox.shrink();
    
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
                ? slot.accentColor.withOpacity(0.5)
                : const Color(0xFF30363D),
            width: isCurrent && !isPast ? 2 : 1,
          ),
          boxShadow: isCurrent && !isPast
              ? [
                  BoxShadow(
                    color: slot.accentColor.withOpacity(0.1),
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
                    color: slot.accentColor.withOpacity(0.15),
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
        onTap: () => _toggleDose(medicine),
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
                        ? const Color(0xFF4CAF50).withOpacity(0.3)
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
