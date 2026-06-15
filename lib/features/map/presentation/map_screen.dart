import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/firestore/firestore_paths.dart';
import '../../reports/presentation/report_detail_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../volunteer/presentation/screens/volunteer_mission_detail_screen.dart';
import '../../volunteer/presentation/controllers/volunteer_controller.dart';
import '../../../services/volunteer_service.dart';
import '../../../models/volunteer_model.dart';

Color _colorForUrgency(double score) {
  if (score >= 4.5) return const Color(0xFFD32F2F);
  if (score >= 3.5) return const Color(0xFFF57C00);
  if (score >= 2.5) return const Color(0xFFFBC02D);
  return const Color(0xFF388E3C);
}

enum MapLayerCategory {
  myMission,
  medical,
  food,
  airborne,
  waterborne,
  mentalHealth,
  naturalDisaster,
}

class MapScreen extends ConsumerWidget {
  const MapScreen({
    super.key,
    this.initialLayer = MapLayerCategory.medical,
    this.initialFocus,
    this.initialZoom = 13.0,
    this.lockInitialFocus = false,
    this.initialReportId,
    this.isVolunteer = false,
  });

  final MapLayerCategory initialLayer;
  final LatLng? initialFocus;
  final double initialZoom;
  final bool lockInitialFocus;
  final String? initialReportId;
  final bool isVolunteer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MapPage(
      initialLayer: initialLayer,
      initialFocus: initialFocus,
      initialZoom: initialZoom,
      lockInitialFocus: lockInitialFocus,
      initialReportId: initialReportId,
      isVolunteer: isVolunteer,
    );
  }
}

class MapPage extends ConsumerStatefulWidget {
  const MapPage({
    super.key,
    this.initialLayer = MapLayerCategory.medical,
    this.initialFocus,
    this.initialZoom = 13.0,
    this.lockInitialFocus = false,
    this.initialReportId,
    this.isVolunteer = false,
  });

