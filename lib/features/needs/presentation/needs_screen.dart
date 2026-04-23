import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/custom_card.dart';
import '../../../models/app_user.dart';
import '../../../models/need_model.dart';
import '../../../models/document_attachment.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';
import '../application/need_submission_service.dart';

enum _LocationMode { current, search, map }
enum _UrgencyLevel { critical, high, medium, low }

const List<_NeedCategoryOption> _needCategoryOptions = [
  _NeedCategoryOption(
    key: 'medical',
    title: 'Medical',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFE16A79),
    subcategories: ['Injuries', 'Chronic illness', 'Medicine/First Aid', 'Other Medical care'],
  ),
  _NeedCategoryOption(
    key: 'food_nutrition',
    title: 'Food & Nutrition',
    icon: Icons.restaurant_menu_outlined,
    color: Color(0xFFF0A55A),
    subcategories: ['Hunger', 'Malnutrition', 'Infant formula', 'Other Food supply'],
  ),
  _NeedCategoryOption(
    key: 'shelter_essentials',
    title: 'Shelter & Essentials',
    icon: Icons.night_shelter_outlined,
    color: Color(0xFF8B8FD6),
    subcategories: ['Eviction risk', 'Repair needed', 'Heating/Cooling', 'Other Shelter'],
  ),
  _NeedCategoryOption(
    key: 'disaster_emergency',
    title: 'Disaster & Emergency',
    icon: Icons.warning_amber_rounded,
    color: Color(0xFFE66A5F),
    subcategories: ['Missing persons', 'Rescue needed', 'Natural disaster', 'Other Emergency'],
  ),
  _NeedCategoryOption(
    key: 'mental_wellbeing',
    title: 'Mental Health & Wellbeing',
    icon: Icons.psychology_alt_outlined,
    color: Color(0xFF6E90C5),
    subcategories: ['Grief support', 'Panic attacks', 'Support network', 'Other Wellbeing'],
  ),
  _NeedCategoryOption(
    key: 'education_child_support',
    title: 'Education & Child Support',
    icon: Icons.school_outlined,
    color: Color(0xFF4D97A5),
    subcategories: ['Tutoring', 'Youth programs', 'Child protection', 'Other Child help'],
  ),
  _NeedCategoryOption(
    key: 'elderly_special_care',
    title: 'Elderly & Special Care',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF7E9B70),
    subcategories: ['Isolated senior', 'Home visit', 'Caregiver respite', 'Other Elderly care'],
  ),
  _NeedCategoryOption(
    key: 'livelihood_financial_support',
    title: 'Livelihood & Financial Support',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFFB37F52),
    subcategories: ['Small business', 'Debt relief', 'Grant assistance', 'Other Financial'],
  ),
  _NeedCategoryOption(
    key: 'women_safety',
    title: 'Women & Safety',
    icon: Icons.shield_outlined,
    color: Color(0xFFC75D87),
    subcategories: ['Resource access', 'Legal aid', 'Escort service', 'Other Women safety'],
  ),
  _NeedCategoryOption(
    key: 'others',
    title: 'Others',
    icon: Icons.category_outlined,
    color: Color(0xFF7B8794),
    subcategories: ['Other'],
  ),
];

class NeedsScreen extends ConsumerStatefulWidget {
  const NeedsScreen({super.key});

  @override
  ConsumerState<NeedsScreen> createState() => _NeedsScreenState();
}

