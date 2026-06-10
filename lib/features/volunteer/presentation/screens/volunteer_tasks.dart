import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VolunteerTasksScreen extends StatefulWidget {
  const VolunteerTasksScreen({super.key});

  @override
  State<VolunteerTasksScreen> createState() => _VolunteerTasksScreenState();
}

class _VolunteerTasksScreenState extends State<VolunteerTasksScreen> with SingleTickerProviderStateMixin {
  int _selectedSegment = 0; // 0 = Assigned, 1 = Available Pool

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Field Tasks',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSegment = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedSegment == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _selectedSegment == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'My Tasks (2)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedSegment == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSegment = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedSegment == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _selectedSegment == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Available Pool (4)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedSegment == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _selectedSegment == 0 ? _buildMyTasksList(theme) : _buildAvailablePoolList(theme),
    );
  }

  Widget _buildMyTasksList(ThemeData theme) {
    final myTasks = [
      {
        'title': 'Deliver First Aid Supplies',
        'desc': 'Bring 2 emergency medical kits from HQ to Shelter 3.',
        'location': 'Sector 3 - Pundlik Nagar Shelter',
        'distance': '1.4 km away',
        'priority': 'Critical',
        'status': 'In Progress',
        'color': const Color(0xFFEF4444),
      },
      {
        'title': 'Setup Emergency Water Point',
        'desc': 'Help deploy clean water tanks in CIDCO playground area.',
        'location': 'Sector 4 - CIDCO Grounds',
        'distance': '2.8 km away',
        'priority': 'Medium',
        'status': 'Assigned',
        'color': const Color(0xFFF59E0B),
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: myTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final task = myTasks[index];
        return _buildTaskCard(
          task: task,
          theme: theme,
          actions: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.navigation_outlined, size: 16),
              label: const Text('Navigate'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Task marked as Completed. Good job!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvailablePoolList(ThemeData theme) {
    final poolTasks = [
      {
        'title': 'Ration Box Sorting',
        'desc': 'Unload and sort grocery supplies received at Sector 1 hub.',
        'location': 'Sector 1 Hub - Railway Station Rd',
        'distance': '0.8 km away',
        'priority': 'Low',
        'status': 'Open',
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Elderly Care Assistance',
        'desc': 'Help transport mobility-restricted senior citizens to safety camps.',
        'location': 'Sector 2 - HUDCO Sector B',
        'distance': '3.1 km away',
        'priority': 'Critical',
        'status': 'Open',
        'color': const Color(0xFFEF4444),
      },
      {
        'title': 'Blanket Distribution',
        'desc': 'Distribute 50 blankets at the temporary night shelter.',
        'location': 'Sector 3 - Pundlik Nagar Shelter',
        'distance': '1.4 km away',
        'priority': 'Medium',
        'status': 'Open',
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Debris Clearing',
        'desc': 'Assist in clearing main access road from fallen branches.',
        'location': 'Sector 4 - Jalna Road Crossing',
        'distance': '4.5 km away',
        'priority': 'Medium',
        'status': 'Open',
        'color': const Color(0xFFF59E0B),
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: poolTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final task = poolTasks[index];
        return _buildTaskCard(
          task: task,
          theme: theme,
          actions: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task accepted! It has been added to My Tasks.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Accept Task'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard({
    required Map<String, dynamic> task,
    required ThemeData theme,
    required List<Widget> actions,
  }) {
    final priorityColor = task['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title and Priority Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task['title'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task['priority'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task['desc'] as String,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          // Metadata: Location & Distance
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task['location'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                task['distance'] as String,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions,
          ),
        ],
      ),
    );
  }
}
