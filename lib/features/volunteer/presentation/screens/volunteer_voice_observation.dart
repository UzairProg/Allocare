import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../services/volunteer_service.dart';
import '../../../reports/application/ground_intelligence_service.dart';
import 'volunteer_ai_generated_report_screen.dart';

class VolunteerVoiceObservationScreen extends ConsumerStatefulWidget {
  const VolunteerVoiceObservationScreen({super.key});

  @override
  ConsumerState<VolunteerVoiceObservationScreen> createState() => _VolunteerVoiceObservationScreenState();
}

class _VolunteerVoiceObservationScreenState extends ConsumerState<VolunteerVoiceObservationScreen> with TickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isProcessing = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _audioPath;
  List<File> _supportingImages = [];
  
  // Location
  Position? _currentPosition;
  String _address = 'Detecting location...';
  DateTime? _locationUpdatedAt;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _processingController;
  late Animation<double> _waveformAnimation;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _initLocation();

    // Pulse animation for mic idle/recording
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Processing AI ring animation
    _processingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _waveformAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _pulseController.dispose();
    _processingController.dispose();
    super.dispose();
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
          _locationUpdatedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _address = 'Failed to get location');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() => _recordDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/ground_report_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordDuration = 0;
            _audioPath = path;
          });
          // Speed up pulse during recording
          _pulseController.duration = const Duration(milliseconds: 800);
          _pulseController.repeat(reverse: true);
        }
        
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      final path = await _audioRecorder.stop();
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessing = true;
        });
        _processingController.repeat();
      }

      if (path != null) {
        await _processReport(File(path));
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _processingController.stop();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording failed.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingController.stop();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }

  Future<void> _processReport(File audioFile) async {
    try {
      // Mock processing delay for demo
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingController.stop();
        });
        
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, animation, secondaryAnimation) => 
                VolunteerAIGeneratedReportScreen(
                  supportingImages: _supportingImages,
                  audioPath: audioFile.path,
                ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingController.stop();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _processReport(audioFile),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _supportingImages.add(File(pickedFile.path));
      });
    }
  }

  Widget _buildProcessingState() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 160,
              width: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing orb
                  AnimatedBuilder(
                    animation: _processingController,
                    builder: (context, child) {
                      return Container(
                        height: 120 + (math.sin(_processingController.value * math.pi * 4) * 20),
                        width: 120 + (math.sin(_processingController.value * math.pi * 4) * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4F46E5).withOpacity(0.1),
                        ),
                      );
                    },
                  ),
                  // Rotating dashed rings
                  AnimatedBuilder(
                    animation: _processingController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _processingController.value * math.pi * 2,
                        child: CustomPaint(
                          size: const Size(140, 140),
                          painter: DashedRingPainter(
                            color: const Color(0xFF4F46E5).withOpacity(0.3),
                            strokeWidth: 2,
                            dashes: 12,
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _processingController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: -_processingController.value * math.pi * 4,
                        child: CustomPaint(
                          size: const Size(100, 100),
                          painter: DashedRingPainter(
                            color: const Color(0xFF3B82F6).withOpacity(0.5),
                            strokeWidth: 3,
                            dashes: 8,
                          ),
                        ),
                      );
                    },
                  ),
                  // Center solid core
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Analyzing Field Intelligence',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Extracting observations, impact indicators and resource requirements.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) return _buildProcessingState();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 32),
                    _buildMicArea(),
                    const SizedBox(height: 24),
                    _buildRecordingText(),
                    const SizedBox(height: 32),
                    _buildLocationCard(),
                    const SizedBox(height: 24),
                    _buildEvidenceSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Voice Observation',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF3B82F6)),
                const SizedBox(width: 4),
                Text(
                  'AI Assisted',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'GROUND INTELLIGENCE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'What do you observe?',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Describe the situation naturally. AI will structure your observations into an actionable field report.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildMicArea() {
    final primaryColor = _isRecording ? const Color(0xFFBE123C) : const Color(0xFF4F46E5); // Lighter blue
    final glowColor = _isRecording ? const Color(0xFFE11D48) : const Color(0xFF6366F1);
    
    return GestureDetector(
      onTap: () {
        if (_isRecording) {
          _stopRecording();
        } else {
          _startRecording();
        }
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = _isRecording ? 1.0 + (_waveformAnimation.value * 0.20) : 1.0 + (_waveformAnimation.value * 0.08);
          
          return SizedBox(
            height: 200,
            width: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer subtle ring
                Transform.scale(
                  scale: scale + 0.2,
                  child: Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glowColor.withOpacity(0.08),
                    ),
                  ),
                ),
                // Middle translucent ring
                Transform.scale(
                  scale: scale,
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glowColor.withOpacity(0.15),
                    ),
                  ),
                ),
                // Inner solid AI orb (no mic icon)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 88,
                  width: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primaryColor, glowColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: _isRecording ? 12 * _waveformAnimation.value : 6,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordingText() {
    if (_isRecording) {
      return Column(
        children: [
          Text(
            'Listening...',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFBE123C), // Muted red
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_recordDuration),
            style: GoogleFonts.robotoMono(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFBE123C),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap again when finished',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFE11D48).withOpacity(0.8),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          'Tap to Speak',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Describe what you see. AI will structure\nand process your report.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF16A34A),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Location Verified',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _address,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                if (_locationUpdatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Updated just now',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supporting Evidence (Optional)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionCard(
              icon: Icons.camera_alt_rounded,
              title: 'Capture Photo',
              onTap: () => _pickImage(ImageSource.camera),
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildActionCard(
              icon: Icons.photo_library_rounded,
              title: 'Upload Evidence',
              onTap: () => _pickImage(ImageSource.gallery),
            )),
          ],
        ),
        if (_supportingImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_supportingImages.length} Supporting Image${_supportingImages.length > 1 ? 's' : ''} Attached',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _supportingImages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.9),
                      builder: (BuildContext context) {
                        return Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: EdgeInsets.zero,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: Image.file(
                                  _supportingImages[index],
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                top: 40,
                                right: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                      image: DecorationImage(
                        image: FileImage(_supportingImages[index]),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_out_map_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _supportingImages.removeAt(index));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: const Color(0xFF3B82F6)),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for Dashed Rings in Processing State
class DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashes;

  DashedRingPainter({required this.color, required this.strokeWidth, required this.dashes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final dashAngle = (math.pi * 2) / (dashes * 2);

    for (int i = 0; i < dashes * 2; i++) {
      if (i % 2 == 0) {
        final startAngle = i * dashAngle;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          dashAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