  final MapLayerCategory initialLayer;
  final LatLng? initialFocus;
  final double initialZoom;
  final bool lockInitialFocus;
  final String? initialReportId;
  final bool isVolunteer;

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  static const LatLng _sambhajinagar = LatLng(19.8762, 75.3433);
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: _sambhajinagar,
    zoom: 13.0,
  );
  static const _heatmapIdCritical = HeatmapId(
    'allocare_needs_density_critical',
  );
  static const _heatmapIdHigh = HeatmapId('allocare_needs_density_high');
  static const _heatmapIdMedium = HeatmapId('allocare_needs_density_medium');
  static const _heatmapIdLow = HeatmapId('allocare_needs_density_low');

  static const HeatmapGradient _criticalRiskGradient = HeatmapGradient([
    HeatmapGradientColor(Color(0x14D32F2F), 0.12),
    HeatmapGradientColor(Color(0x66D32F2F), 0.56),
    HeatmapGradientColor(Color(0xFFD32F2F), 1.0),
  ]);
  static const HeatmapGradient _highRiskGradient = HeatmapGradient([
    HeatmapGradientColor(Color(0x14F57C00), 0.12),
    HeatmapGradientColor(Color(0x66F57C00), 0.56),
    HeatmapGradientColor(Color(0xFFF57C00), 1.0),
  ]);
  static const HeatmapGradient _mediumRiskGradient = HeatmapGradient([
    HeatmapGradientColor(Color(0x14F9A825), 0.12),
    HeatmapGradientColor(Color(0x66F9A825), 0.56),
    HeatmapGradientColor(Color(0xFFF9A825), 1.0),
  ]);
  static const HeatmapGradient _lowRiskGradient = HeatmapGradient([
    HeatmapGradientColor(Color(0x142E7D32), 0.12),
    HeatmapGradientColor(Color(0x662E7D32), 0.56),
    HeatmapGradientColor(Color(0xFF2E7D32), 1.0),
  ]);

  static const HeatmapGradient _airborneMagentaGradient = HeatmapGradient([
    HeatmapGradientColor(Color(0x14B5179E), 0.12),
    HeatmapGradientColor(Color(0x66B5179E), 0.56),
    HeatmapGradientColor(Color(0xFFB5179E), 1.0),
  ]);
  static const HeatmapGradient _airbornePurpleGradient = HeatmapGradient([
    HeatmapGradientColor(Color(0x147209B7), 0.12),
    HeatmapGradientColor(Color(0x667209B7), 0.56),
    HeatmapGradientColor(Color(0xFF7209B7), 1.0),
  ]);
  static const HeatmapGradient _waterborneCyanGradient = HeatmapGradient([
    HeatmapGradientColor(Color(0x1400B4D8), 0.12),
    HeatmapGradientColor(Color(0x6600B4D8), 0.56),
    HeatmapGradientColor(Color(0xFF00B4D8), 1.0),
  ]);
  static const HeatmapGradient _waterborneNavyGradient = HeatmapGradient([
    HeatmapGradientColor(Color(0x1403045E), 0.12),
    HeatmapGradientColor(Color(0x6603045E), 0.56),
    HeatmapGradientColor(Color(0xFF03045E), 1.0),
  ]);

  GoogleMapController? _mapController;
  final CustomInfoWindowController _infoWindowController =
      CustomInfoWindowController();
  final Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream =
      FirebaseFirestore.instance.collection(FirestorePaths.reports).snapshots();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSubscription;
  QuerySnapshot<Map<String, dynamic>>? _latestReportsSnapshot;
  Set<Marker> _markers = <Marker>{};
  Set<Heatmap> _heatmaps = <Heatmap>{};
  Set<Circle> _circles = <Circle>{};
  int _docsInSnapshot = 0;
  int _docsWithCoordinates = 0;
  int _heatPointsCount = 0;
  bool _hasAutoFramed = false;

  BitmapDescriptor _glowMarkerIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _responderMarkerIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _myMissionMarkerIcon = BitmapDescriptor.defaultMarker;
  String? _autoCenteredMissionId;
  _LayerCategory _selectedCategory = _LayerCategory.medical;
  final Set<String> _announcedAssignmentKeys = <String>{};
  _MissionDispatchAlert? _missionDispatchAlert;
  Timer? _missionDispatchTimer;
  bool _hasProcessedInitialSnapshot = false;

  bool _isMapInitializing = true;
  bool _isPermissionLoading = true;
  bool _hasLocationPermission = false;
  String? _permissionMessage;
  LatLng? _selectedMarkerPosition;
  bool _didApplyRequestedInitialFocus = false;

  // Command Center Dispatch Alert state
  CommandCenterDispatchData? _dispatchAlert;
  bool _hasSelectedInitialReport = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _fromMapLayer(widget.initialLayer);
    unawaited(_resolveLocationPermission());
    unawaited(_loadMarkerIcons());
    _reportsSubscription = _reportsStream.listen(
      _onReportsSnapshot,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Reports stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _missionDispatchTimer?.cancel();
    _infoWindowController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onReportsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _latestReportsSnapshot = snapshot;
    final layers = _buildMapLayers(snapshot);
    if (!mounted) {
      return;
    }

    setState(() {
      _markers = layers.markers;
      _heatmaps = layers.heatmaps;
      _circles = layers.circles;
    });

    _handleMissionDispatchSnapshot(snapshot);
    unawaited(_focusCameraOnData(layers.focusPoints));

    // Auto-select initial report if passed
    if (widget.initialReportId != null && !_hasSelectedInitialReport) {
      _hasSelectedInitialReport = true;
      DocumentSnapshot<Map<String, dynamic>>? matchedDoc;
      for (final doc in snapshot.docs) {
        if (doc.id == widget.initialReportId) {
          matchedDoc = doc;
          break;
        }
      }
      if (matchedDoc != null) {
        final data = matchedDoc.data();
        final position = data != null ? _extractLatLng(data) : null;
        if (position != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showReportBriefing(
              reportId: matchedDoc!.id,
              reportData: data!,
              position: position,
            );
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: position, zoom: 15.0),
              ),
            );
          });
        }
      }
    }

    print('Mapped ${layers.markers.length} markers');
    print(
      'Layer=${_selectedCategory.name}, docs=$_docsInSnapshot, '
      'coords=$_docsWithCoordinates, heatPoints=$_heatPointsCount',
    );
  }

  void _handleMissionDispatchSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!_hasProcessedInitialSnapshot) {
      _hasProcessedInitialSnapshot = true;
      return;
    }

    _MissionDispatchAlert? latestAlert;

    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        continue;
      }

      final data = change.doc.data();
      if (data == null) {
        continue;
      }

      final category = (data['category'] as String? ?? '').trim().toLowerCase();
      if (category != _selectedCategory.firestoreCategoryKey) {
        continue;
      }

      final volunteerId = (data['assigned_volunteer_id'] as String?)?.trim();
      final volunteerName = (data['assigned_volunteer_name'] as String?)
          ?.trim();
      if ((volunteerId == null || volunteerId.isEmpty) &&
          (volunteerName == null || volunteerName.isEmpty)) {
        continue;
      }

      final alertKey = _assignmentAlertKey(change.doc.id, data);
      if (_announcedAssignmentKeys.contains(alertKey)) {
        continue;
      }

      final position = _extractLatLng(data);
      if (position == null) {
        continue;
      }

      final crisisType = _readDisplayValue(data, const [
        'crisis_type',
        'subcategory',
        'title',
      ], 'Active Response');
      final speciality = (data['assigned_volunteer_speciality'] as String?)
          ?.trim();

      latestAlert = _MissionDispatchAlert(
        reportId: change.doc.id,
        reportData: data,
        position: position,
        volunteerName: volunteerName?.isNotEmpty == true
            ? volunteerName!
            : 'Volunteer',
        volunteerSpeciality: speciality == null || speciality.isEmpty
            ? 'Specialist'
            : speciality,
        crisisType: crisisType,
      );
      _announcedAssignmentKeys.add(alertKey);
    }

    if (latestAlert == null) {
      return;
    }

    _missionDispatchTimer?.cancel();
    setState(() {
      _missionDispatchAlert = latestAlert;
    });

    _missionDispatchTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _missionDispatchAlert = null;
      });
    });
  }

  String _assignmentAlertKey(String reportId, Map<String, dynamic> data) {
    final volunteerId =
        (data['assigned_volunteer_id'] as String?)?.trim() ?? '';
    final assignedAt = data['assigned_at'];
    final assignedAtKey = assignedAt is Timestamp
        ? assignedAt.microsecondsSinceEpoch.toString()
        : assignedAt?.toString() ?? '';
    return '$reportId|$volunteerId|$assignedAtKey';
  }

  void _onLayerChanged(_LayerCategory category) {
    if (_selectedCategory == category) {
      return;
    }

    setState(() {
      _selectedCategory = category;
    });

    if (_latestReportsSnapshot != null) {
      _onReportsSnapshot(_latestReportsSnapshot!);
    }

    setState(() {
      _selectedMarkerPosition = null;
    });
  }

  Future<void> _openSelectedLocationInMaps() async {
    final selected = _selectedMarkerPosition;
    if (selected == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${selected.latitude},${selected.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openDirectionsToSelectedLocation() async {
    final selected = _selectedMarkerPosition;
    if (selected == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${selected.latitude},${selected.longitude}&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showDispatchAlert({
    required String volunteerName,
    required String crisisType,
    required String areaName,
    required LatLng reportPosition,
  }) {
    setState(() {
      _dispatchAlert = CommandCenterDispatchData(
        volunteerName: volunteerName,
        crisisType: crisisType,
        areaName: areaName,
        reportPosition: reportPosition,
      );
    });
  }

  void _hideDispatchAlert() {
    setState(() {
      _dispatchAlert = null;
    });
  }

  void _onViewDispatchOnMap() {
    if (_dispatchAlert == null) return;

    // Animate camera to the report location
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _dispatchAlert!.reportPosition, zoom: 15.0),
      ),
    );

    // Show the report briefing for this location
    // Note: We'll need to find the corresponding report data
    // This is a placeholder - you may need to adjust based on your data structure
  }

  // Public method to be called from submitReport function after SmartAllocationService
  void showSmartAllocationDispatch({
    required String volunteerName,
    required String crisisType,
    required String areaName,
    required double latitude,
    required double longitude,
  }) {
    _showDispatchAlert(
      volunteerName: volunteerName,
      crisisType: crisisType,
      areaName: areaName,
      reportPosition: LatLng(latitude, longitude),
    );
  }

  // Example integration method - call this from your submitReport function
  // after SmartAllocationService successfully assigns a volunteer
  Future<void> handleSmartAllocationResult({
    required Map<String, dynamic> reportData,
    required Map<String, dynamic> allocationResult,
  }) async {
    // Extract volunteer information from allocation result
    final volunteerName =
        allocationResult['volunteer_name'] as String? ?? 'Unknown Volunteer';
    final crisisType =
        reportData['crisis_type'] as String? ??
        reportData['category'] as String? ??
        'Emergency';
    final areaName = _extractAreaName(reportData);
    final position = _extractLatLng(reportData);

    if (position != null) {
      showSmartAllocationDispatch(
        volunteerName: volunteerName,
        crisisType: crisisType,
        areaName: areaName,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }

  String _extractAreaName(Map<String, dynamic> reportData) {
    // Try to extract area name from various possible fields
    final candidates = [
      reportData['area_name'],
      reportData['location_name'],
      reportData['address'],
      reportData['district'],
      reportData['city'],
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return 'Unknown Area';
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final icons = await Future.wait([
        _buildCreativePinIcon(assigned: false, isMyMission: false),
        _buildCreativePinIcon(assigned: true, isMyMission: false),
        _buildCreativePinIcon(assigned: true, isMyMission: true),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _glowMarkerIcon = icons[0];
        _responderMarkerIcon = icons[1];
        _myMissionMarkerIcon = icons[2];
      });
      if (_latestReportsSnapshot != null) {
        _onReportsSnapshot(_latestReportsSnapshot!);
      }
    } catch (_) {
      // Keep default marker when custom asset is unavailable.
    }
  }

  Future<BitmapDescriptor> _buildCreativePinIcon({
    required bool assigned,
    bool isMyMission = false,
  }) async {
    const baseMarkerSize = 126.0;
    final markerSize = kIsWeb ? 78.0 : baseMarkerSize;
    final scale = markerSize / baseMarkerSize;
    double s(double value) => value * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(markerSize / 2, markerSize / 2);

    final glowPaint = Paint()
      ..color = isMyMission
          ? const Color(0xFF6366F1).withOpacity(0.4)
          : (assigned ? const Color(0x6634D399) : const Color(0x66FF1744));
    final pulsePaint = Paint()
      ..color = isMyMission
          ? const Color(0xFF4F46E5).withOpacity(0.5)
          : (assigned ? const Color(0x88388E3C) : const Color(0x88FF5252));
    final corePaint = Paint()
      ..color = isMyMission
          ? const Color(0xFF4F46E5)
          : (assigned ? const Color(0xFF1A73E8) : const Color(0xFFE53935));
    final innerPaint = Paint()..color = Colors.white;

    canvas.drawCircle(center, s(52), glowPaint);
    canvas.drawCircle(center, s(38), pulsePaint);
    canvas.drawCircle(center, s(22), corePaint);
    canvas.drawCircle(center, s(10), innerPaint);

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s(4);
    canvas.drawCircle(center, s(28), ringPaint);

    if (assigned || isMyMission) {
      final badgeCenter = Offset(markerSize - s(34), s(34));
      final badgePaint = Paint()
        ..color = isMyMission
            ? const Color(0xFFEC4899)
            : const Color(0xFF16A34A);
      canvas.drawCircle(badgeCenter, s(16), badgePaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s(3);
      canvas.drawCircle(badgeCenter, s(16), borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: isMyMission ? '★' : 'V',
          style: TextStyle(
            color: Colors.white,
            fontSize: s(16),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        badgeCenter - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    final pointerPath = Path()
      ..moveTo(center.dx, markerSize - s(8))
      ..lineTo(center.dx - s(11), markerSize - s(34))
      ..lineTo(center.dx + s(11), markerSize - s(34))
      ..close();
    canvas.drawPath(pointerPath, corePaint);

    final image = await recorder.endRecording().toImage(
      markerSize.toInt(),
      markerSize.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }

  Future<void> _resolveLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionMessage =
            'Location services are off. Enable location to use live map positioning.';
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      _hasLocationPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (!_hasLocationPermission &&
          permission == LocationPermission.deniedForever) {
        _permissionMessage =
            'Location permission is permanently denied. Open app settings to enable it.';
      } else if (!_hasLocationPermission && _permissionMessage == null) {
        _permissionMessage =
            'Location permission denied. The map will still load without device location.';
      }
    } catch (_) {
      _permissionMessage =
          'Unable to verify location permission right now. Please try again.';
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPermissionLoading = false;
      });
    }
  }

  DocumentSnapshot<Map<String, dynamic>>? _findActiveMissionDoc(
    VolunteerModel? volunteer,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (volunteer == null) return null;
    final missionId = volunteer.currentMissionId;
    if (missionId == null || missionId.isEmpty) return null;
    for (final doc in snapshot.docs) {
      if (doc.id == missionId) {
        return doc;
      }
    }
    // Fallback search by status and matchedVolunteerId
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['matchedVolunteerId'] == volunteer.uid &&
          (data['status'] == 'pending_acceptance' ||
              data['status'] == 'assigned')) {
        return doc;
      }
      if (data['assigned_volunteer_id'] == volunteer.uid &&
          (data['status'] == 'pending_acceptance' ||
              data['status'] == 'assigned')) {
        return doc;
      }
    }
    return null;
  }

  Future<LatLng?> _getCurrentLatLng() async {
    try {
      if (_hasLocationPermission) {
        final pos = await Geolocator.getCurrentPosition();
        return LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}
    return null;
  }

  void _centerMapOnMission(LatLng volunteerLatLng, LatLng missionLatLng) {
    if (_mapController == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(volunteerLatLng.latitude, missionLatLng.latitude),
        math.min(volunteerLatLng.longitude, missionLatLng.longitude),
      ),
      northeast: LatLng(
        math.max(volunteerLatLng.latitude, missionLatLng.latitude),
        math.max(volunteerLatLng.longitude, missionLatLng.longitude),
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  String _formatDistance(LatLng? p1, LatLng? p2) {
    if (p1 == null || p2 == null) return 'Calculating distance...';
    final meters = Geolocator.distanceBetween(
      p1.latitude,
      p1.longitude,
      p2.latitude,
      p2.longitude,
    );
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km away';
  }

  Future<String> _loadCustomMapStyleJson() {
    return rootBundle.loadString('lib/assets/maps/silver_dark_style.json');
  }

  Future<void> _applyCustomMapStyle() async {
    if (_mapController == null) {
      return;
    }

    try {
      final styleJson = await _loadCustomMapStyleJson();
      await _mapController!.setMapStyle(styleJson);
    } catch (_) {
      // Fall back to default style when style loading fails.
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _infoWindowController.googleMapController = controller;
    await _applyCustomMapStyle();
    await _applyRequestedInitialView();

    if (!mounted) {
      return;
    }
    setState(() {
      _isMapInitializing = false;
    });
  }

  _LayerCategory _fromMapLayer(MapLayerCategory layer) {
    switch (layer) {
      case MapLayerCategory.myMission:
        return _LayerCategory.myMission;
      case MapLayerCategory.medical:
        return _LayerCategory.medical;
      case MapLayerCategory.food:
        return _LayerCategory.food;
      case MapLayerCategory.airborne:
        return _LayerCategory.airborne;
      case MapLayerCategory.waterborne:
        return _LayerCategory.waterborne;
      case MapLayerCategory.mentalHealth:
        return _LayerCategory.mentalHealth;
      case MapLayerCategory.naturalDisaster:
        return _LayerCategory.naturalDisaster;
    }
  }

  Future<void> _applyRequestedInitialView() async {
    if (_mapController == null || _didApplyRequestedInitialFocus) {
      return;
    }
    _didApplyRequestedInitialFocus = true;

    final target = widget.initialFocus ?? _sambhajinagar;
    if (widget.lockInitialFocus) {
      _hasAutoFramed = true;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: widget.initialZoom),
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  LatLng? _parseLatLngFromLocationString(String rawLocation) {
    final text = rawLocation.trim();
    if (text.isEmpty) {
      return null;
    }

    try {
      final coordinateSegment = text.contains('·')
          ? text.split('·').last.trim()
          : text;
      final parts = coordinateSegment.split(',');
      if (parts.length != 2) {
        return null;
      }

      final latitude = double.parse(parts[0].trim());
      final longitude = double.parse(parts[1].trim());
      return LatLng(latitude, longitude);
    } catch (_) {
      return null;
    }
  }

  LatLng? _extractLatLng(Map<String, dynamic> data) {
    final locationRaw = data['location'];
    if (locationRaw is GeoPoint) {
      return LatLng(locationRaw.latitude, locationRaw.longitude);
    }

    if (locationRaw is String) {
      final parsed = _parseLatLngFromLocationString(locationRaw);
      if (parsed != null) {
        return parsed;
      }

      // If location is coordinate-like but malformed, skip this document.
      if (locationRaw.contains(',') || locationRaw.contains('·')) {
        return null;
      }
    }

    final coordinatesRaw = data['coordinates'];
    if (coordinatesRaw is GeoPoint) {
      return LatLng(coordinatesRaw.latitude, coordinatesRaw.longitude);
    }

    if (coordinatesRaw is Map<String, dynamic>) {
      final coordinates = coordinatesRaw;
      final latitude = _toDouble(coordinates['latitude'] ?? coordinates['lat']);
      final longitude = _toDouble(
        coordinates['longitude'] ?? coordinates['lng'],
      );
      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }
    }

    final latitude = _toDouble(data['latitude'] ?? data['lat']);
    final longitude = _toDouble(data['longitude'] ?? data['lng']);
    if (latitude == null || longitude == null) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  double _extractUrgencyScore(Map<String, dynamic> data) {
    final score = _toDouble(data['urgency_score']);
    if (score != null && score > 0) {
      return score;
    }

    final urgency = (data['urgency'] as String?)?.trim().toLowerCase();
    switch (urgency) {
      case 'critical':
        return 5.0;
      case 'high':
        return 4.0;
      case 'medium':
      case 'normal':
        return 3.0;
      case 'low':
        return 2.0;
      default:
        return 1.0;
    }
  }

  String _resolveUrgencyLevel(Map<String, dynamic> data) {
    final urgency = (data['urgency'] as String?)?.trim().toLowerCase();
    if (urgency != null) {
      switch (urgency) {
        case 'critical':
        case 'high':
        case 'medium':
        case 'low':
          return urgency;
        case 'normal':
          return 'medium';
      }
    }

    final numericScore = _toDouble(data['urgency_score']);
    if (numericScore != null) {
      // Support both 10-point and 5-point urgency scales.
      if (numericScore > 5) {
        if (numericScore >= 8) return 'critical';
        if (numericScore >= 6) return 'high';
        if (numericScore >= 3) return 'medium';
        return 'low';
      }
      if (numericScore >= 4.5) return 'critical';
      if (numericScore >= 3.5) return 'high';
      if (numericScore >= 2.5) return 'medium';
      return 'low';
    }

    return 'medium';
  }

  Color _urgencyHaloFillColor(Map<String, dynamic> data) {
    switch (_resolveUrgencyLevel(data)) {
      case 'critical':
        return const Color(0x66E53935);
      case 'high':
        return const Color(0x66FB8C00);
      case 'low':
        return const Color(0x6643A047);
      case 'medium':
      default:
        return const Color(0x66FBC02D);
    }
  }

  Color _urgencyHaloStrokeColor(Map<String, dynamic> data) {
    switch (_resolveUrgencyLevel(data)) {
      case 'critical':
        return const Color(0xFFD32F2F);
      case 'high':
        return const Color(0xFFF57C00);
      case 'low':
        return const Color(0xFF2E7D32);
      case 'medium':
      default:
        return const Color(0xFFF9A825);
    }
  }

  int _stableSeedFromKey(String key) {
    var seed = 0;
    for (final code in key.codeUnits) {
      seed = ((seed * 31) + code) & 0x7fffffff;
    }
    return seed;
  }

  double _unitNoise(int seed, int index, double salt) {
    final value = math.sin((seed * 0.013) + (index * 1.973) + salt * 3.14159);
    return (value + 1.0) / 2.0;
  }

  double _metersToLatitudeDelta(double meters) {
    return meters / 111320.0;
  }

  double _metersToLongitudeDelta(double meters, double latitude) {
    final latitudeRadians = latitude * (math.pi / 180.0);
    final denominator = math.max(0.2, math.cos(latitudeRadians).abs());
    return meters / (111320.0 * denominator);
  }

  List<WeightedLatLng> _buildIrregularHeatCluster({
    required LatLng center,
    required double urgencyScore,
    required String seedKey,
  }) {
    final seed = _stableSeedFromKey(seedKey);
    final normalizedUrgency = urgencyScore.clamp(1.0, 5.0).toDouble();
    // Broader base spread so clusters remain visible and organic when zoomed out.
    final baseRadiusMeters = 180.0 + (normalizedUrgency * 45.0);

    final anisotropy = 0.68 + (_unitNoise(seed, 2, 0.7) * 0.72);
    final rotation = _unitNoise(seed, 3, 1.9) * (math.pi * 2);

    final points = <WeightedLatLng>[
      WeightedLatLng(center, weight: normalizedUrgency * 1.35),
    ];

    final rings = <({double radiusFactor, int count, double weightFactor})>[
      (radiusFactor: 0.30, count: 8, weightFactor: 1.0),
      (radiusFactor: 0.58, count: 11, weightFactor: 0.78),
      (radiusFactor: 0.92, count: 14, weightFactor: 0.58),
      (radiusFactor: 1.24, count: 10, weightFactor: 0.42),
      (radiusFactor: 1.58, count: 8, weightFactor: 0.30),
    ];

    var pointIndex = 0;
    for (final ring in rings) {
      for (var i = 0; i < ring.count; i++) {
        pointIndex++;
        final t = (i / ring.count) * (math.pi * 2);
        final angleJitter = (_unitNoise(seed, pointIndex, 1.4) - 0.5) * 0.68;
        final radialJitter = 0.58 + (_unitNoise(seed, pointIndex, 2.8) * 0.95);
        final angle = t + rotation + angleJitter;
        final radiusMeters =
            baseRadiusMeters * ring.radiusFactor * radialJitter;

        final dxMeters = math.cos(angle) * radiusMeters;
        final dyMeters = math.sin(angle) * radiusMeters * anisotropy;

        final latitude = center.latitude + _metersToLatitudeDelta(dyMeters);
        final longitude =
            center.longitude +
            _metersToLongitudeDelta(dxMeters, center.latitude);

        final weightNoise = 0.64 + (_unitNoise(seed, pointIndex, 0.9) * 0.76);
        points.add(
          WeightedLatLng(
            LatLng(latitude, longitude),
            weight: normalizedUrgency * ring.weightFactor * weightNoise,
          ),
        );
      }
    }

    return points;
  }

  HeatmapId _heatmapIdForUrgency(String urgencyLevel) {
    switch (urgencyLevel) {
      case 'critical':
        return _heatmapIdCritical;
      case 'high':
        return _heatmapIdHigh;
      case 'low':
        return _heatmapIdLow;
      case 'medium':
      default:
        return _heatmapIdMedium;
    }
  }

  HeatmapGradient _heatGradientForLayer({
    required _LayerCategory category,
    required String urgencyLevel,
  }) {
    if (category == _LayerCategory.airborne) {
      // Airborne palette: magenta for lower urgency, electric purple for high risk.
      switch (urgencyLevel) {
        case 'critical':
        case 'high':
          return _airbornePurpleGradient;
        case 'low':
        case 'medium':
        default:
          return _airborneMagentaGradient;
      }
    }

    if (category == _LayerCategory.waterborne || category == _LayerCategory.naturalDisaster) {
      // Waterborne and Natural Disaster palette: bright cyan with deep navy for high-risk zones.
      switch (urgencyLevel) {
        case 'critical':
        case 'high':
          return _waterborneNavyGradient;
        case 'low':
        case 'medium':
        default:
          return _waterborneCyanGradient;
      }
    }

    if (category == _LayerCategory.mentalHealth) {
      // Mental Health palette: teal with emerald for high-risk zones.
      switch (urgencyLevel) {
        case 'critical':
        case 'high':
          return const HeatmapGradient([
            HeatmapGradientColor(Color(0x14065F46), 0.12),
            HeatmapGradientColor(Color(0x66065F46), 0.56),
            HeatmapGradientColor(Color(0xFF065F46), 1.0),
          ]);
        case 'low':
        case 'medium':
        default:
          return const HeatmapGradient([
            HeatmapGradientColor(Color(0x140D9488), 0.12),
            HeatmapGradientColor(Color(0x660D9488), 0.56),
            HeatmapGradientColor(Color(0xFF0D9488), 1.0),
          ]);
      }
    }

    switch (urgencyLevel) {
      case 'critical':
        return _criticalRiskGradient;
      case 'high':
        return _highRiskGradient;
      case 'low':
        return _lowRiskGradient;
      case 'medium':
      default:
        return _mediumRiskGradient;
    }
  }

  HeatmapRadius _heatRadiusForUrgency(String urgencyLevel) {
    switch (urgencyLevel) {
      case 'critical':
        return const HeatmapRadius.fromPixels(50);
      case 'high':
        return const HeatmapRadius.fromPixels(46);
      case 'medium':
        return const HeatmapRadius.fromPixels(42);
      case 'low':
      default:
        return const HeatmapRadius.fromPixels(38);
    }
  }

  Color _webHeatFillColor({
    required _LayerCategory category,
    required String urgencyLevel,
  }) {
    if (category == _LayerCategory.airborne) {
      return switch (urgencyLevel) {
        'critical' || 'high' => const Color(0x667209B7),
        _ => const Color(0x66B5179E),
      };
    }

    if (category == _LayerCategory.waterborne) {
      return switch (urgencyLevel) {
        'critical' || 'high' => const Color(0x6603045E),
        _ => const Color(0x6600B4D8),
      };
    }

    if (category == _LayerCategory.mentalHealth) {
      return switch (urgencyLevel) {
        'critical' || 'high' => const Color(0x66065F46),
        _ => const Color(0x660D9488),
      };
    }

    return switch (urgencyLevel) {
      'critical' => const Color(0x66D32F2F),
      'high' => const Color(0x66F57C00),
      'low' => const Color(0x662E7D32),
      _ => const Color(0x66F9A825),
    };
  }

  Color _webHeatStrokeColor({
    required _LayerCategory category,
    required String urgencyLevel,
  }) {
    if (category == _LayerCategory.airborne) {
      return switch (urgencyLevel) {
        'critical' || 'high' => const Color(0xCC7209B7),
        _ => const Color(0xCCB5179E),
      };
    }

    if (category == _LayerCategory.waterborne) {
      return switch (urgencyLevel) {
        'critical' || 'high' => const Color(0xCC03045E),
        _ => const Color(0xCC00B4D8),
      };
    }

    if (category == _LayerCategory.mentalHealth) {
      return switch (urgencyLevel) {
        'critical' || 'high' => const Color(0xCC065F46),
        _ => const Color(0xCC0D9488),
      };
    }

    return switch (urgencyLevel) {
      'critical' => const Color(0xCCD32F2F),
      'high' => const Color(0xCCF57C00),
      'low' => const Color(0xCC2E7D32),
      _ => const Color(0xCCF9A825),
    };
  }

  String _readDisplayValue(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final dynamic raw = data[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    }
    return fallback;
  }

  void _showReportBriefing({
    required String reportId,
    required Map<String, dynamic> reportData,
    required LatLng position,
  }) {
    final crisisType = _readDisplayValue(reportData, const [
      'crisis_type',
      'subcategory',
      'title',
    ], 'Acute Waterborne Risk');
    final urgencyScore =
        _toDouble(reportData['urgency_score']) ??
        _extractUrgencyScore(reportData);
    final imageUrl = (reportData['image_url'] as String?)?.trim();
    final assignedVolunteerName =
        (reportData['assigned_volunteer_name'] as String?)?.trim();
    final assignedVolunteerContact =
        (reportData['assigned_volunteer_contact'] as String?)?.trim();
    final assignedVolunteerSpeciality =
        (reportData['assigned_volunteer_speciality'] as String?)?.trim();

    final briefingCard = _MapIntelCard(
      crisisType: crisisType,
      urgencyScore: urgencyScore,
      imageUrl: imageUrl,
      reportData: reportData,
      assignedVolunteerName: assignedVolunteerName,
      assignedVolunteerContact: assignedVolunteerContact,
      assignedVolunteerSpeciality: assignedVolunteerSpeciality,
      onTap: () {
        if (kIsWeb) {
          Navigator.of(context).pop();
        } else {
          _infoWindowController.hideInfoWindow!();
        }
        if (widget.isVolunteer) {
          ref.read(volunteerTabControllerProvider.notifier).state = 1;
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ReportDetailsPage(reportId: reportId, reportData: reportData),
            ),
          );
        }
      },
    );

    setState(() {
      _selectedMarkerPosition = position;
    });

    if (kIsWeb) {
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xE50A111B), Color(0xE5101826)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    briefingCard,
                  ],
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    _infoWindowController.addInfoWindow!(briefingCard, position);
  }

  Future<void> _focusCameraOnData(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) {
      return;
    }

    // Auto-frame once after data first appears; users can then explore manually.
    if (_hasAutoFramed) {
      return;
    }

    _hasAutoFramed = true;
    if (points.length == 1) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 15),
        ),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 70),
    );
  }

  ({
    Set<Marker> markers,
    Set<Heatmap> heatmaps,
    Set<Circle> circles,
    List<LatLng> focusPoints,
  })
  _buildMapLayers(QuerySnapshot<Map<String, dynamic>> snapshot) {
    // ── MY MISSION fast-path ──────────────────────────────────────────────
    if (_selectedCategory == _LayerCategory.myMission) {
      final volunteer = ref.read(currentVolunteerProvider).value;
      final missionDoc = _findActiveMissionDoc(volunteer, snapshot);

      final layerMarkers = <Marker>{};
      final layerCircles = <Circle>{};
      final focusPoints = <LatLng>[];

      if (missionDoc != null) {
        final data = missionDoc.data() ?? <String, dynamic>{};
        final missionPos = _extractLatLng(data);

        if (missionPos != null) {
          focusPoints.add(missionPos);

          // Mission halo ring
          layerCircles.add(
            Circle(
              circleId: const CircleId('my_mission_halo'),
              center: missionPos,
              radius: 120,
              fillColor: const Color(0x206366F1),
              strokeColor: const Color(0xFF6366F1),
              strokeWidth: 2,
              zIndex: 2,
            ),
          );

          // Mission marker (Indigo ★)
          layerMarkers.add(
            Marker(
              markerId: const MarkerId('my_mission_target'),
              position: missionPos,
              icon: _myMissionMarkerIcon,
              zIndex: 5,
              onTap: () {
                _showReportBriefing(
                  reportId: missionDoc.id,
                  reportData: data,
                  position: missionPos,
                );
              },
            ),
          );

          // Auto-center map on first encounter of this mission
          if (_autoCenteredMissionId != missionDoc.id &&
              _mapController != null) {
            _autoCenteredMissionId = missionDoc.id;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final myLatLng = await _getCurrentLatLng();
              if (myLatLng != null) {
                _centerMapOnMission(myLatLng, missionPos);
              } else {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: missionPos, zoom: 15),
                  ),
                );
              }
            });
          }
        }
      }

      _docsInSnapshot = snapshot.docs.length;
      _docsWithCoordinates = focusPoints.length;
      _heatPointsCount = 0;

      return (
        markers: layerMarkers,
        heatmaps: <Heatmap>{},
        circles: layerCircles,
        focusPoints: focusPoints,
      );
    }

    // ── Standard layers ───────────────────────────────────────────────────
    final shouldRenderMarkers =
        _selectedCategory == _LayerCategory.medical ||
        _selectedCategory == _LayerCategory.food;
    final shouldRenderMarkerHalo = _selectedCategory == _LayerCategory.medical;
    final shouldRenderHeatmap =
        _selectedCategory == _LayerCategory.food ||
        _selectedCategory == _LayerCategory.airborne ||
        _selectedCategory == _LayerCategory.waterborne ||
        _selectedCategory == _LayerCategory.mentalHealth ||
        _selectedCategory == _LayerCategory.naturalDisaster;
    final shouldRenderHeatInteractions =
        _selectedCategory == _LayerCategory.airborne ||
        _selectedCategory == _LayerCategory.waterborne ||
        _selectedCategory == _LayerCategory.mentalHealth ||
        _selectedCategory == _LayerCategory.naturalDisaster;
    final selectedCategoryKey = _selectedCategory.firestoreCategoryKey;

    final heatPointsByUrgency = <String, List<WeightedLatLng>>{
      'critical': <WeightedLatLng>[],
      'high': <WeightedLatLng>[],
      'medium': <WeightedLatLng>[],
      'low': <WeightedLatLng>[],
    };
    final layerMarkers = <Marker>{};
    final layerCircles = <Circle>{};
    final focusPoints = <LatLng>[];
    var docsWithCoordinates = 0;

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final rawCategory = data['category'];
        final category = rawCategory == null
            ? ''
            : rawCategory.toString().trim().toLowerCase();
        if (category != selectedCategoryKey) {
          continue;
        }

        final position = _extractLatLng(data);
        if (position == null) {
          continue;
        }
        docsWithCoordinates++;
        focusPoints.add(position);

        if (shouldRenderHeatmap) {
          final urgencyScore = _extractUrgencyScore(data);
          final urgencyLevel = _resolveUrgencyLevel(data);
          final bucket =
              heatPointsByUrgency[urgencyLevel] ??
              heatPointsByUrgency['medium']!;
          bucket.addAll(
            _buildIrregularHeatCluster(
              center: position,
              urgencyScore: urgencyScore,
              seedKey: '${selectedCategoryKey}_${doc.id}',
            ),
          );

          if (shouldRenderHeatInteractions) {
            final tapRadiusMeters = 170 + (urgencyScore * 55);
            layerCircles.add(
              Circle(
                circleId: CircleId('heat_tap_${selectedCategoryKey}_${doc.id}'),
                center: position,
                radius: tapRadiusMeters,
                fillColor: const Color(0x05000000),
                strokeColor: Colors.transparent,
                strokeWidth: 0,
                zIndex: 0,
                consumeTapEvents: true,
                onTap: () {
                  _showReportBriefing(
                    reportId: doc.id,
                    reportData: data,
                    position: position,
                  );
                },
              ),
            );
          }
        }

        if (shouldRenderMarkers) {
          final markerId = MarkerId('${selectedCategoryKey}_${doc.id}');
          if (shouldRenderMarkerHalo) {
            final haloFill = _urgencyHaloFillColor(data);
            final haloStroke = _urgencyHaloStrokeColor(data);
            layerCircles.add(
              Circle(
                circleId: CircleId('halo_${selectedCategoryKey}_${doc.id}'),
                center: position,
                radius: 90,
                fillColor: haloFill,
                strokeColor: haloStroke,
                strokeWidth: 2,
                zIndex: 1,
              ),
            );
          }
          layerMarkers.add(
            Marker(
              markerId: markerId,
              position: position,
              icon:
                  ((data['assigned_volunteer_id'] as String?)?.trim() ?? '')
                      .isNotEmpty
                  ? _responderMarkerIcon
                  : _glowMarkerIcon,
              onTap: () {
                _showReportBriefing(
                  reportId: doc.id,
                  reportData: data,
                  position: position,
                );
              },
            ),
          );
        }
      } catch (error) {
        debugPrint('Skipping malformed report ${doc.id}: $error');
      }
    }

    final heatmaps = <Heatmap>{};
    if (shouldRenderHeatmap) {
      for (final entry in heatPointsByUrgency.entries) {
        if (entry.value.isEmpty) {
          continue;
        }
        heatmaps.add(
          Heatmap(
            heatmapId: _heatmapIdForUrgency(entry.key),
            data: entry.value,
            radius: _heatRadiusForUrgency(entry.key),
            opacity: 0.78,
            gradient: _heatGradientForLayer(
              category: _selectedCategory,
              urgencyLevel: entry.key,
            ),
          ),
        );
      }
    }

    _docsInSnapshot = snapshot.docs.length;
    _docsWithCoordinates = docsWithCoordinates;
    _heatPointsCount = heatPointsByUrgency.values.fold(
      0,
      (total, points) => total + points.length,
    );

    return (
      markers: layerMarkers,
      heatmaps: heatmaps,
      circles: layerCircles,
      focusPoints: focusPoints,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showLoader = _isPermissionLoading || _isMapInitializing;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: Navigator.canPop(context) && !widget.isVolunteer
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: _onMapCreated,
            onTap: (_) {
              _infoWindowController.hideInfoWindow!();
              if (_selectedMarkerPosition != null) {
                setState(() {
                  _selectedMarkerPosition = null;
                });
              }
            },
            onCameraMove: (_) => _infoWindowController.onCameraMove!(),
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _markers,
            heatmaps: _heatmaps,
            circles: _circles,
          ),
          CustomInfoWindow(
            controller: _infoWindowController,
            width: 250,
            height: 200,
            offset: 42,
          ),
          if (_missionDispatchAlert != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, -22 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: _MissionDispatchCard(
                    alert: _missionDispatchAlert!,
                    urgencyColor: _colorForUrgency(
                      _toDouble(
                            _missionDispatchAlert!.reportData['urgency_score'],
                          ) ??
                          _extractUrgencyScore(
                            _missionDispatchAlert!.reportData,
                          ),
                    ),
                    onViewOnMap: () {
                      final alert = _missionDispatchAlert;
                      if (alert == null) {
                        return;
                      }
                      _infoWindowController.hideInfoWindow!();
                      _mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(target: alert.position, zoom: 16),
                        ),
                      );
                      _showReportBriefing(
                        reportId: alert.reportId,
                        reportData: alert.reportData,
                        position: alert.position,
                      );
                    },
                  ),
                ),
              ),
            ),
          if (showLoader)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_permissionMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF202124).withValues(alpha: 0.9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _permissionMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (!_hasLocationPermission)
                        TextButton(
                          onPressed: Geolocator.openAppSettings,
                          child: const Text('Settings'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // ── Top Bar Elements ──────────
          if (widget.isVolunteer)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _buildVolunteerMissionBanner(),
              ),
            ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: widget.isVolunteer ? 74 : 16,
                    right: 16,
                  ),
                  child: _LayerControlButton(
                    selectedCategory: _selectedCategory,
                    onSelected: _onLayerChanged,
                    isVolunteer: widget.isVolunteer,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 24,
            child: !kIsWeb
                ? _LayerDebugChip(
                    category: _selectedCategory,
                    docsInSnapshot: _docsInSnapshot,
                    docsWithCoordinates: _docsWithCoordinates,
                    markersCount: _markers.length,
                    heatPointsCount: _heatPointsCount,
                  )
                : const SizedBox.shrink(),
          ),
          if (_selectedMarkerPosition != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 92,
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _openSelectedLocationInMaps,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 11,
                            horizontal: 11,
                          ),
                          backgroundColor: const Color(0xFF0F766E),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/open_maps.svg',
                              width: 31,
                              height: 31,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Open Maps',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _openDirectionsToSelectedLocation,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          backgroundColor: const Color(0xFF1D4ED8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/directions_maps.svg',
                              width: 29,
                              height: 29,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Directions',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_dispatchAlert != null)
            CommandCenterDispatchAlert(
              volunteerName: _dispatchAlert!.volunteerName,
              crisisType: _dispatchAlert!.crisisType,
              areaName: _dispatchAlert!.areaName,
              reportPosition: _dispatchAlert!.reportPosition,
              onViewOnMap: _onViewDispatchOnMap,
              onDismiss: _hideDispatchAlert,
            ),
        ],
      ),
    );
  }

  Widget _buildVolunteerMissionBanner() {
    final volunteer = ref.watch(currentVolunteerProvider).value;
    final hasMission =
        volunteer != null &&
        volunteer.currentMissionId != null &&
        volunteer.currentMissionId!.isNotEmpty;

    if (!hasMission) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xDD1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.radar_rounded,
                color: Color(0xFF38BDF8),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Scanning for missions…',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Transform.translate(
          offset: Offset(0, -16 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xEE1E1B4B), Color(0xEE312E81)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.25),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFFA5B4FC),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '★  MISSION ACTIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFEC4899),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap ★ marker to view details & navigate',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFE0E7FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_latestReportsSnapshot != null) {
                    final doc = _findActiveMissionDoc(
                      volunteer,
                      _latestReportsSnapshot!,
                    );
                    if (doc != null) {
                      final data = doc.data() ?? <String, dynamic>{};
                      final pos = _extractLatLng(data);
                      if (pos != null) {
                        _showReportBriefing(
                          reportId: doc.id,
                          reportData: data,
                          position: pos,
                        );
                      }
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'View',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

  Widget _buildVolunteerCategoryChips() {
    final categories = _LayerCategory.values;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => _onLayerChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.indicatorColor
                    : const Color(0xDD1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? cat.indicatorColor
                      : const Color(0xFF334155),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: cat.indicatorColor.withOpacity(0.35),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                cat.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _LayerCategory {
  myMission,
  medical,
  food,
  airborne,
  waterborne,
  mentalHealth,
  naturalDisaster,
}

extension _LayerCategoryPresentation on _LayerCategory {
  String get label {
    switch (this) {
      case _LayerCategory.myMission:
        return 'My Mission';
      case _LayerCategory.medical:
        return 'Medical';
      case _LayerCategory.food:
        return 'Food';
      case _LayerCategory.airborne:
        return 'Airborne';
      case _LayerCategory.waterborne:
        return 'Waterborne';
      case _LayerCategory.mentalHealth:
        return 'Mental Health';
      case _LayerCategory.naturalDisaster:
        return 'Natural Disaster';
    }
  }

  Color get indicatorColor {
    switch (this) {
      case _LayerCategory.myMission:
        return const Color(0xFFEC4899);
      case _LayerCategory.medical:
        return const Color(0xFFD32F2F);
      case _LayerCategory.food:
        return const Color(0xFF2E7D32);
      case _LayerCategory.airborne:
        return const Color(0xFFF57C00);
      case _LayerCategory.waterborne:
        return const Color(0xFF0288D1);
      case _LayerCategory.mentalHealth:
        return const Color(0xFF0D9488);
      case _LayerCategory.naturalDisaster:
        return const Color(0xFF0288D1);
    }
  }

  String get firestoreCategoryKey {
    switch (this) {
      case _LayerCategory.myMission:
        return 'my_mission';
      case _LayerCategory.medical:
        return 'medical';
      case _LayerCategory.food:
        return 'food_nutrition';
      case _LayerCategory.airborne:
        return 'airborne';
      case _LayerCategory.waterborne:
        return 'waterborne';
      case _LayerCategory.mentalHealth:
        return 'mentalhealth';
      case _LayerCategory.naturalDisaster:
        return 'natural_disaster';
    }
  }
}

class _LayerControlButton extends StatelessWidget {
  const _LayerControlButton({
    required this.selectedCategory,
    required this.onSelected,
    this.isVolunteer = false,
  });

  final _LayerCategory selectedCategory;
  final ValueChanged<_LayerCategory> onSelected;
  final bool isVolunteer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_LayerCategory>(
          value: selectedCategory,
          isDense: true,
          icon: const Padding(
            padding: EdgeInsets.only(left: 4.0),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
            ),
          ),
          elevation: 16,
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          onChanged: (newValue) {
            if (newValue != null) onSelected(newValue);
          },
          items: _LayerCategory.values
              .where((c) => isVolunteer || c != _LayerCategory.myMission)
              .map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: category.indicatorColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(category.label),
                    ],
                  ),
                );
              })
              .toList(),
        ),
      ),
    );
  }
}