class _NeedsScreenState extends ConsumerState<NeedsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _peopleAffectedController = TextEditingController(text: '24');
  final _otherSubcategoryController = TextEditingController();

  _LocationMode _locationMode = _LocationMode.current;
  String _currentLocationLabel = 'Tap to fetch your live location';
  double? _currentLatitude;
  double? _currentLongitude;
  String _categoryKey = 'medical';
  String _selectedSubcategory = 'Injuries';
  String? _expandedCategoryKey = 'medical';
  _UrgencyLevel _urgency = _UrgencyLevel.critical;
  int _peopleAffected = 24;
  int _step = 0;
  bool _isSubmitting = false;
  final List<DocumentAttachment> _supportingDocs = [];
  bool _isUploadingFile = false;
  bool _isCurrentLocationFetched = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _peopleAffectedController.dispose();
    _otherSubcategoryController.dispose();
    super.dispose();
  }

  void _setPeopleAffected(int value) {
    final clampedValue = value < 1 ? 1 : value;
    setState(() {
      _peopleAffected = clampedValue;
      _peopleAffectedController.text = clampedValue.toString();
      _peopleAffectedController.selection = TextSelection.collapsed(
        offset: _peopleAffectedController.text.length,
      );
    });
  }

  Future<void> _fetchCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _currentLocationLabel = 'Fetching live location...';
      _isCurrentLocationFetched = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _currentLocationLabel = 'Location services are disabled';
          _currentLatitude = null;
          _currentLongitude = null;
          _isCurrentLocationFetched = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _currentLocationLabel = 'Location permission needed';
          _currentLatitude = null;
          _currentLongitude = null;
          _isCurrentLocationFetched = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
        _currentLocationLabel = 'Live location · ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        _isCurrentLocationFetched = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _currentLocationLabel = 'Unable to fetch live location';
        _currentLatitude = null;
        _currentLongitude = null;
        _isCurrentLocationFetched = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location fetch failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final authService = ref.watch(authServiceProvider);
    final submissionService = ref.watch(needSubmissionServiceProvider);

    final demoProfile = AppUser(
      id: 'demo-user',
      email: 'ngo@allocare.app',
      displayName: 'Allocare NGO',
      phoneNumber: '+91 90000 00000',
      role: AppUserRole.ngo,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final visibleProfile = profile ?? demoProfile;
    final reporterName = visibleProfile.displayName.trim().isNotEmpty
        ? visibleProfile.displayName.trim()
        : authUser?.displayName?.trim().isNotEmpty ?? false
            ? authUser!.displayName!.trim()
            : 'Allocare NGO';
    final reporterEmail = visibleProfile.email.trim().isNotEmpty
        ? visibleProfile.email.trim()
        : authUser?.email?.trim().isNotEmpty ?? false
            ? authUser!.email!.trim()
            : 'ngo@allocare.app';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenHorizontalPadding,
                8,
                AppConstants.screenHorizontalPadding,
                10,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _step == 0
                        ? () => Navigator.of(context).maybePop()
                        : () => setState(() => _step -= 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: theme.colorScheme.onSurface,
                  ),
                  Text(
                    'Back',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
              child: _ProgressBar(step: _step, totalSteps: 6),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenHorizontalPadding,
                14,
                AppConstants.screenHorizontalPadding,
                12,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STEP ${_step + 1} OF 6',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _stepTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E2A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _stepContext,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_step == 0) ...[
                        _SectionLabel(title: 'Choose Location'),
                        _LocationCard(
                          mode: _LocationMode.current,
                          selected: _locationMode == _LocationMode.current,
                          success: _isCurrentLocationFetched,
                          title: 'Use Current Location',
                          subtitle: _currentLocationLabel,
                          icon: Icons.location_on_rounded,
                          onTap: () {
                            setState(() => _locationMode = _LocationMode.current);
                            _fetchCurrentLocation();
                          },
                        ),
                        const SizedBox(height: 10),
                        _LocationCard(
                          mode: _LocationMode.search,
                          selected: _locationMode == _LocationMode.search,
                          title: 'Search Area',
                          subtitle: 'Type a location or zone',
                          icon: Icons.search_rounded,
                          trailing: Icons.chevron_right_rounded,
                          onTap: () => setState(() => _locationMode = _LocationMode.search),
                        ),
                        const SizedBox(height: 10),
                        _LocationCard(
                          mode: _LocationMode.map,
                          selected: _locationMode == _LocationMode.map,
                          title: 'Pick on Map',
                          subtitle: 'Tap a zone to select',
                          icon: Icons.map_rounded,
                          trailing: Icons.chevron_right_rounded,
                          onTap: () => setState(() => _locationMode = _LocationMode.map),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _locationMode == _LocationMode.current && _isCurrentLocationFetched
                              ? Padding(
                                  key: const ValueKey('location-success-note'),
                                  padding: const EdgeInsets.fromLTRB(
                                    AppConstants.screenHorizontalPadding,
                                    10,
                                    AppConstants.screenHorizontalPadding,
                                    0,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF9F2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF1F9D55).withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF1F9D55),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Current location fetched successfully.',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: const Color(0xFF166A41),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (_locationMode != _LocationMode.current) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                            child: TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location',
                                hintText: 'Enter area, landmark, or zone',
                              ),
                              validator: (value) {
                                if (_locationMode == _LocationMode.current) return null;
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Location is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ],
                      if (_step == 1) ...[
                        _SectionLabel(title: 'Choose Need Category'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                          child: Column(
                            children: [
                              for (final option in _needCategoryOptions) ...[
                                _NeedCategoryCard(
                                  option: option,
                                  isSelected: _categoryKey == option.key,
                                  isExpanded: _expandedCategoryKey == option.key,
                                  selectedSubcategory: _categoryKey == option.key ? _selectedSubcategory : null,
                                  onHeaderTap: () {
                                    setState(() {
                                      _expandedCategoryKey = _expandedCategoryKey == option.key ? null : option.key;
                                      _categoryKey = option.key;
                                      if (_categoryKey != 'others' && _otherSubcategoryController.text.isNotEmpty) {
                                        _otherSubcategoryController.clear();
                                      }
                                      if (!option.subcategories.contains(_selectedSubcategory)) {
                                        _selectedSubcategory = option.subcategories.first;
                                      }
                                    });
                                  },
                                  onSubcategoryTap: (subcategory) {
                                    setState(() {
                                      _categoryKey = option.key;
                                      _selectedSubcategory = subcategory;
                                    });
                                  },
                                  customOtherController: option.key == 'others' ? _otherSubcategoryController : null,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (_step == 2) ...[
                        _SectionLabel(title: 'Urgency Level'),
                        _ChoiceGrid<_UrgencyLevel>(
                          selected: _urgency,
                          items: const [
                            _ChoiceItem(value: _UrgencyLevel.critical, label: 'Critical', icon: Icons.brightness_1_rounded),
                            _ChoiceItem(value: _UrgencyLevel.high, label: 'High', icon: Icons.brightness_1_rounded),
                            _ChoiceItem(value: _UrgencyLevel.medium, label: 'Medium', icon: Icons.brightness_1_rounded),
                            _ChoiceItem(value: _UrgencyLevel.low, label: 'Low', icon: Icons.brightness_1_rounded),
                          ],
                          onChanged: (value) => setState(() => _urgency = value),
                          colorFor: _urgencyColor,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6E8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF2CC8F).withValues(alpha: 0.7)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE4B0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.tips_and_updates_rounded, size: 16, color: Color(0xFF9B6A1A)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tip: Pick the level that best matches current risk. You can always share extra context in details so teams prioritize better.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF7A4F0E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_step == 3) ...[
                        _SectionLabel(title: 'Impact Details'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                          child: CustomCard(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _CircleCounterButton(
                                      icon: Icons.remove_rounded,
                                      onTap: _peopleAffected > 1 ? () => _setPeopleAffected(_peopleAffected - 1) : null,
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: 110,
                                      child: TextFormField(
                                        controller: _peopleAffectedController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        style: theme.textTheme.displaySmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.primary,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onTap: () {
                                          _peopleAffectedController.selection = TextSelection(
                                            baseOffset: 0,
                                            extentOffset: _peopleAffectedController.text.length,
                                          );
                                        },
                                        onChanged: (value) {
                                          final parsedValue = int.tryParse(value);
                                          if (parsedValue != null && parsedValue > 0) {
                                            setState(() => _peopleAffected = parsedValue);
                                          }
                                        },
                                        validator: (value) {
                                          final parsedValue = int.tryParse((value ?? '').trim());
                                          if (parsedValue == null || parsedValue < 1) {
                                            return 'Enter a valid count';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const Spacer(),
                                    _CircleCounterButton(
                                      icon: Icons.add_rounded,
                                      onTap: () => _setPeopleAffected(_peopleAffected + 1),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Approximate numbers are enough here if the exact count is still being verified.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionLabel(title: 'Need Details'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Need title',
                                  hintText: 'Example: Food shortage in Ward 12',
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
                                controller: _descriptionController,
                                minLines: 3,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Describe the issue, severity, and any immediate needs',
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
                                controller: _contactNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact person (optional)',
                                  hintText: 'Name of local contact',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contactPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Contact phone (optional)',
                                  hintText: 'Mobile number',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_step == 4) ...[
                        _SectionLabel(title: 'Supporting Evidence (Optional)'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                          child: Text(
                            'Attach photos, documents, or reports to strengthen your report',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                          child: Column(
                            children: [
                              _DocumentUploadCard(
                                label: 'Take Photo',
                                icon: Icons.camera_alt_rounded,
                                onTap: _isUploadingFile ? null : () => _pickFileFromCamera(),
                                isLoading: _isUploadingFile,
                              ),
                              const SizedBox(height: 10),
                              _DocumentUploadCard(
                                label: 'From Gallery',
                                icon: Icons.image_rounded,
                                onTap: _isUploadingFile ? null : () => _pickFileFromGallery(),
                                isLoading: _isUploadingFile,
                              ),
                              const SizedBox(height: 10),
                              _DocumentUploadCard(
                                label: 'Upload File',
                                icon: Icons.description_rounded,
                                onTap: _isUploadingFile ? null : () => _pickFileFromBrowser(),
                                isLoading: _isUploadingFile,
                              ),
                            ],
                          ),
                        ),
                        if (_supportingDocs.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attached Files (${_supportingDocs.length})',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final (index, doc) in _supportingDocs.indexed) ...[
                                  InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => _previewAttachment(doc),
                                    child: CustomCard(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              doc.isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                                              size: 24,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  doc.fileName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.labelMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  doc.isImage ? 'Tap to view image' : 'Tap to open in app',
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                                Text(
                                                  doc.fileSizeDisplay,
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => setState(() => _supportingDocs.removeAt(index)),
                                            icon: const Icon(Icons.close_rounded),
                                            iconSize: 20,
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (index < _supportingDocs.length - 1) const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                      if (_step == 5) ...[
                        _SectionLabel(title: 'Review Report'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                          child: CustomCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ReviewRow(label: 'Location', value: _resolvedLocation),
                                const SizedBox(height: 10),
                                _ReviewRow(label: 'Type', value: _categoryLabel),
                                const SizedBox(height: 10),
                                _ReviewRow(label: 'Urgency', value: _urgencyLabel),
                                const SizedBox(height: 10),
                                _ReviewRow(label: 'People', value: '$_peopleAffected people'),
                                const SizedBox(height: 10),
                                _ReviewRow(label: 'Title', value: _titleController.text.trim().isEmpty ? 'Untitled need' : _titleController.text.trim()),
                                const SizedBox(height: 10),
                                _ReviewRow(
                                  label: 'Description',
                                  value: _descriptionController.text.trim().isEmpty ? 'No description provided' : _descriptionController.text.trim(),
                                  alignTop: true,
                                ),
                                const SizedBox(height: 10),
                                _ReviewRow(label: 'Reported by', value: reporterName),
                                const SizedBox(height: 10),
                                // _ReviewRow(label: 'Source', value: profile == null ? 'Demo fallback' : 'Firebase profile'),
                              ],
                            ),
                          ),
                        ),
                        if (_supportingDocs.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                            child: Text(
                              'Supporting Evidence (${_supportingDocs.length} file${_supportingDocs.length != 1 ? 's' : ''})',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final (index, doc) in _supportingDocs.indexed) ...[
                                    if (index > 0) const SizedBox(width: 8),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => _previewAttachment(doc),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: theme.colorScheme.surfaceContainerHigh,
                                        ),
                                        child: doc.isImage
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.memory(
                                                  base64Decode(doc.base64Data),
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.picture_as_pdf_rounded,
                                                    size: 28,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    child: Text(
                                                      'PDF',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      textAlign: TextAlign.center,
                                                      style: theme.textTheme.labelSmall?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                          child: Text(
                            'Your report helps AI prioritize resource allocation fairly',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
                        child: Row(
                          children: [
                            if (_step > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting ? null : () => setState(() => _step -= 1),
                                  child: const Text('Back'),
                                ),
                              ),
                            if (_step > 0) const SizedBox(width: 12),
                            Expanded(
                              flex: _step == 5 ? 2 : 1,
                              child: FilledButton(
                                onPressed: _isSubmitting
                                  ? null
                                    : _step == 5
                                        ? () => _submitNeed(context, authService, submissionService, reporterName, reporterEmail)
                                        : () => _nextStep(context),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(_step == 5 ? 'Submit Report ->' : 'Continue'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Where is the need?';
      case 1:
        return 'What kind of need?';
      case 2:
        return 'How urgent is it?';
      case 3:
        return 'How many people are affected?';
      case 4:
        return 'Supporting evidence';
      default:
        return 'Review the report';
    }
  }

  String get _stepContext {
    switch (_step) {
      case 0:
        return 'Pinpointing the exact area helps teams route aid faster and avoid duplicate dispatches.';
      case 1:
        return 'Select the closest category so analysis systems can group similar needs and prioritize correctly.';
      case 2:
        return 'Your urgency signal helps response teams balance immediate risks with available resources.';
      case 3:
        return 'A clear impact estimate helps planning models size support kits and volunteer allocation.';
      case 4:
        return 'Supporting files make reports more reliable and improve downstream AI structuring quality.';
      default:
        return 'Review once before submission to keep the final report complete, clean, and actionable.';
    }
  }

  String get _resolvedLocation {
    if (_locationMode == _LocationMode.current) {
      if (_currentLatitude != null && _currentLongitude != null) {
        return 'Live location · ${_currentLatitude!.toStringAsFixed(5)}, ${_currentLongitude!.toStringAsFixed(5)}';
      }
      return 'Live location not fetched yet';
    }
    return _locationController.text.trim().isEmpty ? 'Search location' : _locationController.text.trim();
  }

  String get _categoryLabel {
    return '${_selectedCategory.title} • $_resolvedSubcategory';
  }

  _NeedCategoryOption get _selectedCategory {
    return _needCategoryOptions.firstWhere(
      (option) => option.key == _categoryKey,
      orElse: () => _needCategoryOptions.first,
    );
  }

  String get _resolvedSubcategory {
    if (_categoryKey == 'others') {
      final customValue = _otherSubcategoryController.text.trim();
      if (customValue.isNotEmpty) {
        return customValue;
      }
    }
    return _selectedSubcategory;
  }

  String get _urgencyLabel {
    switch (_urgency) {
      case _UrgencyLevel.critical:
        return 'Critical';
      case _UrgencyLevel.high:
        return 'High';
      case _UrgencyLevel.medium:
        return 'Medium';
      case _UrgencyLevel.low:
        return 'Low';
    }
  }

  Color _urgencyColor(_UrgencyLevel urgency) {
    switch (urgency) {
      case _UrgencyLevel.critical:
        return const Color(0xFFE44D5B);
      case _UrgencyLevel.high:
        return const Color(0xFFF07842);
      case _UrgencyLevel.medium:
        return const Color(0xFFE0B64D);
      case _UrgencyLevel.low:
        return const Color(0xFF58A55C);
    }
  }

  Future<void> _pickFileFromCamera() async {
    try {
      setState(() => _isUploadingFile = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        if (!mounted) {
          return;
        }
        if (!_canAttachFile(bytes.length)) {
          return;
        }

        final fileName = picked.name.trim().isNotEmpty
            ? picked.name
            : 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ext = _normalizedExtension(_extensionFromNameOrPath(fileName, picked.path));
        final doc = DocumentAttachment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: fileName,
          fileType: ext != null ? _getMimeType(ext) : 'image/jpeg',
          fileSizeBytes: bytes.length,
          base64Data: base64Encode(bytes),
          uploadedAt: DateTime.now(),
          localPath: picked.path,
        );

        setState(() {
          _supportingDocs.add(doc);
        });
        _showUploadSuccessToast();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  Future<void> _pickFileFromGallery() async {
    try {
      setState(() => _isUploadingFile = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        if (!mounted) {
          return;
        }
        if (!_canAttachFile(bytes.length)) {
          return;
        }

        final fileName = picked.name.trim().isNotEmpty
            ? picked.name
            : 'gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ext = _normalizedExtension(_extensionFromNameOrPath(fileName, picked.path));
        final doc = DocumentAttachment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: fileName,
          fileType: ext != null ? _getMimeType(ext) : 'image/jpeg',
          fileSizeBytes: bytes.length,
          base64Data: base64Encode(bytes),
          uploadedAt: DateTime.now(),
          localPath: picked.path,
        );

        setState(() {
          _supportingDocs.add(doc);
        });
        _showUploadSuccessToast();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting from gallery: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  Future<void> _pickFileFromBrowser() async {
    try {
      setState(() => _isUploadingFile = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'gif'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        if (file.bytes != null) {
          if (!_canAttachFile(file.size)) {
            return;
          }

          final base64 = base64Encode(file.bytes!);
          final ext = _normalizedExtension(file.extension);
          final doc = DocumentAttachment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            fileName: file.name,
            fileType: ext != null ? _getMimeType(ext) : 'application/octet-stream',
            fileSizeBytes: file.size,
            base64Data: base64,
            uploadedAt: DateTime.now(),
            localPath: file.path,
          );
          setState(() {
            _supportingDocs.add(doc);
          });
          _showUploadSuccessToast();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  String _getMimeType(String extension) {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  String? _normalizedExtension(String? extension) {
    final value = extension?.trim().toLowerCase().replaceFirst('.', '');
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? _extensionFromNameOrPath(String? name, String? path) {
    final fromName = _extractExtension(name);
    if (fromName != null) {
      return fromName;
    }
    return _extractExtension(path);
  }

  String? _extractExtension(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    if (!fileName.contains('.')) {
      return null;
    }
    final ext = fileName.split('.').last.trim();
    return ext.isEmpty ? null : ext;
  }

  bool _canAttachFile(int newFileSize) {
    if (_supportingDocs.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 5 files only.')),
      );
      return false;
    }

    final currentBytes = _supportingDocs.fold<int>(0, (sum, doc) => sum + doc.fileSizeBytes);
    final nextBytes = currentBytes + newFileSize;
    const maxTotalBytes = 50 * 1024 * 1024;

    if (nextBytes > maxTotalBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total attachment size must stay within 50 MB.')),
      );
      return false;
    }

    return true;
  }

  void _showUploadSuccessToast() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(milliseconds: 1700),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F9D55),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1F9D55).withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'File uploaded successfully',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  void _showReportSubmittedToast() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(milliseconds: 2200),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF127A6E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF7BE0C5).withValues(alpha: 0.55),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF127A6E).withValues(alpha: 0.34),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Report submitted successfully',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Future<void> _previewAttachment(DocumentAttachment attachment) async {
    if (attachment.isImage) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final imageBytes = base64Decode(attachment.base64Data);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.black,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                attachment.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                attachment.fileSizeDisplay,
                                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    if (attachment.isPdf) {
      try {
        final pdfPath = await _resolveLocalPreviewPath(attachment, extensionHint: 'pdf');
        if (pdfPath == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to prepare the PDF for opening.')),
          );
          return;
        }

        final result = await OpenFilex.open(pdfPath);
        if (!mounted) return;
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open PDF: ${result.message}')),
          );
        }
      } on MissingPluginException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF opener is not initialized yet. Fully stop and rerun the app once.'),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $error')),
        );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preview is available for images and PDFs only.')),
    );
  }

  Future<String?> _resolveLocalPreviewPath(
    DocumentAttachment attachment, {
    required String extensionHint,
  }) async {
    final existingPath = attachment.localPath;
    if (existingPath != null && existingPath.trim().isNotEmpty) {
      final file = File(existingPath);
      if (await file.exists()) {
        return existingPath;
      }
    }

    try {
      final directory = await getTemporaryDirectory();
      final safeName = attachment.fileName.trim().isNotEmpty
          ? attachment.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
          : 'attachment_${attachment.id}.$extensionHint';
      final fileName = safeName.toLowerCase().endsWith('.$extensionHint')
          ? safeName
          : '$safeName.$extensionHint';
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(base64Decode(attachment.base64Data), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  void _nextStep(BuildContext context) {
    if (_step == 0) {
      if (_locationMode != _LocationMode.current && _locationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a location first.')),
        );
        return;
      }
    }

    if (_step == 3) {
      final titleError = _validateTitle();
      if (titleError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(titleError)));
        return;
      }
    }

    setState(() => _step += 1);
  }

  String? _validateTitle() {
    if (_titleController.text.trim().isEmpty) {
      return 'Need title is required';
    }
    if (_descriptionController.text.trim().isEmpty) {
      return 'Description is required';
    }
    return null;
  }

  Future<void> _submitNeed(
    BuildContext context,
    AuthService authService,
    NeedSubmissionService submissionService,
    String reporterName,
    String reporterEmail,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsedPeopleAffected = int.tryParse(_peopleAffectedController.text.trim()) ?? _peopleAffected;

    setState(() => _isSubmitting = true);

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final contactName = _contactNameController.text.trim();
      final contactPhone = _contactPhoneController.text.trim();
      final currentUser = authService.currentUser;

      final need = NeedModel(
        id: '',
        title: title,
        category: _categoryKey,
        subcategory: _resolvedSubcategory,
        urgency: _urgency.name,
        description: description,
        location: _resolvedLocation,
        locationMode: _locationMode.name,
        reportedBy: currentUser?.uid ?? reporterEmail,
        peopleAffected: parsedPeopleAffected,
        status: 'open',
        latitude: _locationMode == _LocationMode.current ? _currentLatitude : null,
        longitude: _locationMode == _LocationMode.current ? _currentLongitude : null,
        contactName: contactName.isEmpty ? null : contactName,
        contactPhone: contactPhone.isEmpty ? null : contactPhone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        supportingDocsMetadata: _supportingDocs.isNotEmpty
          ? _supportingDocs.map((doc) => doc.toFirestoreMetadataMap()).toList()
            : null,
      );

      await submissionService.submitNeed(need);

      if (!context.mounted) return;

      _showReportSubmittedToast();

      setState(() {
        _step = 0;
        _titleController.clear();
        _descriptionController.clear();
        _contactNameController.clear();
        _contactPhoneController.clear();
        _locationMode = _LocationMode.current;
        _currentLocationLabel = 'Tap to fetch your live location';
        _currentLatitude = null;
        _currentLongitude = null;
        _isCurrentLocationFetched = false;
        _categoryKey = 'medical';
        _selectedSubcategory = 'Injuries';
        _expandedCategoryKey = 'medical';
        _otherSubcategoryController.clear();
        _urgency = _UrgencyLevel.critical;
        _peopleAffected = 24;
        _peopleAffectedController.text = '24';
        _locationController.clear();
        _supportingDocs.clear();
      });
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.step,
    required this.totalSteps,
  });

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: List.generate(totalSteps, (index) {
        final active = index <= step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 8),
            height: 4,
            decoration: BoxDecoration(
              color: active ? theme.colorScheme.primary : const Color(0xFFE6E1D4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenHorizontalPadding,
        14,
        AppConstants.screenHorizontalPadding,
        10,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A4A4A),
            ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.mode,
    required this.selected,
    this.success = false,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    required this.onTap,
  });

  final _LocationMode mode;
  final bool selected;
  final bool success;
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = success
      ? const Color(0xFF1F9D55).withValues(alpha: 0.70)
      : selected
        ? theme.colorScheme.primary.withValues(alpha: 0.55)
        : theme.colorScheme.outlineVariant;
    final background = success
      ? const Color(0xFFEAF9F2)
      : selected
        ? const Color(0xFFF2F0DE)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: success
                      ? const Color(0xFFDFF3E9)
                      : selected
                          ? const Color(0xFFE8DDC1)
                          : const Color(0xFFF4F1E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  success ? Icons.gps_fixed_rounded : icon,
                  color: success ? const Color(0xFF1F9D55) : (selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (success)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF1F9D55),
                )
              else if (selected)
                Icon(
                  Icons.check_rounded,
                  color: theme.colorScheme.primary,
                )
              else if (trailing != null)
                Icon(
                  trailing,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedCategoryOption {
  const _NeedCategoryOption({
    required this.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.subcategories,
  });

  final String key;
  final String title;
  final IconData icon;
  final Color color;
  final List<String> subcategories;
}

class _NeedCategoryCard extends StatelessWidget {
  const _NeedCategoryCard({
    required this.option,
    required this.isSelected,
    required this.isExpanded,
    required this.selectedSubcategory,
    required this.onHeaderTap,
    required this.onSubcategoryTap,
    this.customOtherController,
  });

  final _NeedCategoryOption option;
  final bool isSelected;
  final bool isExpanded;
  final String? selectedSubcategory;
  final VoidCallback onHeaderTap;
  final ValueChanged<String> onSubcategoryTap;
  final TextEditingController? customOtherController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? option.color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? option.color.withValues(alpha: 0.75) : theme.colorScheme.outlineVariant,
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onHeaderTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: option.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(option.icon, color: option.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2A3338),
                          ),
                        ),
                        if (isSelected && selectedSubcategory != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            selectedSubcategory!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: option.color.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final subcategory in option.subcategories)
                        if (subcategory == 'Other')
                          Tooltip(
                            message: 'Can\'t find your specific need? Tell us more in the description.',
                            child: ChoiceChip(
                              avatar: Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 16,
                                color: selectedSubcategory == subcategory
                                    ? option.color
                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              label: Text(
                                subcategory,
                                style: const TextStyle(fontStyle: FontStyle.italic),
                              ),
                              selected: selectedSubcategory == subcategory,
                              showCheckmark: false,
                              selectedColor: option.color.withValues(alpha: 0.15),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: selectedSubcategory == subcategory
                                    ? option.color.withValues(alpha: 0.8)
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                width: selectedSubcategory == subcategory ? 1.5 : 1,
                                strokeAlign: BorderSide.strokeAlignOutside,
                              ),
                              labelStyle: theme.textTheme.bodySmall?.copyWith(
                                color: selectedSubcategory == subcategory ? option.color : theme.colorScheme.onSurfaceVariant,
                                fontWeight: selectedSubcategory == subcategory ? FontWeight.w700 : FontWeight.w500,
                              ),
                              onSelected: (_) => onSubcategoryTap(subcategory),
                            ),
                          )
                        else
                          ChoiceChip(
                            label: Text(subcategory),
                            selected: selectedSubcategory == subcategory,
                            showCheckmark: false,
                            selectedColor: option.color.withValues(alpha: 0.2),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: selectedSubcategory == subcategory ? option.color : theme.colorScheme.outlineVariant,
                            ),
                            labelStyle: theme.textTheme.bodySmall?.copyWith(
                              color: selectedSubcategory == subcategory ? option.color : theme.colorScheme.onSurfaceVariant,
                              fontWeight: selectedSubcategory == subcategory ? FontWeight.w700 : FontWeight.w500,
                            ),
                            onSelected: (_) => onSubcategoryTap(subcategory),
                          ),
                    ],
                  ),
                  if (option.key == 'others' && selectedSubcategory == 'Other' && customOtherController != null) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: customOtherController,
                      decoration: const InputDecoration(
                        labelText: 'Specify other category',
                        hintText: 'Type the specific need category',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 190),
          ),
        ],
      ),
    );
  }
}

class _ChoiceItem<T> {
  const _ChoiceItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class _ChoiceGrid<T> extends StatelessWidget {
  const _ChoiceGrid({
    required this.selected,
    required this.items,
    required this.onChanged,
    required this.colorFor,
  });

  final T selected;
  final List<_ChoiceItem<T>> items;
  final ValueChanged<T> onChanged;
  final Color Function(T value) colorFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.screenHorizontalPadding),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(
              child: _ChoiceTile<T>(
                item: items[i],
                selected: selected == items[i].value,
                color: colorFor(items[i].value),
                onTap: () => onChanged(items[i].value),
              ),
            ),
            if (i != items.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.item,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final _ChoiceItem<T> item;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF3F0E6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? color : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleCounterButton extends StatelessWidget {
  const _CircleCounterButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF2F0E4) : const Color(0xFFE3E1D8),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? const Color(0xFF7A7A72) : const Color(0xFFB1ADA0),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.alignTop = false,
  });

  final String label;
  final String value;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF434B4D),
            ),
          ),
        ),

      ],
    );
  }
}

class _DocumentUploadCard extends StatelessWidget {
  const _DocumentUploadCard({
    required this.label,
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              )
            else
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isLoading ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

