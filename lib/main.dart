import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/home_screen.dart';
import 'screens/add_medicine_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'models/user_profile.dart';
import 'models/dose_log.dart';
import 'firebase_options.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
    
    // Enable offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    await NotificationService().init();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Running in DEMO MODE without Firebase connectivity.');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF161B22),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MedicepApp());
}

class MedicepApp extends StatelessWidget {
  const MedicepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          secondary: Color(0xFF238636),
          surface: Color(0xFF161B22),
          error: Color(0xFFEF5350),
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/add-medicine': (context) => const AddMedicineScreen(),
      },
    );
  }
}

/// AuthWrapper — Decides between Login and Main Shell
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        return StreamBuilder<User?>(
          stream: AuthService().user,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF))),
              );
            }
            
            final bool isMocked = !isFirebaseInitialized && AuthService.isMockLoggedIn;
            
            if (snapshot.hasData || isMocked) {
              final uid = isMocked ? 'demo-uid' : snapshot.data!.uid;
              return StreamBuilder<UserProfile?>(
                stream: DatabaseService(uid).profileStream,
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF))),
                    );
                  }
                  
                  if (profileSnapshot.hasData && profileSnapshot.data != null) {
                    return const MainShell();
                  } else {
                    return const ProfileSetupScreen();
                  }
                },
              );
            } else {
              return const LoginScreen();
            }
          },
        );
      }
    );
  }
}