class _LayerDebugChip extends StatelessWidget {
  const _LayerDebugChip({
    required this.category,
    required this.docsInSnapshot,
    required this.docsWithCoordinates,
    required this.markersCount,
    required this.heatPointsCount,
  });

  final _LayerCategory category;
  final int docsInSnapshot;
  final int docsWithCoordinates;
  final int markersCount;
  final int heatPointsCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0E1621).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x335B6B80)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          '${category.label} | docs:$docsInSnapshot coords:$docsWithCoordinates markers:$markersCount heat:$heatPointsCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MapIntelCard extends StatelessWidget {
  const _MapIntelCard({
    required this.crisisType,
    required this.urgencyScore,
    required this.imageUrl,
    required this.reportData,
    required this.assignedVolunteerName,
    required this.assignedVolunteerContact,
    required this.assignedVolunteerSpeciality,
    required this.onTap,
  });

  final String crisisType;
  final double urgencyScore;
  final String? imageUrl;
  final Map<String, dynamic> reportData;
  final String? assignedVolunteerName;
  final String? assignedVolunteerContact;
  final String? assignedVolunteerSpeciality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final accentColor = _briefingAccentColor(
      reportData['category']?.toString() ?? '',
    );
    final peopleAffected = reportData['peopleAffected'] ?? 0;

    // Time parsing
    String timeAgo = 'Just now';
    final dynamic createdRaw = reportData['createdAt'];
    if (createdRaw is Timestamp) {
      final diff = DateTime.now().difference(createdRaw.toDate());
      if (diff.inDays > 0) {
        timeAgo = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeAgo = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        timeAgo = '${diff.inMinutes}m ago';
      }
    }

    final urgencyColor = _colorForUrgency(urgencyScore);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isWeb ? 22 : 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isWeb ? 22 : 20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: isWeb ? 14 : 12,
              sigmaY: isWeb ? 14 : 12,
            ),
            child: Container(
              width: isWeb ? 420 : 250,
              decoration: BoxDecoration(
                gradient: isWeb
                    ? const LinearGradient(
                        colors: [Color(0xE70A111C), Color(0xE7172233)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isWeb ? null : const Color(0xFF0F141A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(isWeb ? 22 : 20),
                border: Border.all(
                  color: Colors.white.withOpacity(isWeb ? 0.16 : 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(isWeb ? 0.24 : 0.2),
                    blurRadius: isWeb ? 36 : 30,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: Container(color: urgencyColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeAgo,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      crisisType,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (peopleAffected > 0) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.people_alt_rounded,
                                            size: 14,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$peopleAffected affected',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                  color: const Color(0xFF1A1F26),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageUrl == null || imageUrl!.isEmpty
                                    ? const Center(
                                        child: Icon(
                                          Icons.satellite_alt_rounded,
                                          color: Colors.white38,
                                          size: 24,
                                        ),
                                      )
                                    : Image.network(
                                        imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                              child: Icon(
                                                Icons.broken_image_rounded,
                                                color: Colors.white38,
                                                size: 24,
                                              ),
                                            ),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if ((assignedVolunteerName ?? '').isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1B2A).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF16A34A,
                                          ).withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.verified_rounded,
                                          color: Color(0xFF86EFAC),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Responder Profile',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    assignedVolunteerName ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if ((assignedVolunteerSpeciality ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      assignedVolunteerSpeciality!,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if ((assignedVolunteerContact ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      assignedVolunteerContact!,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (assignedVolunteerName ?? '').isEmpty
                                  ? 'Tap to view report'
                                  : 'Tap to open response details',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _colorForUrgency(double score) {
    if (score >= 4.5) return const Color(0xFFD32F2F); // Red
    if (score >= 3.5) return const Color(0xFFF57C00); // Orange
    if (score >= 2.5) return const Color(0xFFFBC02D); // Yellow
    return const Color(0xFF388E3C); // Green
  }

  Color _briefingAccentColor(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('food')) return const Color(0xFFF9A825);
    if (normalized.contains('fire')) return const Color(0xFFFF5252);
    if (normalized.contains('medical')) return const Color(0xFF448AFF);
    if (normalized.contains('police')) return const Color(0xFF536DFE);
    if (normalized.contains('natural_disaster')) return const Color(0xFFFF9100);
    return const Color(0xFFE53935);
  }
}

class _MissionDispatchAlert {
  const _MissionDispatchAlert({
    required this.reportId,
    required this.reportData,
    required this.position,
    required this.volunteerName,
    required this.volunteerSpeciality,
    required this.crisisType,
  });

  final String reportId;
  final Map<String, dynamic> reportData;
  final LatLng position;
  final String volunteerName;
  final String volunteerSpeciality;
  final String crisisType;
}

class _MissionDispatchCard extends StatelessWidget {
  const _MissionDispatchCard({
    required this.alert,
    required this.urgencyColor,
    required this.onViewOnMap,
  });

  final _MissionDispatchAlert alert;
  final Color urgencyColor;
  final VoidCallback onViewOnMap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        return Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFF08111D), Color(0xFF121A28)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: urgencyColor.withOpacity(0.22),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        colors: [
                          urgencyColor.withOpacity(0.18),
                          Colors.transparent,
                          const Color(0xFF0D1622).withOpacity(0.35),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: isCompact
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: urgencyColor.withOpacity(0.16),
                                    border: Border.all(
                                      color: urgencyColor.withOpacity(0.36),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mission Dispatch',
                                        style: TextStyle(
                                          color: urgencyColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        alert.crisisType,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          height: 1.12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${alert.volunteerName} assigned',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: onViewOnMap,
                                style: FilledButton.styleFrom(
                                  backgroundColor: urgencyColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.near_me_rounded),
                                label: const Text(
                                  'View Location',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: urgencyColor.withOpacity(0.16),
                                border: Border.all(
                                  color: urgencyColor.withOpacity(0.36),
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Mission Dispatch',
                                    style: TextStyle(
                                      color: urgencyColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    alert.crisisType,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${alert.volunteerName} • ${alert.volunteerSpeciality}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: onViewOnMap,
                              style: FilledButton.styleFrom(
                                backgroundColor: urgencyColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.near_me_rounded),
                              label: const Text(
                                'View Location',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
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
  }
}

class CommandCenterDispatchData {
  const CommandCenterDispatchData({
    required this.volunteerName,
    required this.crisisType,
    required this.areaName,
    required this.reportPosition,
  });

  final String volunteerName;
  final String crisisType;
  final String areaName;
  final LatLng reportPosition;
}

class CommandCenterDispatchAlert extends StatefulWidget {
  const CommandCenterDispatchAlert({
    super.key,
    required this.volunteerName,
    required this.crisisType,
    required this.areaName,
    required this.reportPosition,
    required this.onViewOnMap,
    required this.onDismiss,
  });

  final String volunteerName;
  final String crisisType;
  final String areaName;
  final LatLng reportPosition;
  final VoidCallback onViewOnMap;
  final VoidCallback onDismiss;

  @override
  State<CommandCenterDispatchAlert> createState() =>
      _CommandCenterDispatchAlertState();
}

class _CommandCenterDispatchAlertState extends State<CommandCenterDispatchAlert>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);
    _startAutoDismissTimer();
  }

  void _startAutoDismissTimer() {
    _dismissTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Active Mission badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF34C759),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Active Mission',
                                  style: TextStyle(
                                    color: Color(0xFF34C759),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                color: Color(0xFF8E8E93),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      const Text(
                        'Smart Allocation Successful',
                        style: TextStyle(
                          color: Color(0xFF1C1C1E),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Body content
                      Text(
                        '${widget.volunteerName} has been dispatched for ${widget.crisisType} in ${widget.areaName}.',
                        style: const TextStyle(
                          color: Color(0xFF3C3C43),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            _dismiss();
                            widget.onViewOnMap();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.location_searching, size: 18),
                          label: const Text(
                            'VIEW ON MAP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
