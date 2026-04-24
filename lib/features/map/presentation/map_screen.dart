import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/firestore/firestore_paths.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapPage();
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
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
  _LayerCategory _selectedCategory = _LayerCategory.medical;

  bool _isMapInitializing = true;
  bool _isPermissionLoading = true;
  bool _hasLocationPermission = false;
  String? _permissionMessage;
  LatLng? _selectedMarkerPosition;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveLocationPermission());
    unawaited(_loadGlowPinIcon());
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

    unawaited(_focusCameraOnData(layers.focusPoints));

    print('Mapped ${layers.markers.length} markers');
    print(
      'Layer=${_selectedCategory.name}, docs=$_docsInSnapshot, '
      'coords=$_docsWithCoordinates, heatPoints=$_heatPointsCount',
    );
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

  Future<void> _loadGlowPinIcon() async {
    try {
      final icon = await _buildCreativePinIcon();
      if (!mounted) {
        return;
      }
      setState(() {
        _glowMarkerIcon = icon;
      });
      if (_latestReportsSnapshot != null) {
        _onReportsSnapshot(_latestReportsSnapshot!);
      }
    } catch (_) {
      // Keep default marker when custom asset is unavailable.
    }
  }

  Future<BitmapDescriptor> _buildCreativePinIcon() async {
    const markerSize = 126.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(markerSize / 2, markerSize / 2);

    final glowPaint = Paint()..color = const Color(0x66FF1744);
    final pulsePaint = Paint()..color = const Color(0x88FF5252);
    final corePaint = Paint()..color = const Color(0xFFE53935);
    final innerPaint = Paint()..color = Colors.white;

    canvas.drawCircle(center, 52, glowPaint);
    canvas.drawCircle(center, 38, pulsePaint);
    canvas.drawCircle(center, 22, corePaint);
    canvas.drawCircle(center, 10, innerPaint);

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, 28, ringPaint);

    final pointerPath = Path()
      ..moveTo(center.dx, markerSize - 8)
      ..lineTo(center.dx - 11, markerSize - 34)
      ..lineTo(center.dx + 11, markerSize - 34)
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

    if (!mounted) {
      return;
    }
    setState(() {
      _isMapInitializing = false;
    });
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

    if (category == _LayerCategory.waterborne) {
      // Waterborne palette: bright cyan with deep navy for high-risk zones.
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

    _infoWindowController.addInfoWindow!(
      _MedicalBriefingCard(
        crisisType: crisisType,
        urgencyScore: urgencyScore,
        imageUrl: imageUrl,
        onTap: () {
          _infoWindowController.hideInfoWindow!();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ReportDetailsPage(reportId: reportId, reportData: reportData),
            ),
          );
        },
      ),
      position,
    );

    setState(() {
      _selectedMarkerPosition = position;
    });
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
    final shouldRenderMarkers =
        _selectedCategory == _LayerCategory.medical ||
        _selectedCategory == _LayerCategory.food;
    final shouldRenderMarkerHalo = _selectedCategory == _LayerCategory.medical;
    final shouldRenderHeatmap =
        _selectedCategory == _LayerCategory.food ||
        _selectedCategory == _LayerCategory.airborne ||
        _selectedCategory == _LayerCategory.waterborne;
    final shouldRenderHeatInteractions =
        _selectedCategory == _LayerCategory.airborne ||
        _selectedCategory == _LayerCategory.waterborne;
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
              icon: _glowMarkerIcon,
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

    return Stack(
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
          myLocationButtonEnabled: _hasLocationPermission,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          markers: _markers,
          heatmaps: _heatmaps,
          circles: _circles,
        ),
        CustomInfoWindow(
          controller: _infoWindowController,
          width: 320,
          height: 122,
          offset: 42,
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
        Positioned(
          top: 16,
          right: 16,
          child: _LayerControlButton(
            selectedCategory: _selectedCategory,
            onSelected: _onLayerChanged,
          ),
        ),
        Positioned(
          left: 16,
          bottom: 24,
          child: _LayerDebugChip(
            category: _selectedCategory,
            docsInSnapshot: _docsInSnapshot,
            docsWithCoordinates: _docsWithCoordinates,
            markersCount: _markers.length,
            heatPointsCount: _heatPointsCount,
          ),
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
      ],
    );
  }
}

enum _LayerCategory { medical, food, airborne, waterborne }

extension _LayerCategoryPresentation on _LayerCategory {
  String get label {
    switch (this) {
      case _LayerCategory.medical:
        return 'Medical';
      case _LayerCategory.food:
        return 'Food';
      case _LayerCategory.airborne:
        return 'Airborne';
      case _LayerCategory.waterborne:
        return 'Waterborne';
    }
  }

  Color get indicatorColor {
    switch (this) {
      case _LayerCategory.medical:
        return const Color(0xFFD32F2F);
      case _LayerCategory.food:
        return const Color(0xFF2E7D32);
      case _LayerCategory.airborne:
        return const Color(0xFFF57C00);
      case _LayerCategory.waterborne:
        return const Color(0xFF0288D1);
    }
  }

