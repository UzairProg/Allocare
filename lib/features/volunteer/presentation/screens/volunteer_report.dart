import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VolunteerReportScreen extends StatefulWidget {
  const VolunteerReportScreen({super.key});

  @override
  State<VolunteerReportScreen> createState() => _VolunteerReportScreenState();
}

class _VolunteerReportScreenState extends State<VolunteerReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = 'Medical Hazard';
  String _selectedSeverity = 'Medium';
  bool _isAutoDetecting = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Medical Hazard', 'icon': Icons.medical_services_outlined, 'color': const Color(0xFFEF4444)},
    {'name': 'Resource Shortage', 'icon': Icons.inventory_2_outlined, 'color': const Color(0xFF3B82F6)},
    {'name': 'Road Blockage', 'icon': Icons.block_flipped, 'color': const Color(0xFFF59E0B)},
    {'name': 'Infrastructure', 'icon': Icons.foundation_outlined, 'color': const Color(0xFF10B981)},
  ];

  final List<String> _severities = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _detectLocation() async {
    setState(() {
      _isAutoDetecting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      setState(() {
        _isAutoDetecting = false;
        _locationController.text = '19.8762° N, 75.3433° E (Sector 3 - Pundlik Nagar)';
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
      // Simulate submission success
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 12),
              Text(
                'Report Logged',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Your field report has been uploaded to Firestore and routed to the NGO command center.',
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Field Report',
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
                      const Icon(Icons.campaign_outlined, color: Color(0xFF2563EB), size: 26),
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
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat['name'] as String);
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
                  validator: (v) => (v?.isEmpty ?? true) ? 'Please enter a title' : null,
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
                          onPressed: () => setState(() => _selectedSeverity = severity),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isSelected ? color : const Color(0xFFCBD5E1),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            backgroundColor: isSelected ? color.withOpacity(0.08) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            severity,
                            style: GoogleFonts.inter(
                              color: isSelected ? color : const Color(0xFF64748B),
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
                    hintText: 'Describe what you see and what immediate assistance is required...',
                    fillColor: Colors.white,
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Please describe the scenario' : null,
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
                            icon: const Icon(Icons.my_location, color: Color(0xFF5B888F)),
                            onPressed: _detectLocation,
                          ),
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Please define a location' : null,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Submit Field Report',
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
