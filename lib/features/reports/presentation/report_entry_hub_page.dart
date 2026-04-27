import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../needs/presentation/needs_screen.dart';
import 'ai_scan_page.dart';

class ReportEntryHubPage extends StatelessWidget {
  const ReportEntryHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFB),
        foregroundColor: const Color(0xFF202124),
        elevation: 0,
        title: const Text(
          'Report Entry Hub',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final cardHeight = isWide ? 460.0 : 400.0;

              final manualCard = _SplitCard(
                height: cardHeight,
                imageAsset: 'assets/manual_bg.png',
                title: 'Structured Report Entry',
                body:
                    'NGO-Verified Input. Transform field observations into precise, structured strategic data for high-stakes resource allocation.',
                icon: const Icon(
                  Icons.edit,
                  color: Color(0xFF1A73E8),
                  size: 24,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StepByStepFormPage(),
                    ),
                  );
                },
              );

              final aiCard = _SplitCard(
                height: cardHeight,
                imageAsset: 'assets/ai_bg.png',
                title: 'Sentinel Intelligence Scan',
                body:
                    'From Fragmented to Actionable. Upload handwritten logs or messy field notes. Gemini extracts and structures the intelligence instantly.',
                icon: SvgPicture.asset(
                  'assets/gemini_icon.svg',
                  width: 23,
                  height: 23,
                  // colorFilter: const ColorFilter.mode(
                  // Color(0xFF7209B7),
                  // BlendMode.srcIn,
                  // ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AIScanPage()),
                  );
                },
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: manualCard),
                    const SizedBox(width: 24),
                    Expanded(child: aiCard),
                  ],
                );
              }

              return ListView(
                physics: const BouncingScrollPhysics(),
                children: [manualCard, const SizedBox(height: 24), aiCard],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.height,
    required this.imageAsset,
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
  });

  final double height;
  final String imageAsset;
  final String title;
  final String body;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          splashFactory: InkRipple.splashFactory,
          child: Stack(
            children: [
              FractionallySizedBox(
                alignment: Alignment.topCenter,
                heightFactor: 0.5,
                widthFactor: 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) {
                      return Container(color: const Color(0xFFE3E7EB));
                    },
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.5,
                  widthFactor: 1,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: icon),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StepByStepFormPage extends StatelessWidget {
  const StepByStepFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const NeedsScreen();
  }
}