/// Main shell with bottom navigation — Elderly Mode (3 tabs)
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          const HistoryScreen(),
          const HelpScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.pushNamed(context, '/add-medicine');
        },
        backgroundColor: const Color(0xFF238636),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          'Add Medicine',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          border: Border(
            top: BorderSide(color: Color(0xFF30363D), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, 'Home', 0),
                _buildNavItem(Icons.history_rounded, 'History', 1),
                _buildNavItem(Icons.emergency_rounded, 'SOS', 2,
                    isEmergency: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index,
      {bool isEmergency = false}) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _currentIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF58A6FF).withOpacity(0.1)
              : isEmergency
                  ? const Color(0xFFD32F2F).withOpacity(0.05)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? const Color(0xFF58A6FF)
                  : isEmergency
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF8B949E),
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? const Color(0xFF58A6FF)
                    : isEmergency
                        ? const Color(0xFFEF5350)
                        : const Color(0xFF8B949E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// History screen — shows all dose logs from DatabaseService.logsStream
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} — $hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final uid = isFirebaseInitialized
        ? (FirebaseAuth.instance.currentUser?.uid ?? '')
        : 'demo-uid';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Text(
                'Dose History',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text(
                'Your medication log',
                style: TextStyle(fontSize: 16, color: Color(0xFF8B949E)),
              ),
            ),
            // Log list
            Expanded(
              child: StreamBuilder<List<DoseLog>>(
                stream: DatabaseService(uid).logsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
                    );
                  }

                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFF30363D)),
                            ),
                            child: const Icon(Icons.history_rounded,
                                size: 44, color: Color(0xFF58A6FF)),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No doses logged yet',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'Mark a medicine as taken on the Home screen and it will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8B949E),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isTaken = log.status == 'taken';
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isTaken
                                ? const Color(0xFF4CAF50).withOpacity(0.3)
                                : const Color(0xFF30363D),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isTaken
                                    ? const Color(0xFF1B5E20)
                                    : const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isTaken
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: isTaken
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFEF5350),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.medName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTimestamp(log.timestamp),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8B949E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isTaken
                                    ? const Color(0xFF1B5E20)
                                    : const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isTaken ? '✅ Taken' : '❌ Missed',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isTaken
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFEF5350),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SOS + Settings screen with interactive Language and Volume controls
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _language = 'English';
  String _volume = 'High';

  static const _languages = ['English', 'Hindi', 'Tamil'];
  static const _volumes = ['Low', 'Medium', 'High'];

  void _pickLanguage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF30363D)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF58A6FF).withOpacity(0.08),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30363D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A3A5C), Color(0xFF0D2137)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.language_rounded,
                        color: Color(0xFF58A6FF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Select your preferred language',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF8B949E)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // language options
              ...[
                ('🇬🇧', 'English', 'A', const Color(0xFF58A6FF)),
                ('🇮🇳', 'Hindi', 'अ', const Color(0xFFFFA726)),
                ('🇮🇳', 'Tamil', 'அ', const Color(0xFF66BB6A)),
              ].map((item) {
                final flag = item.$1;
                final lang = item.$2;
                final sample = item.$3;
                final col = item.$4 as Color;
                final isSelected = _language == lang;
                return GestureDetector(
                  onTap: () {
                    setState(() => _language = lang);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? col.withOpacity(0.12)
                          : const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isSelected ? col : const Color(0xFF30363D),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            lang,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected ? col : Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? col.withOpacity(0.2)
                                : const Color(0xFF1A1F2E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: isSelected
                                ? Icon(Icons.check_rounded,
                                    color: col, size: 18)
                                : Text(
                                    sample,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF8B949E)),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _pickVolume() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final int idx = _volumes.indexOf(_volume);
          final labels = ['Low', 'Medium', 'High'];
          final icons = [
            Icons.volume_mute_rounded,
            Icons.volume_down_rounded,
            Icons.volume_up_rounded,
          ];
          final colors = [
            const Color(0xFF42A5F5),
            const Color(0xFFFFA726),
            const Color(0xFFEF5350),
          ];

          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF30363D)),
              boxShadow: [
                BoxShadow(
                  color: colors[idx].withOpacity(0.1),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30363D),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // header
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors[idx].withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icons[idx],
                            color: colors[idx], size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alert Volume',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            labels[idx],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors[idx],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // segmented bar — 3 tap targets
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Row(
                      children: List.generate(3, (i) {
                        final isActive = idx == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() {
                              setState(() => _volume = labels[i]);
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colors[i].withOpacity(0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isActive
                                    ? Border.all(
                                        color: colors[i].withOpacity(0.6),
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    icons[i],
                                    color: isActive
                                        ? colors[i]
                                        : const Color(0xFF8B949E),
                                    size: 20,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    labels[i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isActive
                                          ? colors[i]
                                          : const Color(0xFF8B949E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // apply button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors[idx],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // SOS Button
              GestureDetector(
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  showDialog(
                    context: context,
                    builder: (ctx) => FutureBuilder<UserProfile?>(
                      future: DatabaseService(isFirebaseInitialized
                              ? (FirebaseAuth.instance.currentUser?.uid ?? '')
                              : 'demo-uid')
                          .getProfile(),
                      builder: (context, snapshot) {
                        final contact =
                            snapshot.data?.emergencyContact ?? 'Emergency Contact';
                        final phone = snapshot.data?.guardianPhone ?? '911';
                        return AlertDialog(
                          backgroundColor: const Color(0xFF161B22),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: const Row(
                            children: [
                              Icon(Icons.emergency, color: Color(0xFFEF5350)),
                              SizedBox(width: 12),
                              Text('Emergency SOS',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          content: Text(
                            'This will call $contact ($phone) immediately.',
                            style: const TextStyle(
                                color: Color(0xFF8B949E), fontSize: 16),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel',
                                  style:
                                      TextStyle(color: Color(0xFF8B949E))),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                debugPrint('Calling $phone...');
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F)),
                              child: const Text('Call Now'),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFEF5350), Color(0xFFB71C1C)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF5350).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency_rounded, size: 52, color: Colors.white),
                      SizedBox(height: 6),
                      Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Long press for emergency',
                style: TextStyle(fontSize: 18, color: Color(0xFF8B949E)),
              ),
              const SizedBox(height: 48),

              // Language tile — tappable
              _buildSettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                value: _language,
                color: const Color(0xFF58A6FF),
                onTap: _pickLanguage,
              ),
              const SizedBox(height: 12),

              // Volume tile — tappable
              _buildSettingsTile(
                icon: Icons.volume_up_rounded,
                title: 'Alert Volume',
                value: _volume,
                color: const Color(0xFFFFA726),
                onTap: _pickVolume,
              ),
              const SizedBox(height: 12),

              // Bluetooth tile (static for now)
              _buildSettingsTile(
                icon: Icons.bluetooth_rounded,
                title: 'MedicepBox',
                value: 'Connected',
                color: const Color(0xFF4CAF50),
                onTap: null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap != null
                ? const Color(0xFF30363D)
                : const Color(0xFF30363D),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              onTap != null
                  ? Icons.chevron_right_rounded
                  : Icons.check_circle_rounded,
              color: onTap != null
                  ? const Color(0xFF8B949E)
                  : color,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
