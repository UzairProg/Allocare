import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  static const _heatmapId = HeatmapId('allocare_needs_density');
  static const HeatmapGradient _riskGradient = HeatmapGradient(
    [
      HeatmapGradientColor(Color(0xFFFFF176), 0.15),
      HeatmapGradientColor(Color(0xFFFFB300), 0.55),
      HeatmapGradientColor(Color(0xFFD32F2F), 1.0),
    ],
  );

  GoogleMapController? _mapController;
  final CustomInfoWindowController _infoWindowController =
      CustomInfoWindowController();
  final Stream<QuerySnapshot<Map<String, dynamic>>> _needsStream =
      FirebaseFirestore.instance
          .collection(FirestorePaths.needs)
          .snapshots();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _needsSubscription;
  QuerySnapshot<Map<String, dynamic>>? _latestNeedsSnapshot;
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

  @override
  void initState() {
    super.initState();
    unawaited(_resolveLocationPermission());
    unawaited(_loadGlowPinIcon());
    _needsSubscription = _needsStream.listen(
      _onNeedsSnapshot,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Needs stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _needsSubscription?.cancel();
    _infoWindowController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onNeedsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _latestNeedsSnapshot = snapshot;
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

    if (_latestNeedsSnapshot != null) {
      _onNeedsSnapshot(_latestNeedsSnapshot!);
    }
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
      if (_latestNeedsSnapshot != null) {
        _onNeedsSnapshot(_latestNeedsSnapshot!);
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

    final image = await recorder
        .endRecording()
        .toImage(markerSize.toInt(), markerSize.toInt());
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

      _hasLocationPermission = permission == LocationPermission.always ||
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
      final coordinateSegment = text.contains('·') ? text.split('·').last.trim() : text;
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
      final longitude = _toDouble(coordinates['longitude'] ?? coordinates['lng']);
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

  String _readDisplayValue(Map<String, dynamic> data, List<String> keys, String fallback) {
    for (final key in keys) {
      final dynamic raw = data[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    }
    return fallback;
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
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  ({Set<Marker> markers, Set<Heatmap> heatmaps, Set<Circle> circles, List<LatLng> focusPoints}) _buildMapLayers(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final shouldRenderMarkers = _selectedCategory == _LayerCategory.medical ||
        _selectedCategory == _LayerCategory.food;
    final shouldRenderHeatmap = _selectedCategory == _LayerCategory.food ||
        _selectedCategory == _LayerCategory.airborne ||
        _selectedCategory == _LayerCategory.waterborne;
    final selectedCategoryKey = _selectedCategory.firestoreCategoryKey;

    final weightedPoints = <WeightedLatLng>[];
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
          weightedPoints.add(
            WeightedLatLng(
              position,
              weight: _extractUrgencyScore(data),
            ),
          );
        }

        if (shouldRenderMarkers) {
          final markerId = MarkerId('${selectedCategoryKey}_${doc.id}');
          layerCircles.add(
            Circle(
              circleId: CircleId('halo_${selectedCategoryKey}_${doc.id}'),
              center: position,
              radius: 90,
              fillColor: const Color(0x66FF5252),
              strokeColor: const Color(0xFFFF1744),
              strokeWidth: 2,
              zIndex: 1,
            ),
          );
          layerMarkers.add(
            Marker(
              markerId: markerId,
              position: position,
              icon: _glowMarkerIcon,
              onTap: () {
                final crisisType = _readDisplayValue(
                  data,
                  const ['crisis_type', 'subcategory', 'title'],
                  'Acute Waterborne Risk',
                );
                final status = _readDisplayValue(
                  data,
                  const ['status', 'dispatch_status'],
                  'Awaiting Dispatch',
                );

                _infoWindowController.addInfoWindow!(
                  _EmergencyInfoCard(
                    crisisType: crisisType,
                    status: status,
                    onViewDetails: () {
                      _infoWindowController.hideInfoWindow!();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReportDetailsPage(
                            reportId: doc.id,
                            reportData: data,
                          ),
                        ),
                      );
                    },
                  ),
                  position,
                );
              },
            ),
          );
        }
      } catch (error) {
        debugPrint('Skipping malformed need ${doc.id}: $error');
      }
    }

    final heatmaps = <Heatmap>{};
    if (shouldRenderHeatmap && weightedPoints.isNotEmpty) {
      heatmaps.add(
        Heatmap(
          heatmapId: _heatmapId,
          data: weightedPoints,
          radius: const HeatmapRadius.fromPixels(36),
          opacity: 0.72,
          gradient: _riskGradient,
        ),
      );
    }

    _docsInSnapshot = snapshot.docs.length;
    _docsWithCoordinates = docsWithCoordinates;
    _heatPointsCount = weightedPoints.length;

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
          onTap: (_) => _infoWindowController.hideInfoWindow!(),
          onCameraMove: (_) => _infoWindowController.onCameraMove!(),
          myLocationEnabled: _hasLocationPermission,
          myLocationButtonEnabled: _hasLocationPermission,
          zoomControlsEnabled: true,
          markers: _markers,
          heatmaps: _heatmaps,
          circles: _circles,
        ),
        CustomInfoWindow(
          controller: _infoWindowController,
          width: 300,
          height: 152,
          offset: 42,
        ),
        if (showLoader)
          const ColoredBox(
            color: Color(0x33000000),
            child: Center(
              child: CircularProgressIndicator(),
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 18),
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
      ],
    );
  }
}

enum _LayerCategory {
  medical,
  food,
  airborne,
  waterborne,
}

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

class _EmergencyInfoCard extends StatelessWidget {
  const _EmergencyInfoCard({
    required this.crisisType,
    required this.status,
    required this.onViewDetails,
  });

  final String crisisType;
  final String status;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121A25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2F3D4F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crisis Type: $crisisType',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'Status: $status',
            style: const TextStyle(
              color: Color(0xFFB7C5D6),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: onViewDetails,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
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
    final entries = reportData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: Text('Report $reportId'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            title: Text(entry.key),
            subtitle: Text('${entry.value}'),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: entries.length,
      ),
    );
  }
}
