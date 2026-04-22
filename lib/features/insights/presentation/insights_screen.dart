import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/custom_card.dart';
import '../../../core/utils/section_header.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static const _mockInsights = [
    ('Water Shortage Trend', 'Score 0.91', 'Prioritize tanker dispatch in Zone 3.'),
    ('Medicine Supply Risk', 'Score 0.84', 'Restock antibiotics within 24 hours.'),
    ('Shelter Overload', 'Score 0.79', 'Shift families to nearby partner shelters.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.screenHorizontalPadding),
      children: [
        const SectionHeader(
          title: 'Insights',
          subtitle: 'Actionable recommendations from field patterns.',
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
        for (final item in _mockInsights) ...[
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(item.$2),
                const SizedBox(height: 10),
                Text(item.$3),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
