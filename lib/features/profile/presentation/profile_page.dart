import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const MethodChannel _pnvChannel = MethodChannel('com.example.allocare_app/pnv');

  bool _isVerifying = false;
  String? _verifiedPhone;
  String? _verificationToken;

  Future<Map<String, String?>> _verifyPhone() async {
    final response = await _pnvChannel.invokeMethod<Map<dynamic, dynamic>>('getVerifiedPhone');
    return {
      'phoneNumber': (response?['phoneNumber'] as String?)?.trim(),
      'token': (response?['token'] as String?)?.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = ref.watch(authServiceProvider);
    final profile = ref.watch(currentUserProfileProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Profile',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        profile.when(
          data: (data) {
            if (data == null) {
              return const Text('No profile available.');
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(data.email),
                    const SizedBox(height: 8),
                    Text('Phone: ${data.phoneNumber.isEmpty ? 'Not set' : data.phoneNumber}'),
                    const SizedBox(height: 8),
                    Text('Role: ${data.role.name.toUpperCase()}'),
                    const SizedBox(height: 16),
                    Text(
                      'Verification Center',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Smart Resource Allocation relies on trusted phone identity for priority dispatch decisions.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isVerifying
                          ? null
                          : () async {
                              setState(() => _isVerifying = true);
                        try {
                          final payload = await _verifyPhone();
                          final phone = payload['phoneNumber'];
                          final token = payload['token'];

                          setState(() {
                            _verifiedPhone = phone;
                            _verificationToken = token;
                          });

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                phone == null || phone.isEmpty
                                    ? 'Phone verified. Number unavailable from SDK response.'
                                    : 'Verified: $phone',
                              ),
                            ),
                          );

                          if (phone != null && phone.isNotEmpty) {
                            showDialog<void>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Phone Verified'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Number: $phone'),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Token: ${token == null || token.isEmpty ? 'N/A' : token.length > 24 ? '${token.substring(0, 24)}...' : token}',
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(),
                                      child: const Text('Done'),
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        } on PlatformException catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Verification failed: ${error.message ?? error.code}')),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Verification failed: $error')),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isVerifying = false);
                          }
                        }
                      },
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(_isVerifying ? 'Verifying...' : 'Verify Phone'),
                    ),
                    if (_verifiedPhone != null && _verifiedPhone!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Verified Number: $_verifiedPhone',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF1F9D55),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_verificationToken != null && _verificationToken!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Token: ${_verificationToken!.length > 18 ? '${_verificationToken!.substring(0, 18)}...' : _verificationToken!}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        await authService.signOut();
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )),
          error: (error, _) => Text('Profile error: $error'),
        ),
      ],
    );
  }
}
