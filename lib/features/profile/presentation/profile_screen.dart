import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/custom_card.dart';
import '../../../core/utils/primary_button.dart';
import '../../../models/app_user.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';
import 'manage_volunteer_page.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final authService = ref.watch(authServiceProvider);

    final demoProfile = AppUser(
      id: 'demo-user',
      email: 'aarav@foundation.org',
      displayName: 'Aarav Foundation',
      phoneNumber: '+91 98765 43210',
      role: AppUserRole.ngo,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final ui = _ProfileUiData.from(profile ?? demoProfile, authUser);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  const Color(0xFF5C8F96),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.screenHorizontalPadding,
                  16,
                  AppConstants.screenHorizontalPadding,
                  18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ui.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ui.subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _HeroStat(label: 'Missions', value: ui.missions),
                        _HeroDivider(),
                        _HeroStat(label: 'Served', value: ui.served),
                        _HeroDivider(),
                        _HeroStat(label: 'Reliability', value: ui.reliability),
                        _HeroDivider(),
                        _HeroStat(label: 'Rating', value: ui.rating),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              18,
              AppConstants.screenHorizontalPadding,
              0,
            ),
            child: Text(
              'NGO INVENTORY',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              12,
              AppConstants.screenHorizontalPadding,
              0,
            ),
            child: Column(
              children: [
                for (final item in ui.inventoryItems) ...[
                  _InventoryCard(item: item),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              8,
              AppConstants.screenHorizontalPadding,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'MANAGE VOLUNTEER',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManageVolunteerPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              12,
              AppConstants.screenHorizontalPadding,
              0,
            ),
            child: CustomCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < ui.teamMembers.length; i++) ...[
                    _TeamMemberTile(member: ui.teamMembers[i]),
                    if (i != ui.teamMembers.length - 1)
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              18,
              AppConstants.screenHorizontalPadding,
              0,
            ),
            child: Text(
              'RELIABILITY SCORES',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              12,
              AppConstants.screenHorizontalPadding,
              0,
            ),
            child: CustomCard(
              child: Column(
                children: [
                  for (int i = 0; i < ui.reliabilityScores.length; i++) ...[
                    _ScoreRow(score: ui.reliabilityScores[i]),
                    if (i != ui.reliabilityScores.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              18,
              AppConstants.screenHorizontalPadding,
              0,
            ),
            child: Text(
              'COLLABORATIONS',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              12,
              AppConstants.screenHorizontalPadding,
              12,
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1E8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final partner in ui.partners)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: partner.color.withValues(alpha: 0.12),
                            child: Icon(partner.icon, size: 12, color: partner.color),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            partner.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              0,
              AppConstants.screenHorizontalPadding,
              16,
            ),
            child: Column(
              children: [
                PrimaryButton(
                  label: 'Logout',
                  icon: Icons.logout,
                  onPressed: () {
                    authService.signOut();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  profile == null ? 'Using demo profile data until Firebase profile is available.' : 'Profile data loaded from Firebase.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileUiData {
  const _ProfileUiData({
    required this.displayName,
    required this.subtitle,
    required this.missions,
    required this.served,
    required this.reliability,
    required this.rating,
    required this.inventoryItems,
    required this.teamMembers,
    required this.reliabilityScores,
    required this.partners,
  });

  final String displayName;
  final String subtitle;
  final String missions;
  final String served;
  final String reliability;
  final String rating;
  final List<_InventoryItem> inventoryItems;
  final List<_TeamMember> teamMembers;
  final List<_ScoreItem> reliabilityScores;
  final List<_PartnerChip> partners;

  factory _ProfileUiData.from(AppUser profile, User? authUser) {
    final isDemo = profile.id == 'demo-user';
    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : authUser?.displayName?.trim().isNotEmpty ?? false
            ? authUser!.displayName!.trim()
            : 'Aarav Foundation';

    return _ProfileUiData(
      displayName: displayName,
      subtitle: isDemo
          ? 'Community NGO · Mumbai'
          : '${_roleLabel(profile.role)} · ${_locationFromEmail(authUser?.email)}',
      missions: isDemo ? '342' : '128',
      served: isDemo ? '12k' : '4.1k',
      reliability: isDemo ? '98%' : '95%',
      rating: isDemo ? '4.9' : '4.7',
      inventoryItems: isDemo
          ? const [
              _InventoryItem(
                title: 'Medical Kits',
                subtitle: 'Emergency + first aid',
                units: '72 units',
                icon: Icons.medication_outlined,
                accent: Color(0xFFE45B5B),
                progress: 0.74,
              ),
              _InventoryItem(
                title: 'Food Ration Kits',
                subtitle: '5-day family supply',
                units: '185 kits',
                icon: Icons.inventory_2_outlined,
                accent: Color(0xFFEEA24B),
                progress: 0.58,
              ),
              _InventoryItem(
                title: 'Counseling Hours',
                subtitle: 'Licensed therapists',
                units: '44 hrs',
                icon: Icons.event_note_rounded,
                accent: Color(0xFF6B8FC5),
                progress: 0.86,
              ),
            ]
          : const [
              _InventoryItem(
                title: 'Medical Kits',
                subtitle: 'Emergency + first aid',
                units: '72 units',
                icon: Icons.medication_outlined,
                accent: Color(0xFFE45B5B),
                progress: 0.74,
              ),
              _InventoryItem(
                title: 'Food Ration Kits',
                subtitle: '5-day family supply',
                units: '185 kits',
                icon: Icons.inventory_2_outlined,
                accent: Color(0xFFEEA24B),
                progress: 0.58,
              ),
              _InventoryItem(
                title: 'Counseling Hours',
                subtitle: 'Licensed therapists',
                units: '44 hrs',
                icon: Icons.event_note_rounded,
                accent: Color(0xFF6B8FC5),
                progress: 0.86,
              ),
            ],
      teamMembers: const [
        _TeamMember(
          name: 'Dr. Meera Joshi',
          role: 'Senior Medical Officer',
          tags: ['Emergency', 'Pediatrics', 'OB-GYN'],
          percent: '98%',
          avatarLabel: '👩‍⚕️',
          accent: Color(0xFF60A3A4),
        ),
        _TeamMember(
          name: 'Rohan Kapoor',
          role: 'Logistics Coordinator',
          tags: ['Supply Chain', 'Mapping'],
          percent: '95%',
          avatarLabel: '👨‍💼',
          accent: Color(0xFF8A9EC9),
        ),
        _TeamMember(
          name: 'Ananya Singh',
          role: 'Mental Health Counselor',
          tags: ['CBT', 'Trauma', 'Youth'],
          percent: '100%',
          avatarLabel: '👩‍🏫',
          accent: Color(0xFF7BA56B),
        ),
      ],
      reliabilityScores: const [
        _ScoreItem(label: 'On-time Arrivals', percent: 0.98, value: '98%'),
        _ScoreItem(label: 'Report Accuracy', percent: 0.94, value: '94%'),
        _ScoreItem(label: 'Mission Completion', percent: 1.0, value: '100%'),
        _ScoreItem(label: 'Community Feedback', percent: 0.92, value: '92%'),
      ],
      partners: const [
        _PartnerChip(label: 'Red Cross India', icon: Icons.circle, color: Color(0xFFE45B5B)),
        _PartnerChip(label: 'FSSAI', icon: Icons.eco, color: Color(0xFF9CC24A)),
        _PartnerChip(label: 'iCall', icon: Icons.favorite, color: Color(0xFF5B88E5)),
        _PartnerChip(label: 'MCGM', icon: Icons.account_balance, color: Color(0xFF627A9C)),
        _PartnerChip(label: 'UN-WFP', icon: Icons.public, color: Color(0xFF4CA9A2)),
      ],
    );
  }

  static String _roleLabel(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return 'Community NGO';
      case AppUserRole.volunteer:
        return 'Volunteer';
      case AppUserRole.ngo:
        return 'Community NGO';
    }
  }

  static String _locationFromEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Community';
    }

    final domain = email.split('@').last;
    final base = domain.split('.').first;
    if (base.trim().isEmpty) {
      return 'Community';
    }

    return '${base.substring(0, 1).toUpperCase()}${base.substring(1)}';
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.24),
    );
  }
}

class _InventoryItem {
  const _InventoryItem({
    required this.title,
    required this.subtitle,
    required this.units,
    required this.icon,
    required this.accent,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final String units;
  final IconData icon;
  final Color accent;
  final double progress;
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item});

  final _InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D2A30).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF0E8D5),
                    valueColor: AlwaysStoppedAnimation<Color>(item.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.units.split(' ').first,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF5D7C84),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                item.units.split(' ').skip(1).join(' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamMember {
  const _TeamMember({
    required this.name,
    required this.role,
    required this.tags,
    required this.percent,
    required this.avatarLabel,
    required this.accent,
  });

  final String name;
  final String role;
  final List<String> tags;
  final String percent;
  final String avatarLabel;
  final Color accent;
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.member});

  final _TeamMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: member.accent.withValues(alpha: 0.12),
            child: Text(member.avatarLabel, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.role,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in member.tags)
                      Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: const Color(0xFFF2EDD7),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            member.percent,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF26A39C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreItem {
  const _ScoreItem({
    required this.label,
    required this.percent,
    required this.value,
  });

  final String label;
  final double percent;
  final String value;
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.score});

  final _ScoreItem score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            score.label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score.percent,
              minHeight: 5,
              backgroundColor: const Color(0xFFF0E8D5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2AA492)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Text(
            score.value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerChip {
  const _PartnerChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
