import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'report_detail_page.dart';

class ReportsCenterPage extends StatefulWidget {
  const ReportsCenterPage({super.key});

  @override
  State<ReportsCenterPage> createState() => _ReportsCenterPageState();
}

class _ReportsCenterPageState extends State<ReportsCenterPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';

  final Map<String, _CategoryConfig> _categories = {
    'all': _CategoryConfig(
      'All Categories',
      Icons.grid_view_rounded,
      Colors.black,
    ),
    'medical': _CategoryConfig(
      'Medical Support',
      Icons.medical_services_rounded,
      Colors.red,
    ),
    'fire': _CategoryConfig(
      'Fire Emergency',
      Icons.local_fire_department_rounded,
      Colors.orange,
    ),
    'police': _CategoryConfig(
      'Police/Security',
      Icons.local_police_rounded,
      Colors.blue,
    ),
    'accident': _CategoryConfig(
      'Road Accident',
      Icons.car_crash_rounded,
      Colors.amber,
    ),
    'infrastructure': _CategoryConfig(
      'Infrastructure',
      Icons.construction_rounded,
      Colors.teal,
    ),
    'natural_disaster': _CategoryConfig(
      'Natural Disaster',
      Icons.thunderstorm_rounded,
      Colors.purple,
    ),
    'other': _CategoryConfig(
      'General/Other',
      Icons.report_problem_rounded,
      Colors.grey,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Reports Center',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search reports by title or description...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Category Filter Scroll
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: _categories.entries.map((entry) {
                      final isSelected = _selectedCategory == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(entry.value.label),
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = entry.key;
                            });
                          },
                          backgroundColor: const Color(0xFFF1F5F9),
                          selectedColor: entry.value.color.withValues(
                            alpha: 0.9,
                          ),
                          checkmarkColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? entry.value.color
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Reports Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('needs').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading reports: ${snapshot.error}'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                // Sort in memory by timestamp/createdAt safely
                final sortedDocs = docs.toList()
                  ..sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final tsA =
                        dataA['createdAt'] as Timestamp? ??
                        dataA['timestamp'] as Timestamp?;
                    final tsB =
                        dataB['createdAt'] as Timestamp? ??
                        dataB['timestamp'] as Timestamp?;
                    if (tsA == null && tsB == null) return 0;
                    if (tsA == null) return 1;
                    if (tsB == null) return -1;
                    return tsB.compareTo(tsA); // Descending order
                  });

                // Apply Filters
                final filteredDocs = sortedDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final desc = (data['description'] ?? '')
                      .toString()
                      .toLowerCase();
                  final category = (data['category'] ?? '')
                      .toString()
                      .toLowerCase();

                  final matchesSearch =
                      title.contains(_searchQuery) ||
                      desc.contains(_searchQuery);
                  final matchesCategory =
                      _selectedCategory == 'all' ||
                      category == _selectedCategory;

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_off_rounded,
                              size: 48,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Reports Found',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No reports matched your search criteria.'
                                : 'Upload reports via AI scan page to get started.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _ReportCard(reportId: doc.id, report: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _CategoryConfig(this.label, this.icon, this.color);
}

class _ReportCard extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> report;

  const _ReportCard({required this.reportId, required this.report});

  @override
  Widget build(BuildContext context) {
    final title = report['title']?.toString() ?? 'Untitled Incident';
    final rawCategory = report['category']?.toString() ?? 'other';
    final status = report['status']?.toString() ?? 'open';

    // Resolve timestamp
    final ts =
        report['createdAt'] as Timestamp? ?? report['timestamp'] as Timestamp?;
    final timeStr = ts != null ? _timeAgo(ts.toDate()) : 'Recently';

    // Get config for category
    final categoryKey = _categoriesMap[rawCategory.toLowerCase()] ?? 'other';
    final config = _categoryConfigs[categoryKey]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (reportId.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportDetailsPage(
                    reportId: reportId,
                    reportData: report,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: config.color, width: 4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Category Badge & Status Badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: config.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(config.icon, color: config.color, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                config.label.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: config.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Description / Summary
                    Text(
                      report['description']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    // Bottom Row: Uploaded by & Timestamp & Details CTA
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: report['reportedBy'] == null ||
                                  report['reportedBy'].toString().trim().isEmpty
                              ? Text(
                                  'By Allocare Agent',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                )
                              : FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(report['reportedBy'].toString())
                                      .get(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData &&
                                        snapshot.data!.exists) {
                                      final uData = snapshot.data!.data()
                                          as Map<String, dynamic>?;
                                      final uName =
                                          uData?['displayName']?.toString() ??
                                              '';
                                      return Text(
                                        uName.isNotEmpty
                                            ? 'By $uName'
                                            : 'By Commander',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      );
                                    }
                                    return Text(
                                      'By Allocare Agent',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Details',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: config.color,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: config.color,
                              size: 14,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color badgeColor;
    final String label;

    switch (status.toLowerCase()) {
      case 'open':
        badgeColor = const Color(0xFF2563EB); // active blue
        label = 'Active';
        break;
      case 'resolved':
      case 'closed':
        badgeColor = const Color(0xFF10B981); // green
        label = 'Resolved';
        break;
      case 'pending':
        badgeColor = const Color(0xFFD97706); // orange
        label = 'Pending';
        break;
      default:
        badgeColor = const Color(0xFF64748B); // grey
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Configurations mapping
  static const Map<String, String> _categoriesMap = {
    'medical': 'medical',
    'fire': 'fire',
    'police': 'police',
    'accident': 'accident',
    'infrastructure': 'infrastructure',
    'natural_disaster': 'natural_disaster',
    'other': 'other',
  };

  static final Map<String, _CategoryConfig> _categoryConfigs = {
    'medical': const _CategoryConfig(
      'Medical',
      Icons.medical_services_rounded,
      Colors.red,
    ),
    'fire': const _CategoryConfig(
      'Fire Incident',
      Icons.local_fire_department_rounded,
      Colors.orange,
    ),
    'police': const _CategoryConfig(
      'Police/Security',
      Icons.local_police_rounded,
      Colors.blue,
    ),
    'accident': const _CategoryConfig(
      'Road Accident',
      Icons.car_crash_rounded,
      Colors.amber,
    ),
    'infrastructure': const _CategoryConfig(
      'Infrastructure',
      Icons.construction_rounded,
      Colors.teal,
    ),
    'natural_disaster': const _CategoryConfig(
      'Disaster',
      Icons.thunderstorm_rounded,
      Colors.purple,
    ),
    'other': const _CategoryConfig(
      'Incident',
      Icons.report_problem_rounded,
      Colors.grey,
    ),
  };
}