  String get firestoreCategoryKey {
    switch (this) {
      case _LayerCategory.medical:
        return 'medical';
      case _LayerCategory.food:
        return 'food_nutrition';
      case _LayerCategory.airborne:
        return 'airborne';
      case _LayerCategory.waterborne:
        return 'waterborne';
    }
  }
}

class _LayerControlButton extends StatelessWidget {
  const _LayerControlButton({
    required this.selectedCategory,
    required this.onSelected,
  });

  final _LayerCategory selectedCategory;
  final ValueChanged<_LayerCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF10161F).withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(14),
      child: PopupMenuButton<_LayerCategory>(
        onSelected: onSelected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        offset: const Offset(0, 44),
        itemBuilder: (context) {
          return _LayerCategory.values
              .map(
                (category) => PopupMenuItem<_LayerCategory>(
                  value: category,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: category.indicatorColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(category.label),
                    ],
                  ),
                ),
              )
              .toList();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: selectedCategory.indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                selectedCategory.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
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

class _MedicalBriefingCard extends StatelessWidget {
  const _MedicalBriefingCard({
    required this.crisisType,
    required this.urgencyScore,
    required this.imageUrl,
    required this.onTap,
  });

  final String crisisType;
  final double urgencyScore;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = _briefingAccentColor(crisisType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111318),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x29000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 104,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Intel Briefing',
                      style: TextStyle(
                        color: accentColor.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      crisisType,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Risk: ',
                            style: TextStyle(
                              color: Color(0xFFE7E7E7),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: '${urgencyScore.toStringAsFixed(1)}/10',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to view full intel ➔',
                      style: TextStyle(
                        color: Color(0xFF9C9C9C),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: imageUrl == null || imageUrl!.isEmpty
                      ? Container(
                          color: const Color(0xFF2A2A2A),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 20,
                            color: Color(0xFFBDBDBD),
                          ),
                        )
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF2A2A2A),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 20,
                                color: Color(0xFFBDBDBD),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return Container(
                              color: const Color(0xFF2A2A2A),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  Color _briefingAccentColor(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('food')) {
      return const Color(0xFFF9A825);
    }
    return const Color(0xFFD32F2F);
  }
}

class ReportDetailsPage extends StatelessWidget {
  const ReportDetailsPage({
    super.key,
    required this.reportId,
    required this.reportData,
  });

  final String reportId;
  final Map<String, dynamic> reportData;

