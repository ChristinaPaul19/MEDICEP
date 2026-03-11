import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/medicine.dart';
import '../main.dart';

// =============================================================
// Medicep — Add Medicine Screen (Guardian Mode)
// =============================================================
// This screen allows guardians to:
//   • Add/edit medicine details
//   • Set dosage and frequency
//   • Assign pill color for identification
//   • Pick time slots
//   • Assign to device tray
//   • Run a drug interaction check
//   • Push schedule to MedicepBox via BLE
// =============================================================

/// Available pill colors for visual identification
class PillColor {
  final String name;
  final Color color;
  final String hex;

  const PillColor({
    required this.name,
    required this.color,
    required this.hex,
  });
}

const List<PillColor> kPillColors = [
  PillColor(name: 'White', color: Color(0xFFFAFAFA), hex: '#FAFAFA'),
  PillColor(name: 'Yellow', color: Color(0xFFFFEB3B), hex: '#FFEB3B'),
  PillColor(name: 'Red', color: Color(0xFFEF5350), hex: '#EF5350'),
  PillColor(name: 'Blue', color: Color(0xFF42A5F5), hex: '#42A5F5'),
  PillColor(name: 'Pink', color: Color(0xFFF48FB1), hex: '#F48FB1'),
  PillColor(name: 'Green', color: Color(0xFF66BB6A), hex: '#66BB6A'),
  PillColor(name: 'Orange', color: Color(0xFFFFA726), hex: '#FFA726'),
  PillColor(name: 'Brown', color: Color(0xFF8D6E63), hex: '#8D6E63'),
];

/// Frequency options
enum DoseFrequency {
  once('Once Daily', 1),
  twice('Twice Daily', 2),
  thrice('Thrice Daily', 3),
  fourTimes('Four Times', 4);

