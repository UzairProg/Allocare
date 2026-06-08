import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/firestore/firestore_paths.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../models/ngo_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_profile_service.dart';
import '../../../../services/volunteer_service.dart';

final approvedNgosProvider = StreamProvider<List<NgoModel>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirestorePaths.ngos)
      .where('verificationStatus', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => NgoModel.fromMap(doc.id, doc.data())).toList());
});

class VolunteerProfileSetupScreen extends ConsumerStatefulWidget {
  const VolunteerProfileSetupScreen({super.key});

  @override
  ConsumerState<VolunteerProfileSetupScreen> createState() =>
      _VolunteerProfileSetupScreenState();
}

class _VolunteerProfileSetupScreenState
    extends ConsumerState<VolunteerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();

  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();

  String? _selectedNgoId;
  final List<String> _selectedSpecializations = [];

  final List<String> _selectedSkills = [];

  final List<String> _skillsOptions = [
    'Food Distribution',
    'Logistics',
    'Community Outreach',
    'Shelter Support',
    'Search & Rescue',
    'First Responder',
  ];

  final Map<String, String> _specializationOptions = {
    'medical': 'Medical',
    'food_nutrition': 'Food & Nutrition',
    'shelter_essentials': 'Shelter & Essentials',
    'disaster_emergency': 'Disaster & Emergency',
    'mental_wellbeing': 'Mental Health & Wellbeing',
    'education_child_support': 'Education & Child Support',
    'elderly_special_care': 'Elderly & Special Care',
    'livelihood_financial_support': 'Livelihood & Financial Support',
    'women_safety': 'Women & Safety',
    'others': 'General Support',
  };

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authUser = ref.read(authStateProvider).asData?.value;
      final profile = ref.read(currentUserProfileProvider).asData?.value;
      final volunteer = ref.read(currentVolunteerProvider).asData?.value;

      if (volunteer != null) {
        _nameController.text = volunteer.displayName;
        _phoneController.text = volunteer.phoneNumber;
        _countryController.text = volunteer.country;
        _stateController.text = volunteer.state;
        _cityController.text = volunteer.city;
        _emergencyNameController.text = volunteer.emergencyContactName;
        _emergencyPhoneController.text = volunteer.emergencyContactPhone;
        _emergencyRelationController.text = volunteer.emergencyContactRelation;
        setState(() {
          _selectedNgoId = volunteer.ngoId.isNotEmpty ? volunteer.ngoId : null;
          _selectedSkills.clear();
          _selectedSkills.addAll(volunteer.skills);
          _selectedSpecializations.clear();
          _selectedSpecializations.addAll(volunteer.specializations);
        });
      } else {
        if (profile != null && profile.displayName.trim().isNotEmpty) {
          _nameController.text = profile.displayName;
        } else if (authUser != null && authUser.displayName != null) {
          _nameController.text = authUser.displayName!;
        }
        if (profile != null && profile.phoneNumber.trim().isNotEmpty) {
          _phoneController.text = profile.phoneNumber;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  void _toggleSpecialization(String key) {
    setState(() {
      if (_selectedSpecializations.contains(key)) {
        _selectedSpecializations.remove(key);
      } else {
        _selectedSpecializations.add(key);
      }
    });
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the validation errors.')),
      );
      return;
    }

    if (_selectedNgoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an NGO to join.')),
      );
      return;
    }

    if (_selectedSpecializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one specialization.')),
      );
      return;
    }

    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one skill.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authUser = ref.read(authStateProvider).asData?.value;
      if (authUser == null) throw StateError('No authenticated user found.');

      // 1. Create or Update Volunteer document
      final existingVolunteer = ref.read(currentVolunteerProvider).asData?.value;
      if (existingVolunteer != null) {
        await ref.read(volunteerServiceProvider).updateProfile(
              uid: authUser.uid,
              displayName: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              country: _countryController.text.trim(),
              state: _stateController.text.trim(),
              city: _cityController.text.trim(),
              skills: _selectedSkills,
              specializations: _selectedSpecializations,
              ngoId: _selectedNgoId!,
              emergencyContactName: _emergencyNameController.text.trim(),
              emergencyContactPhone: _emergencyPhoneController.text.trim(),
              emergencyContactRelation: _emergencyRelationController.text.trim(),
              resubmit: true,
            );
      } else {
        await ref.read(volunteerServiceProvider).createProfile(
              uid: authUser.uid,
              email: authUser.email ?? '',
              displayName: _nameController.text.trim(),
              photoUrl: authUser.photoURL,
              phoneNumber: _phoneController.text.trim(),
              country: _countryController.text.trim(),
              state: _stateController.text.trim(),
              city: _cityController.text.trim(),
              skills: _selectedSkills,
              specializations: _selectedSpecializations,
              ngoId: _selectedNgoId!,
              emergencyContactName: _emergencyNameController.text.trim(),
              emergencyContactPhone: _emergencyPhoneController.text.trim(),
              emergencyContactRelation: _emergencyRelationController.text.trim(),
            );
      }

      // 2. Also ensure UserProfile is updated
      final currentProfile = ref.read(currentUserProfileProvider).asData?.value;
      if (currentProfile != null) {
        await ref.read(userProfileServiceProvider).upsert(
              currentProfile.copyWith(
                displayName: _nameController.text.trim(),
                phoneNumber: _phoneController.text.trim(),
                ngoId: _selectedNgoId,
                updatedAt: DateTime.now(),
              ),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Volunteer profile created successfully.')),
        );
        context.go(RoutePaths.volunteerVerificationPending);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ngosStream = ref.watch(approvedNgosProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Volunteer Onboarding',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Header
                Text(
                  'Complete Your Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join the emergency response network. Enter your personal and contact details to get verified.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 1: Personal Info
                _buildSectionHeader('1. Personal Details'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Enter phone number' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        icon: Icons.location_city_rounded,
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'City required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _stateController,
                        label: 'State',
                        icon: Icons.map_outlined,
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'State required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _countryController,
                  label: 'Country',
                  icon: Icons.public_rounded,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Country required' : null,
                ),
                const SizedBox(height: 24),

                // SECTION 2: Select NGO
                _buildSectionHeader('2. Choose NGO Organization'),
                const SizedBox(height: 6),
                Text(
                  'You will register under this organization. They will review and approve your application.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                ngosStream.when(
                  data: (ngos) {
                    if (ngos.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'No approved NGOs found on the platform. Please check back later.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFB45309),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedNgoId,
                          hint: Text(
                            'Select NGO',
                            style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                          ),
                          isExpanded: true,
                          decoration: const InputDecoration(border: InputBorder.none),
                          items: ngos.map((ngo) {
                            return DropdownMenuItem<String>(
                              value: ngo.ngoId,
                              child: Text(
                                ngo.ngoName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedNgoId = val);
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  error: (err, _) => Text(
                    'Failed to load NGOs: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 3: Skills selection
                _buildSectionHeader('3. Select Skills (Multi-Select)'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skillsOptions.map((skill) {
                    final isSelected = _selectedSkills.contains(skill);
                    return ChoiceChip(
                      label: Text(skill),
                      selected: isSelected,
                      onSelected: (_) => _toggleSkill(skill),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      selectedColor: const Color(0xFF0284C7),
                      backgroundColor: Colors.white,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // SECTION 4: Specialization
                _buildSectionHeader('4. Operational Specializations (Multi-Select)'),
                const SizedBox(height: 6),
                Text(
                  'Select one or more crisis categories you are qualified to handle.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _specializationOptions.entries.map((entry) {
                    final isSelected = _selectedSpecializations.contains(entry.key);
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (_) => _toggleSpecialization(entry.key),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      selectedColor: const Color(0xFF0284C7),
                      backgroundColor: Colors.white,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // SECTION 5: Emergency Contact
                _buildSectionHeader('5. Emergency Contact'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _emergencyNameController,
                  label: 'Contact Person Name',
                  icon: Icons.contact_emergency_outlined,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Enter contact name' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emergencyPhoneController,
                  label: 'Contact Person Phone',
                  icon: Icons.phone_callback_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Enter contact phone' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emergencyRelationController,
                  label: 'Relationship (e.g. Spouse, Parent)',
                  icon: Icons.family_restroom_rounded,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Enter relationship' : null,
                ),
                const SizedBox(height: 32),

                // Submission CTA
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('SUBMIT PROFILE FOR REVIEW'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}