  @override
  Widget build(BuildContext context) {
    final category = _categoryKey;
    final categoryLabel = _categoryLabel(category);
    final accentColor = _categoryAccentColor(category);
    final status = _statusLabel;
    final statusColor = _statusColor;
    final createdAt =
        _extractDateTime(reportData['createdAt']) ??
        _extractDateTime(reportData['updatedAt']) ??
        DateTime.now();
    final imageUrl = _resolveImageUrl();
    final description = _readText([
      'description',
      'report',
      'details',
    ], fallback: 'No field description was provided.');
    final coordinates = _coordinatesText;
    final riskScore = _riskScore;
    final supplyLine = _supplyLine;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Intel Briefing',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              backgroundColor: statusColor,
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemBuilder: (context, index) {
          final sections = <Widget>[
            _IntelHeroCard(
              categoryLabel: categoryLabel,
              accentColor: accentColor,
              createdAt: createdAt,
              status: status,
              statusColor: statusColor,
              imageUrl: imageUrl,
              heroTag: 'report-image-$reportId',
              onOpenFullScreen: imageUrl == null || imageUrl.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _ReportImageViewerPage(
                            imageUrl: imageUrl,
                            heroTag: 'report-image-$reportId',
                          ),
                        ),
                      );
                    },
            ),
            _IntelSectionCard(
              title: 'Field Report',
              accentColor: accentColor,
              child: Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF243447),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            _IntelSectionCard(
              title: 'AI Analysis',
              accentColor: accentColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KeyValuePill(
                    label: 'Category',
                    value: categoryLabel,
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 10),
                  _KeyValuePill(
                    label: 'Risk',
                    value: '${riskScore.toStringAsFixed(1)}/10',
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 10),
                  _KeyValuePill(
                    label: 'Specific Needs',
                    value: supplyLine,
                    accentColor: accentColor,
                  ),
                ],
              ),
            ),
            _IntelSectionCard(
              title: 'Geospatial',
              accentColor: accentColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coordinates ?? 'Coordinates unavailable',
                    style: const TextStyle(
                      color: Color(0xFF243447),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: coordinates == null
                          ? null
                          : () => _launchMaps(coordinates),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Navigate in Maps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _IntelSectionCard(
              title: 'NGO Synergy',
              accentColor: accentColor,
              child: const Column(
                children: [
                  _IntelligenceRow(
                    label: 'Assigned Volunteer',
                    value: 'Pending assignment',
                  ),
                  SizedBox(height: 10),
                  _IntelligenceRow(
                    label: 'Estimated Response Time',
                    value: 'To be calculated',
                  ),
                ],
              ),
            ),
          ];
          return sections[index];
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: 5,
      ),
    );
  }

  String get _categoryKey {
    return (reportData['category'] as String?)?.trim().toLowerCase() ??
        'general';
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'medical':
        return 'Medical';
      case 'food_nutrition':
        return 'Food';
      default:
        if (category.isEmpty) {
          return 'General';
        }
        return category
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (part) => part.isEmpty
                  ? part
                  : '${part[0].toUpperCase()}${part.substring(1)}',
            )
            .join(' ');
    }
  }

  Color _categoryAccentColor(String category) {
    switch (category) {
      case 'medical':
        return const Color(0xFFD32F2F);
      case 'food_nutrition':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2563EB);
    }
  }

  DateTime? _extractDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  String? _resolveImageUrl() {
    final candidates = [
      reportData['image_url'],
      reportData['imageUrl'],
      reportData['secure_url'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  String _readText(List<String> keys, {required String fallback}) {
    for (final key in keys) {
      final candidate = reportData[key];
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return fallback;
  }

  String get _statusLabel {
    final raw = (reportData['status'] as String?)?.trim();
    if (raw == null || raw.isEmpty) {
      return 'AWAITING DISPATCH';
    }
    return raw.toUpperCase();
  }

  Color get _statusColor {
    final raw = (reportData['status'] as String?)?.trim().toLowerCase() ?? '';
    switch (raw) {
      case 'open':
        return const Color(0xFFB45309);
      case 'in progress':
      case 'assigned':
        return const Color(0xFF0F766E);
      case 'resolved':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF374151);
    }
  }

  double get _riskScore {
    final raw = reportData['urgency_score'];
    if (raw is num) {
      return raw.toDouble();
    }
    final urgency =
        (reportData['urgency'] as String?)?.trim().toLowerCase() ?? '';
    switch (urgency) {
      case 'critical':
        return 10.0;
      case 'high':
        return 8.5;
      case 'medium':
      case 'normal':
        return 5.0;
      case 'low':
        return 2.5;
      default:
        return 1.0;
    }
  }

  String get _coordinatesText {
    final latitude = reportData['latitude'];
    final longitude = reportData['longitude'];
    if (latitude is num && longitude is num) {
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    }

    final location = reportData['location'];
    if (location is String) {
      final text = location.trim();
      if (text.contains('·')) {
        return text.split('·').last.trim();
      }
      if (text.contains(',')) {
        return text;
      }
    }

    final coordinates = reportData['coordinates'];
    if (coordinates is GeoPoint) {
      return '${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}';
    }
    if (coordinates is Map<String, dynamic>) {
      final lat = coordinates['latitude'] ?? coordinates['lat'];
      final lng = coordinates['longitude'] ?? coordinates['lng'];
      if (lat is num && lng is num) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
    }

    return 'Coordinates unavailable';
  }

  String get _supplyLine {
    final category = _categoryKey;
    final subcategory = _readText([
      'subcategory',
      'crisis_type',
      'title',
    ], fallback: 'Immediate review required');
    final peopleAffected = reportData['peopleAffected'];
    final peopleText = peopleAffected is num
        ? '${peopleAffected.toInt()} Patients'
        : '';

    final supplies = <String>[];
    switch (category) {
      case 'medical':
        supplies.add('Antibiotics');
        supplies.add('First Aid');
        break;
      case 'food_nutrition':
        supplies.add('Food Packs');
        supplies.add('Nutritional Support');
        break;
      default:
        supplies.add('Field Assessment');
    }

    return [
      'Supplies: ${supplies.join(', ')}',
      if (peopleText.isNotEmpty) peopleText,
      subcategory,
    ].join(' • ');
  }

  Future<void> _launchMaps(String coordinateText) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(coordinateText)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _IntelHeroCard extends StatelessWidget {
  const _IntelHeroCard({
    required this.categoryLabel,
    required this.accentColor,
    required this.createdAt,
    required this.status,
    required this.statusColor,
    required this.imageUrl,
    required this.heroTag,
    required this.onOpenFullScreen,
  });

  final String categoryLabel;
  final Color accentColor;
  final DateTime createdAt;
  final String status;
  final Color statusColor;
  final String? imageUrl;
  final String heroTag;
  final VoidCallback? onOpenFullScreen;

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat(
      'EEEE, MMM d, yyyy • hh:mm a',
    ).format(createdAt.toLocal());

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryLabel.toUpperCase(),
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Strategic Intelligence Report',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeText,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  backgroundColor: statusColor,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: Colors.black,
                  child: InkWell(
                    onTap: onOpenFullScreen,
                    child: Hero(
                      tag: heroTag,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFFF3F4F6),
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFF3F4F6),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 36,
                                color: Color(0xFF9CA3AF),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenFullScreen,
                icon: const Icon(Icons.open_in_full_rounded),
                label: const Text('Full Screen View'),
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntelSectionCard extends StatelessWidget {
  const _IntelSectionCard({
    required this.title,
    required this.accentColor,
    required this.child,
  });

  final String title;
  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.15,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValuePill extends StatelessWidget {
  const _KeyValuePill({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelligenceRow extends StatelessWidget {
  const _IntelligenceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ReportImageViewerPage extends StatelessWidget {
  const _ReportImageViewerPage({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Full Evidence View'),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 48,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
