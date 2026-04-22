import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/custom_card.dart';
import '../../../core/utils/primary_button.dart';
import '../../../core/utils/section_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.screenHorizontalPadding),
      children: [
        const SectionHeader(
          title: 'Profile',
          subtitle: 'Manage account details and preferences.',
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
        const CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: User Name Placeholder'),
              SizedBox(height: 8),
              Text('Role: Admin'),
              SizedBox(height: 8),
              Text('Email: user@allocare.app'),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
        PrimaryButton(
          label: 'Logout',
          icon: Icons.logout,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logout action will be connected to auth service later.')),
            );
          },
        ),
      ],
    );
  }
}
