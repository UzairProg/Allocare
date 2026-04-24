import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/custom_card.dart';
import '../../../models/app_user.dart';
import '../../../models/ngo_inventory_item.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';

class ManageNgoInventoryPage extends ConsumerStatefulWidget {
  const ManageNgoInventoryPage({super.key});

  @override
  ConsumerState<ManageNgoInventoryPage> createState() => _ManageNgoInventoryPageState();
}

class _ManageNgoInventoryPageState extends ConsumerState<ManageNgoInventoryPage> {
  final _formKey = GlobalKey<FormState>();
  final List<_InventoryDraft> _drafts = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInventory());
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final authUser = ref.read(authStateProvider).asData?.value;
    final service = ref.read(userProfileServiceProvider);

    if (authUser == null) {
      if (!mounted) return;
      setState(() {
        _drafts.add(_InventoryDraft.empty());
        _isLoading = false;
      });
      return;
    }

    final profile = await service.getById(authUser.uid);
    if (!mounted) return;

    setState(() {
      _drafts
        ..clear()
        ..addAll(
          (profile?.inventoryItems.isNotEmpty ?? false)
              ? profile!.inventoryItems.map(_InventoryDraft.fromItem)
              : [_InventoryDraft.empty()],
        );
      _isLoading = false;
    });
  }

  void _addItem() {
    setState(() {
      _drafts.add(_InventoryDraft.empty());
    });
  }

  void _removeItem(int index) {
    if (_drafts.length == 1) {
      _drafts.first.clear();
      return;
    }

    setState(() {
      _drafts[index].dispose();
      _drafts.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authUser = ref.read(authStateProvider).asData?.value;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first to manage NGO inventory.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(userProfileServiceProvider);
      final existing = await service.getById(authUser.uid);
      final now = DateTime.now();

      final updatedProfile = AppUser(
        id: authUser.uid,
        email: authUser.email ?? existing?.email ?? '',
        displayName: (authUser.displayName ?? existing?.displayName ?? '').trim(),
        phoneNumber: (existing?.phoneNumber ?? '').trim(),
        role: existing?.role ?? AppUserRole.ngo,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        inventoryItems: _drafts
            .map((draft) => draft.toItem())
            .where((item) => item.title.trim().isNotEmpty)
            .toList(),
      );

      await service.upsert(updatedProfile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NGO inventory saved successfully.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save NGO inventory: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage NGO Inventory'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Saving' : 'Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.screenHorizontalPadding,
                    12,
                    AppConstants.screenHorizontalPadding,
                    24,
                  ),
                  children: [
                    CustomCard(
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
                                child: Icon(Icons.domain_rounded, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stored inside your NGO profile',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Email, role, phone number, and inventory all live inside the same Firestore NGO schema.',
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
                          Text(
                            'Add or update stock items your NGO wants to track on the profile.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (int i = 0; i < _drafts.length; i++) ...[
                      _InventoryDraftCard(
                        draft: _drafts[i],
                        itemIndex: i,
                        onRemove: () => _removeItem(i),
                        onProgressChanged: (value) {
                          setState(() {
                            _drafts[i].progress = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add inventory item'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tip: keep names short and use the units field for counts such as 32 kits, 15 boxes, or 80 meals.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InventoryDraft {
  _InventoryDraft({
    required this.id,
    String? title,
    String? subtitle,
    String? units,
    double? progress,
  })  : titleController = TextEditingController(text: title ?? ''),
        subtitleController = TextEditingController(text: subtitle ?? ''),
        unitsController = TextEditingController(text: units ?? ''),
        progress = progress ?? 0.6;

  factory _InventoryDraft.empty() {
    return _InventoryDraft(id: DateTime.now().microsecondsSinceEpoch.toString());
  }

  factory _InventoryDraft.fromItem(NgoInventoryItem item) {
    return _InventoryDraft(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      units: item.units,
      progress: item.progress,
    );
  }

  final String id;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final TextEditingController unitsController;
  double progress;

  NgoInventoryItem toItem() {
    return NgoInventoryItem(
      id: id,
      title: titleController.text.trim(),
      subtitle: subtitleController.text.trim(),
      units: unitsController.text.trim(),
      progress: progress,
    );
  }

  void clear() {
    titleController.clear();
    subtitleController.clear();
    unitsController.clear();
    progress = 0.6;
  }

  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    unitsController.dispose();
  }
}

class _InventoryDraftCard extends StatelessWidget {
  const _InventoryDraftCard({
    required this.draft,
    required this.itemIndex,
    required this.onRemove,
    required this.onProgressChanged,
  });

  final _InventoryDraft draft;
  final int itemIndex;
  final VoidCallback onRemove;
  final ValueChanged<double> onProgressChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _colorForIndex(itemIndex).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForIndex(itemIndex), color: _colorForIndex(itemIndex), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Inventory item ${itemIndex + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                color: theme.colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: draft.titleController,
            decoration: const InputDecoration(
              labelText: 'Item title',
              hintText: 'Example: Medical Kits',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Title is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: draft.subtitleController,
            decoration: const InputDecoration(
              labelText: 'Item description',
              hintText: 'Example: Emergency first aid packs',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: draft.unitsController,
            decoration: const InputDecoration(
              labelText: 'Units',
              hintText: 'Example: 72 kits',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Units are required';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Readiness: ${(draft.progress * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: draft.progress,
            onChanged: onProgressChanged,
          ),
        ],
      ),
    );
  }
}

IconData _iconForIndex(int index) {
  const icons = [
    Icons.medication_outlined,
    Icons.inventory_2_outlined,
    Icons.local_shipping_outlined,
    Icons.event_note_rounded,
  ];

  return icons[index % icons.length];
}

Color _colorForIndex(int index) {
  const colors = [
    Color(0xFFE45B5B),
    Color(0xFFEEA24B),
    Color(0xFF6B8FC5),
    Color(0xFF7BA56B),
  ];

  return colors[index % colors.length];
}