import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/custom_card.dart';
import '../../../core/utils/primary_button.dart';
import '../../../models/app_user.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';
import 'manage_ngo_inventory_page.dart';
import 'manage_volunteer_page.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const MethodChannel _pnvChannel = MethodChannel('com.example.allocare_app/pnv');

  bool _isVerifyingPhone = false;
  String? _verifiedPhone;

  void _showVerificationSuccessToast(String phone) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F7A47),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Identity confirmed via OTP-less Firebase PNV. $phone is now verified.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistVerifiedPhone(String verifiedPhone) async {
    final profileService = ref.read(userProfileServiceProvider);
    final authUser = ref.read(authStateProvider).asData?.value;

    if (authUser == null) {
      return;
    }

    final existing = await profileService.getById(authUser.uid);
    final now = DateTime.now();

    final updated = AppUser(
      id: authUser.uid,
      email: authUser.email ?? existing?.email ?? '',
      displayName: (authUser.displayName ?? existing?.displayName ?? '').trim(),
      phoneNumber: verifiedPhone,
      role: existing?.role ?? AppUserRole.ngo,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      inventoryItems: existing?.inventoryItems ?? const [],
    );

    await profileService.upsert(updated);
  }

  Future<void> _verifyPhone() async {
    setState(() => _isVerifyingPhone = true);

    try {
      final response = await _pnvChannel.invokeMethod<Map<dynamic, dynamic>>('getVerifiedPhone');
      final phone = (response?['phoneNumber'] as String?)?.trim();

      if (phone != null && phone.isNotEmpty) {
        await _persistVerifiedPhone(phone);
      }

      if (!mounted) return;
      setState(() {
        _verifiedPhone = phone;
      });

      if (phone != null && phone.isNotEmpty) {
        _showVerificationSuccessToast(phone);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number verified.')),
        );
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone verification failed: ${error.message ?? error.code}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone verification failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingPhone = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final authService = ref.watch(authServiceProvider);
    final hasVerifiedPhone = _verifiedPhone != null && _verifiedPhone!.isNotEmpty;

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
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: hasVerifiedPhone
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text('Phone verification is pending. Please verify to continue.'),
                                    ),
                                  );
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: hasVerifiedPhone
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : const Color(0xFFFFF1C4).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: hasVerifiedPhone
                                    ? Colors.white.withValues(alpha: 0.24)
                                    : const Color(0xFFE7B22B),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasVerifiedPhone ? Icons.verified_rounded : Icons.help_rounded,
                                  size: 14,
                                  color: hasVerifiedPhone ? Colors.white : const Color(0xFF9A6A00),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasVerifiedPhone ? 'Verified' : 'Verify',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: hasVerifiedPhone ? Colors.white : const Color(0xFF7A5300),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
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
              14,
              AppConstants.screenHorizontalPadding,
              0,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: _verifiedPhone != null && _verifiedPhone!.isNotEmpty
                    ? const LinearGradient(
                        colors: [Color(0xFFE8F9F0), Color(0xFFD3F4E2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFF8F9FF), Color(0xFFEFF3FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _verifiedPhone != null && _verifiedPhone!.isNotEmpty
                      ? const Color(0xFF2AA866).withValues(alpha: 0.55)
                      : const Color(0xFF5078D1).withValues(alpha: 0.25),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_verifiedPhone != null && _verifiedPhone!.isNotEmpty
                            ? const Color(0xFF2AA866)
                            : const Color(0xFF5078D1))
                        .withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _verifiedPhone != null && _verifiedPhone!.isNotEmpty
                              ? const Color(0xFF1A9A5A).withValues(alpha: 0.14)
                              : const Color(0xFF2F56B3).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _verifiedPhone != null && _verifiedPhone!.isNotEmpty
                              ? Icons.verified_rounded
                              : Icons.shield_moon_rounded,
                          color: _verifiedPhone != null && _verifiedPhone!.isNotEmpty
                              ? const Color(0xFF1A9A5A)
                              : const Color(0xFF2F56B3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _verifiedPhone != null && _verifiedPhone!.isNotEmpty
                                  ? 'Identity Verified'
                                  : 'Phone Verification Center',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _verifiedPhone != null && _verifiedPhone!.isNotEmpty
                                    ? const Color(0xFF0E6138)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'OTP-less verification powered by Firebase PNV.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _verifiedPhone != null && _verifiedPhone!.isNotEmpty
                                    ? const Color(0xFF1A7A4A)
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sim_card_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SIM-backed',
                              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_clock_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Instant secure check',
                              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!hasVerifiedPhone)
                    FilledButton.icon(
                      onPressed: _isVerifyingPhone ? null : _verifyPhone,
                      icon: _isVerifyingPhone
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_user_rounded),
                      label: Text(
                        _isVerifyingPhone
                            ? 'Verifying with Firebase PNV...'
                            : 'Start OTP-less Verification',
                      ),
                    ),
                  if (_verifiedPhone != null && _verifiedPhone!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1F9D55).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(0xFF1F9D55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.done_rounded, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your phone number is verified',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF0E6138),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _verifiedPhone!,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF164F35),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'NGO INVENTORY',
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
                        builder: (_) => const ManageNgoInventoryPage(),
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
            child: authUser == null
                ? const CustomCard(child: Center(child: CircularProgressIndicator()))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('inventory')
                        .where('ngo_id', isEqualTo: authUser.uid)
                        .limit(4)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CustomCard(child: Center(child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError) {
                        return CustomCard(child: Center(child: Text('Error loading inventory: ${snapshot.error}')));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return CustomCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'No inventory added yet',
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Add medical kits, food packs, shelter supplies, or any other NGO stock here.',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ManageNgoInventoryPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Inventory'),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (int i = 0; i < docs.length; i++) ...[
                            Builder(
                              builder: (context) {
                                final data = docs[i].data() as Map<String, dynamic>;
                                final title = data['title']?.toString() ?? 'Item';
                                final item = _InventoryItem(
                                  title: title,
                                  subtitle: data['description']?.toString() ?? 'Stock item',
                                  units: '${data['quantity'] ?? 0} ${data['unit'] ?? 'units'}',
                                  icon: _ProfileUiData._inventoryIconFor(i, title),
                                  accent: _ProfileUiData._inventoryColorFor(i),
                                  progress: ((data['quantity'] as num?)?.toDouble() ?? 0) > 0 ? 1.0 : 0.0,
                                );
                                return _InventoryCard(item: item);
                              },
                            ),
                            if (i != docs.length - 1) const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
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
              child: authUser == null
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('volunteers')
                          .where('ngo_id', isEqualTo: authUser.uid)
                          .limit(5)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(child: Text('Error loading team: ${snapshot.error}')),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.group_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No volunteers found.',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap Manage Volunteer to add one.',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (int i = 0; i < docs.length; i++) ...[
                              Builder(
                                builder: (context) {
                                  final data = docs[i].data() as Map<String, dynamic>;
                                  final status = data['status']?.toString() ?? 'offline';
                                  
                                  Color accentColor;
                                  String avatarLabel;
                                  String percentLabel;
                                  
                                  if (status == 'available') {
                                    accentColor = const Color(0xFF26A39C);
                                    avatarLabel = '🟢';
                                    percentLabel = 'Ready';
                                  } else if (status == 'on_mission') {
                                    accentColor = const Color(0xFFF59E0B);
                                    avatarLabel = '🟠';
                                    percentLabel = 'Deployed';
                                  } else {
                                    accentColor = const Color(0xFF94A3B8);
                                    avatarLabel = '⚪';
                                    percentLabel = 'Offline';
                                  }

                                  final member = _TeamMember(
                                    name: data['name']?.toString() ?? 'Unknown',
                                    role: data['speciality']?.toString() ?? 'General',
                                    tags: [status.replaceAll('_', ' ').toUpperCase()],
                                    percent: percentLabel,
                                    avatarLabel: avatarLabel,
                                    accent: accentColor,
                                  );

                                  return _TeamMemberTile(member: member);
                                },
                              ),
                              if (i != docs.length - 1)
                                Divider(
                                  height: 1,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                            ],
                          ],
                        );
                      },
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
      subtitle: 'Allocare Intelligence Node',
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
          : profile.inventoryItems.isNotEmpty
              ? profile.inventoryItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _InventoryItem(
                    title: item.title,
                    subtitle: item.subtitle,
                    units: item.units,
                    icon: _inventoryIconFor(index, item.title),
                    accent: _inventoryColorFor(index),
                    progress: item.progress,
                  );
                }).toList()
              : const [],
      teamMembers: const [
        _TeamMember(
          name: 'Dr. Meera Joshi',
          role: 'Senior Medical Officer',
          tags: ['Emergency', 'Pediatrics', 'OB-GYN'],
          percent: '98%',
          avatarLabel: '≡ƒæ⌐ΓÇìΓÜò∩╕Å',
          accent: Color(0xFF60A3A4),
        ),
        _TeamMember(
          name: 'Rohan Kapoor',
          role: 'Logistics Coordinator',
          tags: ['Supply Chain', 'Mapping'],
          percent: '95%',
          avatarLabel: '≡ƒæ¿ΓÇì≡ƒÆ╝',
          accent: Color(0xFF8A9EC9),
        ),
        _TeamMember(
          name: 'Ananya Singh',
          role: 'Mental Health Counselor',
          tags: ['CBT', 'Trauma', 'Youth'],
          percent: '100%',
          avatarLabel: '≡ƒæ⌐ΓÇì≡ƒÅ½',
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

  static IconData _inventoryIconFor(int index, String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('food') || normalized.contains('ration') || normalized.contains('meal')) {
      return Icons.restaurant_outlined;
    }
    if (normalized.contains('medical') || normalized.contains('medicine') || normalized.contains('kit')) {
      return Icons.medication_outlined;
    }
    if (normalized.contains('shelter') || normalized.contains('home') || normalized.contains('repair')) {
      return Icons.home_repair_service_outlined;
    }
    if (normalized.contains('counsel') || normalized.contains('mental') || normalized.contains('therapy')) {
      return Icons.psychology_alt_outlined;
    }

    const icons = [
      Icons.inventory_2_outlined,
      Icons.medication_outlined,
      Icons.event_note_rounded,
      Icons.warehouse_outlined,
    ];

    return icons[index % icons.length];
  }

  static Color _inventoryColorFor(int index) {
    const colors = [
      Color(0xFFE45B5B),
      Color(0xFFEEA24B),
      Color(0xFF6B8FC5),
      Color(0xFF7BA56B),
    ];

    return colors[index % colors.length];
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
