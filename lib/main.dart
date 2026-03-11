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
import 'models/user_profile.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Requires google-services.json / GoogleService-Info.plist)
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Running in DEMO MODE without Firebase connectivity.');
  }

  // Enable offline persistence if initialized
  if (isFirebaseInitialized) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings error: $e');
    }
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
        textTheme: GoogleFonts.interTextTheme(
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
              return FutureBuilder<UserProfile?>(
                future: DatabaseService(uid).getProfile(),
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

/// Placeholder — History screen
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: Color(0xFF58A6FF),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Dose History',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Your weekly medication history will appear here once you start tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF8B949E),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder — Help / SOS screen
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SOS Button
              GestureDetector(
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  
                  // Wrap in FutureBuilder to get profile for SOS
                  showDialog(
                    context: context,
                    builder: (ctx) => FutureBuilder<UserProfile?>(
                      future: DatabaseService(isFirebaseInitialized ? (FirebaseAuth.instance.currentUser?.uid ?? '') : 'demo-uid').getProfile(),
                      builder: (context, snapshot) {
                        final contact = snapshot.data?.emergencyContact ?? 'Emergency Contact';
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
                            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 16),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel',
                                  style: TextStyle(color: Color(0xFF8B949E))),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                // TODO: Trigger SOS call (e.g. url_launcher)
                                debugPrint('Calling $phone...');
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F)),
                              child: const Text('Call Now'),
                            ),
                          ],
                        );
                      }
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
                      Icon(Icons.emergency_rounded,
                          size: 52, color: Colors.white),
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
              const SizedBox(height: 24),
              const Text(
                'Long press for emergency',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF8B949E),
                ),
              ),
              const SizedBox(height: 48),

              // Settings quick links
              _buildSettingsTile(
                Icons.language_rounded,
                'Language',
                'Hindi',
                const Color(0xFF58A6FF),
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                Icons.volume_up_rounded,
                'Alert Volume',
                'High',
                const Color(0xFFFFA726),
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                Icons.bluetooth_rounded,
                'MedicepBox',
                'Connected',
                const Color(0xFF4CAF50),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
      IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
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
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF8B949E), size: 24),
        ],
      ),
    );
  }
}
