import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../services/volunteer_service.dart';
import '../../../reports/application/ground_intelligence_service.dart';
import 'volunteer_ai_generated_report_screen.dart';

class VolunteerPhotoObservationScreen extends ConsumerStatefulWidget {
  const VolunteerPhotoObservationScreen({super.key});

  @override
  ConsumerState<VolunteerPhotoObservationScreen> createState() => _VolunteerPhotoObservationScreenState();
}

class _VolunteerPhotoObservationScreenState extends ConsumerState<VolunteerPhotoObservationScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _isAnalyzing = false;
  int _analysisStep = 0;
  
  // Location
  Position? _currentPosition;
  String _address = 'Detecting location...';
  
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _address = 'Location services disabled');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _address = 'Location permission denied');
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _address = '${position.latitude.toStringAsFixed(5)}° N, ${position.longitude.toStringAsFixed(5)}° E';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _address = 'Failed to get location');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
        if (pickedFiles.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(pickedFiles.map((f) => File(f.path)));
            _isAnalyzing = false;
            _analysisStep = 0;
          });
        }
      } else {
        final pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (pickedFile != null) {
          setState(() {
            _selectedImages.add(File(pickedFile.path));
            _isAnalyzing = false;
            _analysisStep = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Evidence',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildImageSourceCard(
                      icon: Icons.camera_alt_rounded,
                      title: 'Take Photo',
                      description: 'Use camera',
                      source: ImageSource.camera,
                      inBottomSheet: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildImageSourceCard(
                      icon: Icons.photo_library_rounded,
                      title: 'Upload',
                      description: 'From gallery',
                      source: ImageSource.gallery,
                      inBottomSheet: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewImageFullScreen(File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeWithAI() async {
    if (_selectedImages.isEmpty) return;
    
    setState(() {
      _isAnalyzing = true;
      _analysisStep = 1;
    });

    try {
      final volunteer = ref.read(currentVolunteerProvider).asData?.value;
      
      final contextData = {
        'volunteerName': volunteer?.displayName ?? 'Unknown',
        'ngoId': volunteer?.ngoId ?? 'Unknown',
        'location': _address,
        'missionId': volunteer?.currentMissionId ?? 'Unknown',
      };

      if (mounted) setState(() => _analysisStep = 2);

      final groundService = ref.read(groundIntelligenceServiceProvider);
      
      final result = await groundService.analyzeEvidence(
        audioFile: null,
        supportingImages: _selectedImages,
        contextData: contextData,
      );

      if (mounted) setState(() => _analysisStep = 4);
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) => 
              VolunteerAIGeneratedReportScreen(
                supportingImages: _selectedImages,
                audioPath: '',
                reportType: 'photo',
                aiAnalysisResult: result,
                appLocation: _address,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _analysisStep = 0;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisStep = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Photo Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF4F46E5)),
                const SizedBox(width: 4),
                Text(
                  'AI Assisted',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_selectedImages.isEmpty) _buildLandingState()
              else if (!_isAnalyzing) _buildPreviewState()
              else _buildAnalyzingState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandingState() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Text(
          'What are you seeing?',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Capture visual evidence from the field. AI will analyze the images and generate a structured intelligence report.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: _buildImageSourceCard(
                icon: Icons.camera_alt_rounded,
                title: 'Take Photo',
                description: 'Capture evidence using your camera.',
                source: ImageSource.camera,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildImageSourceCard(
                icon: Icons.photo_library_rounded,
                title: 'Upload Photo',
                description: 'Select images from your device.',
                source: ImageSource.gallery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _buildLocationCard(),
      ],
    );
  }

  Widget _buildImageSourceCard({
    required IconData icon,
    required String title,
    required String description,
    required ImageSource source,
    bool inBottomSheet = false,
  }) {
    return GestureDetector(
      onTap: () {
        if (inBottomSheet) Navigator.pop(context);
        _pickImage(source);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF4F46E5), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.my_location_rounded, color: Color(0xFF475569), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Verified',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _address,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
        ],
      ),
    );
  }

  Widget _buildPreviewState() {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _selectedImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                return _buildAddMoreCard();
              }
              return _buildImageThumbnail(_selectedImages[index], index);
            },
          ),
        ),
        const SizedBox(height: 24),
        _buildLocationCard(),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _analyzeWithAI,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 12),
                Text(
                  'ANALYZE MULTI-POINT INTEL',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => setState(() => _selectedImages.clear()),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'CLEAR EVIDENCE',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(File file, int index) {
    return GestureDetector(
      onTap: () => _viewImageFullScreen(file),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 4),
          image: DecorationImage(
            image: FileImage(file),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImages.removeAt(index);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.zoom_out_map, color: Colors.white, size: 16),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'EV-${index + 1}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMoreCard() {
    return GestureDetector(
      onTap: _showSourceBottomSheet,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF64748B), size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'Add More',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Deep Intelligence Scan',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cross-referencing ${_selectedImages.length} data points...',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                // Rapidly cycle through the images to simulate deep processing
                final cycleIndex = (_pulseController.value * _selectedImages.length * 6).floor() % _selectedImages.length;
                final activeImage = _selectedImages[cycleIndex];
                
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      activeImage,
                      fit: BoxFit.cover,
                      color: const Color(0xFF0F172A).withOpacity(0.4),
                      colorBlendMode: BlendMode.darken,
                    ),
                    // Grid overlay
                    CustomPaint(
                      painter: _GridPainter(_pulseController.value),
                    ),
                    // Sweeping scanner
                    Positioned(
                      top: _pulseController.value * 280,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.8),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4F46E5), width: 2),
                        ),
                        child: const Icon(
                          Icons.troubleshoot_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildProgressStep('Contextual Metadata Analyzed', _analysisStep >= 1),
              _buildProgressStep('Visual Crisis Vectors Mapped', _analysisStep >= 2),
              _buildProgressStep('Resource Allocation Predicted', _analysisStep >= 3),
              _buildProgressStep('Synthesizing Master Field Report', _analysisStep >= 4, isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStep(String text, bool isCompleted, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: isCompleted ? null : Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: isCompleted ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w500,
                color: isCompleted ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final double animationValue;

  _GridPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(0.15)
      ..strokeWidth = 1.0;

    const double spacing = 30;
    
    // Draw vertical lines
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    // Draw horizontal lines
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
