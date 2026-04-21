import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GoogleBrandIcon extends StatelessWidget {
  const GoogleBrandIcon({
    super.key,
    this.size = 20,
    this.withContainer = true,
  });

  final double size;
  final bool withContainer;

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      'lib/assets/icons/google_logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (!withContainer) {
      return icon;
    }

    return Container(
      width: size + 10,
      height: size + 10,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142563EB),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: icon,
    );
  }
}

class GmailBrandIcon extends StatelessWidget {
  const GmailBrandIcon({
    super.key,
    this.size = 20,
    this.withContainer = true,
  });

  final double size;
  final bool withContainer;

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      'lib/assets/icons/gmail_logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (!withContainer) {
      return icon;
    }

    return Container(
      width: size + 10,
      height: size + 10,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFECACA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14DC2626),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: icon,
    );
  }
}