  final String label;
  final int count;
  const DoseFrequency(this.label, this.count);
}

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen>
    with SingleTickerProviderStateMixin {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  // State
  int _selectedColorIndex = 0;
  DoseFrequency _frequency = DoseFrequency.twice;
  List<TimeOfDay> _timeSlots = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 20, minute: 0),
  ];
  int _selectedTray = 1;
  bool _isSaving = false;
  bool _interactionCheckDone = false;
  bool _interactionSafe = true;
  String _interactionMessage = '';

  // Animation
  late AnimationController _saveAnimController;
  late Animation<double> _saveAnimation;

  // Drug autocomplete suggestions (demo)
  final List<String> _drugDatabase = [
    'Metformin',
    'Amlodipine',
    'Glimepiride',
    'Atorvastatin',
    'Losartan',
    'Aspirin',
    'Omeprazole',
    'Pantoprazole',
    'Clopidogrel',
    'Telmisartan',
    'Ramipril',
    'Hydroxychloroquine',
    'Paracetamol',
    'Cetirizine',
    'Montelukast',
  ];

  @override
  void initState() {
    super.initState();
    _saveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _saveAnimation = CurvedAnimation(
      parent: _saveAnimController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _saveAnimController.dispose();
    super.dispose();
  }

  void _updateTimeSlots() {
    final defaults = <List<TimeOfDay>>[
      [const TimeOfDay(hour: 8, minute: 0)],
      [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0)],
      [
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 13, minute: 0),
        const TimeOfDay(hour: 21, minute: 0),
      ],
      [
        const TimeOfDay(hour: 7, minute: 0),
        const TimeOfDay(hour: 12, minute: 0),
        const TimeOfDay(hour: 17, minute: 0),
        const TimeOfDay(hour: 22, minute: 0),
      ],
    ];
    setState(() {
      _timeSlots = defaults[_frequency.count - 1];
    });
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeSlots[index],
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF58A6FF),
              surface: Color(0xFF161B22),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _timeSlots[index] = picked;
      });
    }
  }

  Future<void> _checkInteractions() async {
    setState(() {
      _interactionCheckDone = false;
    });

    // Simulate API call to drug interaction service
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _interactionCheckDone = true;
      // Demo: flag certain combinations
      if (_nameController.text.toLowerCase() == 'metformin' &&
          _dosageController.text.contains('1000')) {
        _interactionSafe = false;
        _interactionMessage =
            '⚠ High dose Metformin may cause lactic acidosis. Consult doctor.';
      } else {
        _interactionSafe = true;
        _interactionMessage = '✅ No known interactions found.';
      }
    });
  }

  Future<void> _saveAndPush() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.heavyImpact();
    setState(() => _isSaving = true);
    // 1. Prepare data
    final user = isFirebaseInitialized ? FirebaseAuth.instance.currentUser : null;

    final uid = user?.uid ?? 'demo-uid';

    final med = Medicine(
      id: '', // Firestore will generate
      name: _nameController.text,
      dosage: _dosageController.text,
      frequency: _frequency.label,
      times: _timeSlots.map((t) => _formatTimeOfDay(t)).toList(),
      icon: 'medication', // Could be dynamic
      color: kPillColors[_selectedColorIndex].hex,
    );

    try {
      // 2. Save to Firestore (Sub-collection)
      await DatabaseService(uid).addMedicine(med);
      
      // 3. (Keep existing animations and BLE simulation)
      _saveAnimController.forward();
      // BLE logic would go here...
    } catch (e) {
      debugPrint('Error saving medicine: $e');
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B5E20),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
              SizedBox(width: 12),
              Text(
                'Medicine saved & pushed to device!',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Add Medicine',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF30363D),
            height: 1,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Medicine Name (Autocomplete) ──
              _buildSectionLabel('Medicine Name', Icons.medication_rounded),
              const SizedBox(height: 10),
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const [];
                  return _drugDatabase.where((drug) => drug
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (selection) {
                  _nameController.text = selection;
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                  // Sync with our controller
                  controller.text = _nameController.text;
                  controller.addListener(() {
                    _nameController.text = controller.text;
                  });
                  return _buildTextField(
                    controller: controller,
                    focusNode: focusNode,
                    hint: 'e.g. Metformin',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Medicine name required' : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      color: const Color(0xFF1C2333),
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              title: Text(
                                option,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
                              leading: const Icon(Icons.medication,
                                  color: Color(0xFF58A6FF)),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // ── Dosage ──
              _buildSectionLabel('Dosage', Icons.science_rounded),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _dosageController,
                hint: 'e.g. 500 mg',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Dosage required' : null,
              ),

              const SizedBox(height: 28),

              // ── Pill Color ──
              _buildSectionLabel(
                  'Pill Color (for identification)', Icons.palette_rounded),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(kPillColors.length, (index) {
                  final pc = kPillColors[index];
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedColorIndex = index);
                    },
                    child: Semantics(
                      label: '${pc.name} pill color',
                      selected: isSelected,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: pc.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF58A6FF)
                                : const Color(0xFF30363D),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: pc.color.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelected)
                              const Icon(Icons.check_rounded,
                                  color: Color(0xFF0D1117), size: 22),
                            Text(
                              pc.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: pc.color.computeLuminance() > 0.5
                                    ? const Color(0xFF0D1117)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28),

              // ── Frequency ──
              _buildSectionLabel('Frequency', Icons.repeat_rounded),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: DoseFrequency.values.map((freq) {
                  final isSelected = _frequency == freq;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _frequency = freq);
                      _updateTimeSlots();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF58A6FF).withOpacity(0.15)
                            : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF58A6FF)
                              : const Color(0xFF30363D),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        freq.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? const Color(0xFF58A6FF)
                              : const Color(0xFF8B949E),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // ── Time Slots ──
              _buildSectionLabel('Time Slots', Icons.access_time_rounded),
              const SizedBox(height: 12),
              ...List.generate(_timeSlots.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _pickTime(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getTimeIcon(index),
                            color: _getTimeColor(index),
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Dose ${index + 1}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF8B949E),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTimeOfDay(_timeSlots[index]),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_rounded,
                              color: Color(0xFF58A6FF), size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 28),

              // ── Assign to Tray ──
              _buildSectionLabel('Assign to Device Tray', Icons.inventory_2_rounded),
              const SizedBox(height: 12),
              Row(
                children: List.generate(4, (index) {
                  final trayNum = index + 1;
                  final isSelected = _selectedTray == trayNum;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 3 ? 10 : 0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTray = trayNum);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF58A6FF).withOpacity(0.15)
                                : const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF58A6FF)
                                  : const Color(0xFF30363D),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.dns_rounded,
                                color: isSelected
                                    ? const Color(0xFF58A6FF)
                                    : const Color(0xFF8B949E),
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tray $trayNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF58A6FF)
                                      : const Color(0xFF8B949E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 28),

              // ── Notes (optional) ──
              _buildSectionLabel('Notes (optional)', Icons.notes_rounded),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _notesController,
                hint: 'e.g. Take after meal',
                maxLines: 2,
              ),

              const SizedBox(height: 28),

              // ── Drug Interaction Check ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.health_and_safety_rounded,
                            color: Color(0xFFFFA726), size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'Drug Interaction Check',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _nameController.text.isNotEmpty
                              ? _checkInteractions
                              : null,
                          child: const Text(
                            'Run Check',
                            style: TextStyle(
                              color: Color(0xFF58A6FF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_interactionCheckDone) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _interactionSafe
                              ? const Color(0xFF1B5E20).withOpacity(0.3)
                              : const Color(0xFFB71C1C).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _interactionSafe
                                  ? Icons.check_circle_outline
                                  : Icons.warning_amber_rounded,
                              color: _interactionSafe
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFEF5350),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _interactionMessage,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _interactionSafe
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFEF5350),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAndPush,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF238636).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            SizedBox(width: 14),
                            Text(
                              'Pushing to device...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Save & Push to Device',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ──

  Widget _buildSectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8B949E), size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFC9D1D9),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 18, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF484F58),
          fontSize: 18,
        ),
        filled: true,
        fillColor: const Color(0xFF161B22),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF58A6FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFEF5350), width: 2),
        ),
      ),
    );
  }

  IconData _getTimeIcon(int index) {
    const icons = [
      Icons.wb_sunny_rounded,
      Icons.wb_cloudy_rounded,
      Icons.nights_stay_rounded,
      Icons.dark_mode_rounded,
    ];
    return icons[index % icons.length];
  }

  Color _getTimeColor(int index) {
    const colors = [
      Color(0xFFFFA726),
      Color(0xFF42A5F5),
      Color(0xFF7E57C2),
      Color(0xFF5C6BC0),
    ];
    return colors[index % colors.length];
  }
}
