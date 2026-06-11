import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/need_model.dart';
import '../../../../services/volunteer_service.dart';
import '../../../reports/presentation/ai_scan_page.dart';
import 'volunteer_voice_observation.dart';
import 'volunteer_photo_observation.dart';

class VolunteerReportScreen extends StatefulWidget {
  const VolunteerReportScreen({super.key});

  @override
  State<VolunteerReportScreen> createState() => _VolunteerReportScreenState();
}

class _VolunteerReportScreenState extends State<VolunteerReportScreen>
    with SingleTickerProviderStateMixin {
  String _activeFlow = 'hub';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = 'Medical Hazard';
  String _selectedSeverity = 'Medium';
  bool _isAutoDetecting = false;
  bool _isAnalyzing = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Medical Hazard',
      'icon': Icons.medical_services_outlined,
      'color': const Color(0xFFEF4444),
    },
    {
      'name': 'Resource Shortage',
      'icon': Icons.inventory_2_outlined,
      'color': const Color(0xFF3B82F6),
    },
    {
      'name': 'Road Blockage',
      'icon': Icons.block_flipped,
      'color': const Color(0xFFF59E0B),
    },
    {
      'name': 'Infrastructure',
      'icon': Icons.foundation_outlined,
      'color': const Color(0xFF10B981),
    },
  ];

  final List<String> _severities = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _startVoiceReportSimulation() {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Listening view
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Color(0xFFEF4444),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Listening...',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '"There is a large tree down across the main road in Sector 3, blocking all ambulance access. Severity is high. We need cleanup crews."',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pop(context); // Close previous
        showModalBottomSheet<void>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    height: 80,
                    width: 80,
                    child: CircularProgressIndicator(
                      color: Color(0xFF4F46E5),
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gemini AI Analyzing...',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Extracting location, severity, and incident details...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );

        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) {
            Navigator.pop(context); // Close modal
            setState(() {
              _selectedCategory = 'Road Blockage';
              _selectedSeverity = 'High';
              _titleController.text = 'Road blocked by fallen tree in Sector 3';
              _descController.text =
                  'A large tree has fallen across the main road in Sector 3, completely blocking all ambulance access. Needs immediate clearing crew.';
              _locationController.text =
                  '19.8762° N, 75.3433° E (Sector 3 - Pundlik Nagar)';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gemini extracted and auto-filled 5 report fields.',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF4F46E5),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    });
  }

  void _detectLocation() async {
    setState(() {
      _isAutoDetecting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      setState(() {
        _isAutoDetecting = false;
        _locationController.text =
            '19.8762° N, 75.3433° E (Sector 3 - Pundlik Nagar)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS Coordinates successfully captured.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      // Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ground Intelligence Uploaded\nNGO command center notified.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Simulate submission success dialog
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Intelligence Logged',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Your ground intelligence has been uploaded to Firestore and routed to the NGO command center.',
            style: GoogleFonts.inter(),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset form
                _titleController.clear();
                _descController.clear();
                _locationController.clear();
                setState(() {
                  _selectedCategory = 'Medical Hazard';
                  _selectedSeverity = 'Medium';
                });
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeFlow == 'hub') {
      return _buildHub(context);
    }
    return _buildStructuredReport(context);
  }

  Widget _buildHub(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Report Hub',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              ),
            );
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Section: Illustration area
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // Soft blue/grey
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // A stylized document icon
                        Container(
                          width: 90,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBFDBFE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 6,
                                color: const Color(0xFF3B82F6).withOpacity(0.5),
                                margin: const EdgeInsets.only(bottom: 12),
                              ),
                              Container(
                                width: 50,
                                height: 6,
                                color: const Color(0xFF3B82F6).withOpacity(0.5),
                                margin: const EdgeInsets.only(bottom: 12),
                              ),
                              Container(
                                width: 50,
                                height: 6,
                                color: const Color(0xFF3B82F6).withOpacity(0.5),
                                margin: const EdgeInsets.only(bottom: 12),
                              ),
                              Container(
                                width: 30,
                                height: 6,
                                color: const Color(0xFF3B82F6).withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                        // AI indicator circle
                        Positioned(
                          right: 40,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF93C5FD).withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'AI',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Small success check
                        Positioned(
                          right: 20,
                          top: 30,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                        // Small dot decoration
                        Positioned(
                          left: 40,
                          bottom: 40,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFDE68A),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD97706),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'What would you like to\nsubmit?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how to share your observation',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 40),

                // Option 1
                _buildOptionCard(
                  title: 'Voice observation',
                  subtitle:
                      'Speak naturally. AI structures the report automatically.',
                  iconData: Icons.mic_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  iconBgColor: const Color(0xFFEFF6FF),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VolunteerVoiceObservationScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Option 2
                _buildOptionCard(
                  title: 'Photo evidence',
                  subtitle:
                      'Capture evidence and generate an AI-assisted incident report.',
                  iconData: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFEF3C7),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VolunteerPhotoObservationScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Option 3
                _buildOptionCard(
                  title: 'Structured report',
                  subtitle: 'Fill detailed operational information manually.',
                  iconData: Icons.assignment_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFD1FAE5),
                  onTap: () {
                    setState(() {
                      _activeFlow = 'structured';
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData iconData,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(iconData, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredReport(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => setState(() => _activeFlow = 'hub'),
        ),
        title: Text(
          'Structured Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Prompt Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        color: Color(0xFF2563EB),
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Submit real-time ground intelligence. This will immediately notify dispatchers and update the tactical map.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E3A8A),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Gemini Voice-to-Report Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Voice Situation Report',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'AI ACTIVE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Speak naturally in your preferred language. Gemini Voice Intelligence will transcribe, extract critical facts, and auto-populate the form.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.95),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _startVoiceReportSimulation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4F46E5),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFF4F46E5),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Start Voice Report',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category Selection
                Text(
                  'Incident Category',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat['name'];
                      final color = cat['color'] as Color;
                      return ChoiceChip(
                        showCheckmark: false,
                        label: Row(
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat['name'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(
                              () => _selectedCategory = cat['name'] as String,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Short Title',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Water pipeline leak, shelter crowd size',
                    fillColor: Colors.white,
                  ),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 20),

                // Severity
                Text(
                  'Severity Level',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _severities.map((severity) {
                    final isSelected = _selectedSeverity == severity;
                    final Color color;
                    switch (severity) {
                      case 'Critical':
                        color = const Color(0xFFEF4444);
                        break;
                      case 'High':
                        color = const Color(0xFFF59E0B);
                        break;
                      case 'Medium':
                        color = const Color(0xFF3B82F6);
                        break;
                      default:
                        color = const Color(0xFF10B981);
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _selectedSeverity = severity),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isSelected
                                  ? color
                                  : const Color(0xFFCBD5E1),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            backgroundColor: isSelected
                                ? color.withValues(alpha: 0.08)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            severity,
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? color
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Description
                Text(
                  'Details & Observations',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Describe what you see and what immediate assistance is required...',
                    fillColor: Colors.white,
                  ),
                  validator: (v) => (v?.isEmpty ?? true)
                      ? 'Please describe the scenario'
                      : null,
                ),
                const SizedBox(height: 24),

                // Location detection
                Text(
                  'Location Pin',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'Capture coordinates or enter address',
                    fillColor: Colors.white,
                    suffixIcon: _isAutoDetecting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.my_location,
                              color: Color(0xFF5B888F),
                            ),
                            onPressed: _detectLocation,
                          ),
                  ),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Please define a location' : null,
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitReport,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Submit Ground Intelligence',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
