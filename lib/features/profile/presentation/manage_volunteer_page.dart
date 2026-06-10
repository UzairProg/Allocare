import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/volunteer_model.dart';
import '../../../services/ngo_service.dart';
import '../../../services/volunteer_service.dart';

class ManageVolunteerPage extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final bool filterActiveOnField;

  const ManageVolunteerPage({
    super.key,
    this.initialTabIndex = 0,
    this.filterActiveOnField = false,
  });

  @override
  ConsumerState<ManageVolunteerPage> createState() => _ManageVolunteerPageState();
}

class _ManageVolunteerPageState extends ConsumerState<ManageVolunteerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _callContact(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ngoId = ref.watch(effectiveNgoIdProvider) ?? '';

    if (ngoId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workforce')),
        body: const Center(child: Text('User not authenticated.')),
      );
    }

    final pendingStream = ref.watch(volunteerServiceProvider).watchPendingByNgoId(ngoId);
    final approvedStream = ref.watch(volunteerServiceProvider).watchApprovedByNgoId(ngoId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Text(
          'Workforce Dashboard',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0284C7),
          indicatorWeight: 3,
          labelColor: const Color(0xFF0284C7),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'ACTIVE TEAM'),
            Tab(text: 'PENDING REQUESTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Active Team Panel
          StreamBuilder<List<VolunteerModel>>(
            stream: approvedStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var volunteers = snapshot.data!;
              if (widget.filterActiveOnField) {
                volunteers = volunteers.where((v) => v.isActiveOnField).toList();
              }
              if (volunteers.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.group_off_rounded,
                  title: widget.filterActiveOnField
                      ? 'No active members on field'
                      : 'No active members',
                  subtitle: widget.filterActiveOnField
                      ? 'Active on-field volunteers will appear here.'
                      : 'Approved volunteers will appear here.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: volunteers.length,
                itemBuilder: (context, index) {
                  final v = volunteers[index];
                  return _buildActiveVolunteerCard(context, v);
                },
              );
            },
          ),

          // TAB 2: Pending Requests Panel
          StreamBuilder<List<VolunteerModel>>(
            stream: pendingStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final volunteers = snapshot.data!;
              if (volunteers.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.mark_email_read_rounded,
                  title: 'No pending requests',
                  subtitle: 'All volunteer applications have been processed.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: volunteers.length,
                itemBuilder: (context, index) {
                  final v = volunteers[index];
                  return _buildPendingRequestCard(context, v);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVolunteerCard(BuildContext context, VolunteerModel volunteer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFF0FDF4),
                  radius: 22,
                  backgroundImage: volunteer.photoUrl != null && volunteer.photoUrl!.isNotEmpty
                      ? NetworkImage(volunteer.photoUrl!)
                      : null,
                  child: volunteer.photoUrl == null || volunteer.photoUrl!.isEmpty
                      ? Text(
                          volunteer.displayName.isNotEmpty ? volunteer.displayName[0].toUpperCase() : 'V',
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        volunteer.displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        volunteer.formattedSpecializations.isNotEmpty
                            ? volunteer.formattedSpecializations.join(', ')
                            : 'General Volunteer',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (volunteer.city.isNotEmpty || volunteer.state.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '📍 ${[volunteer.city, volunteer.state].where((s) => s.isNotEmpty).join(", ")}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (volunteer.phoneNumber.isNotEmpty)
                  IconButton(
                    onPressed: () => _callContact(volunteer.phoneNumber),
                    icon: const Icon(Icons.call_rounded, color: Color(0xFF0284C7)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F9FF),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: volunteer.skills
                  .map((skill) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          skill,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: volunteer.isActiveOnField ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  volunteer.isActiveOnField ? 'Active On-Field' : 'Standby / Offline',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: volunteer.isActiveOnField ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Text(
                  'Missions: ${volunteer.missionsCompleted} • Reports: ${volunteer.reportsSubmitted} • Lives: ${volunteer.livesImpacted}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestCard(BuildContext context, VolunteerModel volunteer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name & Role
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEFF6FF),
                  radius: 24,
                  backgroundImage: volunteer.photoUrl != null && volunteer.photoUrl!.isNotEmpty
                      ? NetworkImage(volunteer.photoUrl!)
                      : null,
                  child: volunteer.photoUrl == null || volunteer.photoUrl!.isEmpty
                      ? Text(
                          volunteer.displayName.isNotEmpty ? volunteer.displayName[0].toUpperCase() : 'V',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        volunteer.displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        volunteer.email,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (volunteer.city.isNotEmpty || volunteer.state.isNotEmpty) ...[
                            Text(
                              '📍 ${[volunteer.city, volunteer.state].where((s) => s.isNotEmpty).join(", ")}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'Applied: ${volunteer.createdAt.day}/${volunteer.createdAt.month}/${volunteer.createdAt.year}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            // Specialization & Skills
            Text(
              'SPECIALIZATION',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              volunteer.formattedSpecializations.isNotEmpty ? volunteer.formattedSpecializations.join(', ') : 'None',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'SKILLS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: volunteer.skills
                  .map((skill) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          skill,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Emergency Contact Info
            if (volunteer.emergencyContactName.isNotEmpty) ...[
              Text(
                'EMERGENCY CONTACT',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${volunteer.emergencyContactName} (${volunteer.emergencyContactRelation}) • ${volunteer.emergencyContactPhone}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Actions Buttons: Approve & Reject
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(volunteerServiceProvider).rejectVolunteer(volunteer.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Volunteer request rejected.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('REJECT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(volunteerServiceProvider).approveVolunteer(volunteer.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Volunteer approved successfully.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('APPROVE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
