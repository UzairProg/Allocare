import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../models/ngo_model.dart';
import '../../../../services/ngo_service.dart';
import '../../../auth/presentation/widgets/auth_page_shell.dart';
import '../../../auth/presentation/widgets/auth_primary_button.dart';
import '../../application/ngo_controller.dart';

const List<_NgoCategoryOption> _ngoCategoryOptions = [
  _NgoCategoryOption('medical', 'Medical Relief'),
  _NgoCategoryOption('food', 'Food Distribution'),
  _NgoCategoryOption('water', 'Water & Sanitation'),
  _NgoCategoryOption('shelter', 'Shelter Support'),
  _NgoCategoryOption('emergency', 'Emergency Response'),
  _NgoCategoryOption('recovery', 'Disaster Recovery'),
  _NgoCategoryOption('community', 'Community Outreach'),
];

class _NgoCategoryOption {
  const _NgoCategoryOption(this.key, this.label);

  final String key;
  final String label;
}

class NgoProfileSetupScreen extends ConsumerStatefulWidget {
  const NgoProfileSetupScreen({super.key});

  @override
  ConsumerState<NgoProfileSetupScreen> createState() =>
      _NgoProfileSetupScreenState();
}

class _NgoProfileSetupScreenState extends ConsumerState<NgoProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ngoNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();

  String _countryName = 'India';
  final Set<String> _selectedSupportedCategories = <String>{};
  File? _logoFile;
  bool _initialized = false;

  @override
  void dispose() {
    _ngoNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _prefillFromExisting(NgoModel ngo) {
    if (_initialized) return;
    _initialized = true;
    _ngoNameController.text = ngo.ngoName;
    _descriptionController.text = ngo.description;
    _phoneController.text = ngo.phoneNumber;
    _stateController.text = ngo.state;
    _cityController.text = ngo.city;
    _addressController.text = ngo.address;
    _countryName = ngo.country.isNotEmpty ? ngo.country : _countryName;
    _selectedSupportedCategories
      ..clear()
      ..addAll(ngo.supportedCategories);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _logoFile = File(picked.path));
    }
  }

  Future<void> _submit(NgoModel? existing) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref
          .read(ngoControllerProvider.notifier)
          .submitProfile(
            form: NgoProfileFormData(
              ngoName: _ngoNameController.text,
              description: _descriptionController.text,
              phoneNumber: _phoneController.text,
              country: _countryName,
              state: _stateController.text,
              city: _cityController.text,
              address: _addressController.text,
              supportedCategories: _ngoCategoryOptions
                  .where(
                    (option) =>
                        _selectedSupportedCategories.contains(option.key),
                  )
                  .map((option) => option.key)
                  .toList(),
              logoFile: _logoFile,
            ),
            existing: existing,
          );

      if (!mounted) return;
      if (existing != null) {
        context.pop();
      } else {
        context.go(RoutePaths.ngoVerificationPending);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ngoAsync = ref.watch(currentNgoProvider);
    final existing = ngoAsync.asData?.value;
    if (existing != null) _prefillFromExisting(existing);

    final isBusy = ref.watch(ngoControllerProvider).isLoading;
    final isEdit = existing != null;

    return AuthPageShell(
      title: isEdit ? 'Edit NGO Profile' : 'Complete NGO Profile',
      subtitle:
          'Tell AlloCare about your organization to begin humanitarian coordination.',
      cardMaxWidth: 520,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: isBusy ? null : _pickLogo,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFFEFF6FF),
                  backgroundImage: _logoFile != null
                      ? FileImage(_logoFile!)
                      : (existing != null && existing.logoUrl.isNotEmpty
                            ? NetworkImage(existing.logoUrl)
                            : null),
                  child:
                      _logoFile == null && (existing?.logoUrl.isEmpty ?? true)
                      ? const Icon(
                          Icons.add_a_photo_outlined,
                          color: Color(0xFF3B82F6),
                          size: 28,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Logo Upload (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _field(
              controller: _ngoNameController,
              label: 'NGO Name',
              icon: Icons.business_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'NGO name is required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description_outlined,
              maxLines: 3,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Phone number is required'
                  : null,
            ),
            const SizedBox(height: 14),
            _countryPicker(isBusy),
            const SizedBox(height: 14),
            _field(
              controller: _stateController,
              label: 'State',
              icon: Icons.map_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'State is required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _cityController,
              label: 'City',
              icon: Icons.location_city_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'City is required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _addressController,
              label: 'Address',
              icon: Icons.home_outlined,
              maxLines: 2,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 28),
            const SizedBox(height: 16),
            Text(
              'Supported Categories',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _ngoCategoryOptions)
                  FilterChip(
                    label: Text(option.label),
                    selected: _selectedSupportedCategories.contains(option.key),
                    onSelected: isBusy
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSupportedCategories.add(option.key);
                              } else {
                                _selectedSupportedCategories.remove(option.key);
                              }
                            });
                          },
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedSupportedCategories.contains(option.key)
                          ? Colors.white
                          : const Color(0xFF334155),
                    ),
                    selectedColor: const Color(0xFF1A5F7A),
                    checkmarkColor: Colors.white,
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: isEdit ? 'Update Profile' : 'Submit Application',
              isLoading: isBusy,
              onPressed: isBusy ? null : () => _submit(existing),
              color: const Color(0xFF1A5F7A),
            ),
          ],
        ),
      ),
      footer: const SizedBox.shrink(),
    );
  }

  Widget _countryPicker(bool isBusy) {
    return InkWell(
      onTap: isBusy
          ? null
          : () {
              showCountryPicker(
                context: context,
                showPhoneCode: false,
                onSelect: (country) {
                  setState(() => _countryName = country.name);
                },
              );
            },
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _decoration('Country', Icons.public_outlined),
        child: Row(
          children: [
            Text(
              _countryName,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 15),
      decoration: _decoration(label, icon),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1A5F7A), width: 1.5),
      ),
    );
  }
}
