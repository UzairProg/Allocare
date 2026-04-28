import 'package:flutter/material.dart';

import '../../../../models/app_user.dart';

class AuthRoleSelector extends StatelessWidget {
  const AuthRoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final AppUserRole value;
  final ValueChanged<AppUserRole> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = [
      (AppUserRole.ngo, 'NGO'),
      (AppUserRole.volunteer, 'Volunteer'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: options.map((entry) {
          final role = entry.$1;
          final label = entry.$2;
          final isSelected = role == value;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: enabled ? () => onChanged(role) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
