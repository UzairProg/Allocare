import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/auth_service.dart';
import '../../../../features/reports/presentation/report_detail_page.dart';

class VolunteerMissionHistoryPage extends ConsumerStatefulWidget {
  const VolunteerMissionHistoryPage({super.key});

  @override
  ConsumerState<VolunteerMissionHistoryPage> createState() => _VolunteerMissionHistoryPageState();
}

class _VolunteerMissionHistoryPageState extends ConsumerState<VolunteerMissionHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _selectedDate;

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).asData?.value;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mission History')),
        body: const Center(child: Text('User not found')),
      );
    }

    final volunteerId = currentUser.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFDFE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mission History',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Your completed response missions',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_selectedDate != null)
            TextButton(
              onPressed: () {
                setState(() => _selectedDate = null);
              },
              child: Text(
                'Clear',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              _selectedDate != null ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              color: _selectedDate != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            tooltip: 'Filter by Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF2563EB),
                        onPrimary: Colors.white,
                        onSurface: Color(0xFF0F172A),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('needs')
            .where('assignedVolunteerId', isEqualTo: volunteerId)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)));
          }

          final docs = snapshot.data?.docs ?? [];
          var filteredDocs = docs.toList();

          if (_selectedDate != null) {
            filteredDocs = filteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['completedAt'] as Timestamp? ?? data['createdAt'] as Timestamp? ?? data['timestamp'] as Timestamp?;
              if (ts == null) return false;
              final date = ts.toDate();
              return date.year == _selectedDate!.year &&
                     date.month == _selectedDate!.month &&
                     date.day == _selectedDate!.day;
            }).toList();
          }

          // Sort descending by completion or created time
          final sortedDocs = filteredDocs..sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final tsA = dataA['completedAt'] as Timestamp? ?? dataA['createdAt'] as Timestamp? ?? dataA['timestamp'] as Timestamp?;
            final tsB = dataB['completedAt'] as Timestamp? ?? dataB['createdAt'] as Timestamp? ?? dataB['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA);
          });

          if (sortedDocs.isEmpty) {
            return _buildEmptyState();
          }

          // Calculate Analytics
          int livesImpacted = 0;
          int totalMissions = sortedDocs.length;
          int totalResponseMins = 0;
          int responseCount = 0;

          for (final doc in sortedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final impact = data['peopleAffected'] ?? data['estImpactNum'] ?? 0;
            if (impact is num) {
              livesImpacted += impact.toInt();
            } else if (impact is String) {
              livesImpacted += int.tryParse(impact) ?? 0;
            }

            final acceptedTs = data['acceptedAt'] as Timestamp?;
            final arrivedTs = data['arrivedAt'] as Timestamp? ?? data['completedAt'] as Timestamp?;
            if (acceptedTs != null && arrivedTs != null) {
              final diff = arrivedTs.toDate().difference(acceptedTs.toDate()).inMinutes;
              if (diff >= 0 && diff < 600) { // sanity check
                totalResponseMins += diff;
                responseCount++;
              }
            }
          }

          final avgResponseTime = responseCount > 0 ? totalResponseMins ~/ responseCount : 0;

          return Column(
            children: [
              // Header Summary Chip Area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '$totalMissions Missions Completed',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Analytics Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Lives Impacted',
                        livesImpacted.toString(),
                        Icons.volunteer_activism_rounded,
                        const Color(0xFF2563EB),
                        const Color(0xFFEFF6FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Total Missions',
                        totalMissions.toString(),
                        Icons.check_circle_rounded,
                        const Color(0xFF10B981),
                        const Color(0xFFECFDF5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Avg Response',
                        avgResponseTime > 0 ? _formatDuration(avgResponseTime) : '--',
                        Icons.timer_rounded,
                        const Color(0xFF3B82F6),
                        const Color(0xFFEFF6FF),
                      ),
                    ),
                  ],
                ),
              ),

              // Mission List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    return _buildMissionCard(context, doc, index);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(BuildContext context, DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title']?.toString() ?? 'Emergency Mission';
    final location = data['location']?.toString() ?? data['sector']?.toString() ?? 'Unknown Location';
    final category = data['category']?.toString() ?? 'General';
    final catColor = _getCategoryColor(category);
    final impact = data['peopleAffected'] ?? data['estImpactNum'] ?? 0;
    
    // Timeline
    final completedTs = data['completedAt'] as Timestamp? ?? data['createdAt'] as Timestamp?;
    final dateStr = completedTs != null 
        ? '${completedTs.toDate().day} ${_getMonth(completedTs.toDate().month)} ${completedTs.toDate().year}'
        : 'Unknown Date';

    // Response time
    String responseTimeStr = '--';
    final acceptedTs = data['acceptedAt'] as Timestamp?;
    final arrivedTs = data['arrivedAt'] as Timestamp? ?? data['completedAt'] as Timestamp?;
    if (acceptedTs != null && arrivedTs != null) {
      final diff = arrivedTs.toDate().difference(acceptedTs.toDate()).inMinutes;
      if (diff >= 0 && diff < 600) {
        responseTimeStr = _formatDuration(diff);
      }
    }

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => ReportDetailsPage(
                    reportId: doc.id,
                    reportData: data,
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Title & Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Second Row: Location & Category
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: catColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getCategoryIcon(category), size: 12, color: catColor),
                            const SizedBox(width: 4),
                            Text(
                              _getCategoryLabel(category).toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: catColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Third Row: Date & Response Time
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: const Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.timer_outlined, size: 13, color: const Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        responseTimeStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),

                  // Bottom Row: Impact Summary
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.volunteer_activism_rounded, size: 14, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$impact People Assisted',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Mission History Yet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed missions will appear here once you begin responding to incidents.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'medical': return Icons.medical_services_rounded;
      case 'fire': return Icons.local_fire_department_rounded;
      case 'police': return Icons.local_police_rounded;
      case 'accident': return Icons.car_crash_rounded;
      case 'infrastructure': return Icons.construction_rounded;
      case 'natural_disaster': return Icons.thunderstorm_rounded;
      default: return Icons.report_problem_rounded;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'medical': return 'Medical';
      case 'fire': return 'Fire';
      case 'police': return 'Security';
      case 'accident': return 'Accident';
      case 'infrastructure': return 'Infrastructure';
      case 'natural_disaster': return 'Disaster';
      default: return 'General';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'medical': return const Color(0xFFEF4444); // Red
      case 'fire': return const Color(0xFFF97316); // Orange
      case 'police': return const Color(0xFF3B82F6); // Blue
      case 'accident': return const Color(0xFFF59E0B); // Amber
      case 'infrastructure': return const Color(0xFF14B8A6); // Teal
      case 'natural_disaster': return const Color(0xFF8B5CF6); // Purple
      default: return const Color(0xFF64748B); // Slate
    }
  }
}
