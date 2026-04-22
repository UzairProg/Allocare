import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
