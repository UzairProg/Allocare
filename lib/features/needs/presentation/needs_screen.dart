import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/custom_card.dart';
import '../../../core/utils/primary_button.dart';
import '../../../core/utils/section_header.dart';

class NeedsScreen extends StatelessWidget {
  const NeedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.screenHorizontalPadding),
      children: [
        const SectionHeader(
          title: 'Report',
          subtitle: 'Capture and track newly reported needs.',
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
        PrimaryButton(
          label: 'Add New Need',
          icon: Icons.playlist_add,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Need creation flow will be added next phase.')),
            );
          },
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
        CustomCard(
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'No needs yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Newly reported needs will appear here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
