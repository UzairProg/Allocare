import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VolunteerMapScreen extends StatefulWidget {
  const VolunteerMapScreen({super.key});

  @override
  State<VolunteerMapScreen> createState() => _VolunteerMapScreenState();
}

class _VolunteerMapScreenState extends State<VolunteerMapScreen> {
  bool _layerAlerts = true;
  bool _layerShelters = true;
  bool _layerResponders = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Dark tactical background
      body: Stack(
        children: [
          // Mock Map Area (Stylized to look like a high-tech dark mode GPS)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F172A),
              child: CustomPaint(
                painter: _TacticalMapGridPainter(),
                child: Stack(
                  children: [
                    // Sector Labels
                    Positioned(
                      top: 100,
                      left: 60,
                      child: _buildSectorLabel('SECTOR 1 - NORTH'),
                    ),
                    Positioned(
                      top: 250,
                      right: 80,
                      child: _buildSectorLabel('SECTOR 3 - EAST (ACTIVE)'),
                    ),
                    Positioned(
                      bottom: 200,
                      left: 120,
                      child: _buildSectorLabel('SECTOR 2 - SOUTH'),
                    ),

                    // Tactical Markers
                    if (_layerAlerts) ...[
                      // Pundlik Nagar Critical Incident Marker
                      Positioned(
                        top: 240,
                        left: 210,
                        child: _buildTacticalMarker(
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFEF4444),
                          label: 'Critical: Supplies Request',
                        ),
                      ),
                      Positioned(
                        top: 420,
                        right: 70,
                        child: _buildTacticalMarker(
                          icon: Icons.medical_services_outlined,
                          color: const Color(0xFFF59E0B),
                          label: 'Medical tent B',
                        ),
                      ),
                    ],

                    if (_layerShelters) ...[
                      Positioned(
                        top: 150,
                        right: 140,
                        child: _buildTacticalMarker(
                          icon: Icons.gite_outlined,
                          color: const Color(0xFF10B981),
                          label: 'CIDCO Shelter 2',
                        ),
                      ),
                      Positioned(
                        bottom: 180,
                        left: 100,
                        child: _buildTacticalMarker(
                          icon: Icons.gite_outlined,
                          color: const Color(0xFF10B981),
                          label: 'Railway Station Shelter 1',
                        ),
                      ),
                    ],

                    if (_layerResponders) ...[
                      Positioned(
                        top: 290,
                        left: 140,
                        child: _buildTacticalMarker(
                          icon: Icons.navigation_rounded,
                          color: const Color(0xFF3B82F6),
                          label: 'My Position',
                          angle: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 50, bottom: 16, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tactical HUD Map',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Sector 3 - Pundlik Nagar Area Focus',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gps_fixed_rounded, color: Color(0xFF5B888F), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'GPS ACTIVE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Controls Panel (Right Side)
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                _buildMapControlFAB(
                  icon: Icons.my_location,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Centering on device GPS position...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMapControlFAB(
                  icon: Icons.add,
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _buildMapControlFAB(
                  icon: Icons.remove,
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Bottom Filter Panel
          Positioned(
            bottom: 30,
            left: 20,
            right: 90, // Leave space for map control FABs
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xEC1E293B), // Translucent dark
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HUD Layers',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLayerToggle(
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFEF4444),
                        isActive: _layerAlerts,
                        onTap: () => setState(() => _layerAlerts = !_layerAlerts),
                      ),
                      _buildLayerToggle(
                        icon: Icons.gite_outlined,
                        color: const Color(0xFF10B981),
                        isActive: _layerShelters,
                        onTap: () => setState(() => _layerShelters = !_layerShelters),
                      ),
                      _buildLayerToggle(
                        icon: Icons.navigation_rounded,
                        color: const Color(0xFF3B82F6),
                        isActive: _layerResponders,
                        onTap: () => setState(() => _layerResponders = !_layerResponders),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorLabel(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF475569),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTacticalMarker({
    required IconData icon,
    required Color color,
    required String label,
    double angle = 0.0,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapControlFAB({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildLayerToggle({
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : const Color(0xFF475569),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? color : const Color(0xFF94A3B8), size: 16),
            const SizedBox(width: 6),
            Text(
              isActive ? 'ON' : 'OFF',
              style: GoogleFonts.inter(
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter to draw tactical coordinates and radar grid
class _TacticalMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.2)
      ..strokeWidth = 1.0;

    final radarPaint = Paint()
      ..color = const Color(0xFF475569).withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw Grid lines
    const double gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw Radar/Range rings
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 100, radarPaint);
    canvas.drawCircle(center, 220, radarPaint);
    canvas.drawCircle(center, 340, radarPaint);

    // Crosshairs
    canvas.drawLine(Offset(center.dx - 15, center.dy), Offset(center.dx + 15, center.dy), radarPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 15), Offset(center.dx, center.dy + 15), radarPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
