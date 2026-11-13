import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/campus_map_bounds.dart';
import '../data/campus_repository.dart';
import '../map/campus_layers.dart';
import '../models/campus_building.dart';
import '../services/campus_router.dart';
import '../services/location_service.dart';
import '../widgets/building_card.dart';
import '../widgets/campus_search.dart';
import '../widgets/colours.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/route_panel.dart';
import 'about_screen.dart';

enum _Mode { browse, routes, navigating }

/// CDU Casuarina campus map with building search and walking directions.
class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  static const double _campusZoom = 16.2;

  final LocationService _locationService = LocationService();
  final CampusRepository _campus = CampusRepository();
  late final Future<void> _campusLoaded = _campus.load();
  CampusRouter? _router;

  MapLibreMapController? _map;
  CampusLayers? _layers;
  StreamSubscription<Position>? _positionSubscription;

  bool _layersReady = false;
  String? _mapError;

  // Location
  bool _locating = true;
  LocationProblem? _locationProblem;
  Position? _position;

  // Selection and directions
  _Mode _mode = _Mode.browse;
  CampusBuilding? _selected;
  CampusBuilding? _fromBuilding; // null = start from my location
  List<WalkRoute> _routes = [];
  int _routeIndex = 0;
  String? _routeError;

  // Navigation
  double _remaining = 0;
  bool _arrived = false;
  bool _rerouting = false;
  int _offRouteCount = 0;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _campusLoaded.then((_) => _router = CampusRouter(_campus.walkGraph!));
    _startLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  Future<void> _startLocation() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    setState(() {
      _locating = true;
      _locationProblem = null;
    });

    try {
      final position = await _locationService.determinePosition();
      if (!mounted) return;
      setState(() {
        _position = position;
        _locating = false;
      });
      _afterNewPosition();
      _positionSubscription = _locationService.positionStream().listen(
        _onPosition,
        onError: (Object _) {
          if (!mounted) return;
          setState(() => _locationProblem = LocationProblem.serviceDisabled);
        },
      );
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationProblem = e.problem;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationProblem = LocationProblem.serviceDisabled;
      });
    }
  }

  bool get _hasLocation => _position != null && _locationProblem == null;

  LatLng? get _here =>
      _position == null ? null : LatLng(_position!.latitude, _position!.longitude);

  bool get _onCampus => _here != null && CampusMapBounds.contains(_here!);

  Future<void> _fixLocationProblem() async {
    // A website cannot open the phone's settings; it can only ask again.
    if (kIsWeb) return _startLocation();
    switch (_locationProblem) {
      case LocationProblem.serviceDisabled:
        await _locationService.openLocationSettings();
      case LocationProblem.permissionDeniedForever:
        await _locationService.openAppSettings();
      case LocationProblem.permissionDenied:
      case null:
        break;
    }
    await _startLocation();
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    // Skip rough readings that would pull the dot away from a recent good fix.
    if (!shouldUsePosition(_position, p)) return;
    setState(() => _position = p);
    _afterNewPosition();
    if (_mode == _Mode.navigating) _updateNavigation();
    // Keep the user in the middle while following. (Phones follow natively
    // during navigation, so the camera is only moved here otherwise.)
    final nativeNav = _mode == _Mode.navigating && !kIsWeb;
    if (_followMe && !nativeNav && _here != null) {
      _followTo(_here!);
    }
  }

  /// Whether the map has already jumped to the user's first on-campus position.
  bool _centredOnMe = false;

  /// Draws the web location dot and, once, centres the map on the user.
  void _afterNewPosition() {
    if (!_layersReady || _here == null) return;
    if (kIsWeb) {
      _layers?.showMyLocation(_here, _position?.accuracy ?? 10);
    }
    if (!_centredOnMe && _onCampus && _selected == null && _mode == _Mode.browse) {
      _centredOnMe = true;
      _followMe = true;
      _moveCameraTo(_here!, zoom: 17.3);
    }
  }

  // ---------------------------------------------------------------------------
  // Map
  // ---------------------------------------------------------------------------

  void _onMapCreated(MapLibreMapController c) {
    _map = c;
    _layers = CampusLayers(c);
  }

  Future<void> _onStyleLoaded() async {
    try {
      await _campusLoaded;
      await _layers!.addAll(_campus);
      if (!mounted) return;
      setState(() => _layersReady = true);
      _afterNewPosition();
    } catch (e) {
      if (!mounted) return;
      setState(() => _mapError = 'Could not draw the campus: $e');
    }
  }

  Future<void> _onMapClick(math.Point<double> point, LatLng latLng) async {
    final c = _map;
    if (c == null || !_layersReady || _mode == _Mode.navigating) return;

    if (_mode == _Mode.routes) {
      final hits = await c.queryRenderedFeatures(point, [CampusLayers.routeAltLayer], null);
      if (hits.isNotEmpty) {
        final idx = ((hits.first as Map)['properties'] as Map)['idx'];
        if (idx is num) await _selectRoute(idx.toInt());
      }
      return;
    }

    final hits = await c.queryRenderedFeatures(point, [CampusLayers.buildingsLayer], null);
    if (hits.isEmpty) {
      await _clearSelection();
      return;
    }
    final id = ((hits.first as Map)['properties'] as Map)['id'];
    final b = _campus.buildings[id];
    if (b != null) await _selectBuilding(b);
  }

  // ---------------------------------------------------------------------------
  // Building selection
  // ---------------------------------------------------------------------------

  Future<void> _selectBuilding(CampusBuilding b) async {
    setState(() {
      _selected = b;
      _mode = _Mode.browse;
    });
    await _layers?.clearRoutes();
    await _layers?.highlight(b.id);
    final zoom = math.max(_map?.cameraPosition?.zoom ?? 17, 17.3);
    await _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: b.centre,
      zoom: zoom,
      tilt: 0,
      bearing: _map?.cameraPosition?.bearing ?? 0,
    )));
  }

  Future<void> _clearSelection() async {
    setState(() {
      _selected = null;
      _mode = _Mode.browse;
      _routes = [];
      _routeError = null;
    });
    await _layers?.highlight(null);
    await _layers?.clearRoutes();
  }

  Future<void> _openSearch() async {
    await _campusLoaded;
    if (!mounted) return;
    final b = await showSearch<CampusBuilding?>(
      context: context,
      delegate: CampusSearchDelegate(_campus),
    );
    if (b != null) await _selectBuilding(b);
  }

  // ---------------------------------------------------------------------------
  // Directions
  // ---------------------------------------------------------------------------

  LatLng? get _routeStart {
    if (_fromBuilding != null) {
      return _campus.walkGraph!.access[_fromBuilding!.id]?.first.door ??
          _fromBuilding!.centre;
    }
    return _hasLocation ? _here : null;
  }

  String get _fromLabel => _fromBuilding?.title ?? 'Your location';

  Future<void> _openDirections() async {
    setState(() {
      _mode = _Mode.routes;
      _routes = [];
      _routeIndex = 0;
      _routeError = null;
    });
    await _computeRoutes();
  }

  Future<void> _computeRoutes() async {
    await _campusLoaded;
    final target = _selected;
    final from = _routeStart;
    if (target == null) return;
    if (from == null) {
      setState(() => _routeError = _locating
          ? 'Finding your location… or choose a starting building above.'
          : 'Your location is not available. Choose a starting building above.');
      return;
    }
    try {
      final routes = _router!.routes(from, target.id);
      setState(() {
        _routes = routes;
        _routeIndex = 0;
        _routeError = null;
      });
      await _drawRoutes();
      await _fitRoutes();
    } on RouteException catch (e) {
      setState(() {
        _routes = [];
        _routeError = '${e.message} You can choose a starting building above.';
      });
      await _layers?.clearRoutes();
    }
  }

  Future<void> _drawRoutes() =>
      _layers!.showRoutes(_routes, _routeIndex, from: _routeStart);

  Future<void> _selectRoute(int i) async {
    setState(() => _routeIndex = i);
    await _drawRoutes();
  }

  Future<void> _fitRoutes() async {
    final pts = [for (final r in _routes) ...r.points, ?_routeStart];
    if (pts.isEmpty) return;
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
    }
    await _map?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)),
      left: 50,
      top: 150,
      right: 70,
      bottom: 380,
    ));
  }

  Future<void> _changeStart() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Your location'),
              subtitle: Text(_hasLocation
                  ? (_onCampus ? 'On campus' : 'Not on campus right now')
                  : 'Location not available'),
              onTap: () => Navigator.pop(context, 'me'),
            ),
            ListTile(
              leading: const Icon(Icons.apartment),
              title: const Text('Choose a building…'),
              onTap: () => Navigator.pop(context, 'building'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'me') {
      setState(() => _fromBuilding = null);
    } else {
      final b = await showSearch<CampusBuilding?>(
        context: context,
        delegate: CampusSearchDelegate(_campus),
      );
      if (b == null) return;
      setState(() => _fromBuilding = b);
    }
    setState(() => _routes = []);
    await _computeRoutes();
  }

  bool get _canStart =>
      _routes.isNotEmpty && _fromBuilding == null && _hasLocation && _onCampus;

  String? get _startHint {
    if (_fromBuilding != null) return 'Live directions start from your location.';
    if (!_hasLocation) return 'Live directions need your location.';
    if (!_onCampus) return 'Live directions work on campus.';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Live navigation
  // ---------------------------------------------------------------------------

  Future<void> _startNavigation() async {
    setState(() {
      _mode = _Mode.navigating;
      _arrived = false;
      _rerouting = false;
      _offRouteCount = 0;
      _remaining = _routes[_routeIndex].distance;
      // keep only the chosen route on the map
      _routes = [_routes[_routeIndex]];
      _routeIndex = 0;
    });
    await _drawRoutes();
    await _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: _here!,
      zoom: 18.3,
      tilt: 0,
      bearing: _position?.heading ?? 0,
    )));
    if (!kIsWeb) {
      await _map?.updateMyLocationTrackingMode(MyLocationTrackingMode.trackingCompass);
    } else {
      setState(() => _followMe = true);
      _lastCameraTarget = _here;
    }
    _updateNavigation();
  }

  void _updateNavigation() {
    final here = _here;
    if (here == null || _routes.isEmpty || _arrived) return;
    final route = _routes.first;
    final prog = CampusRouter.progress(route, here);
    final toDoor = _distance(here, route.door);

    if (prog.remaining < 15 || toDoor < 18) {
      setState(() {
        _arrived = true;
        _remaining = 0;
      });
      return;
    }

    final tolerance = math.max(25.0, (_position?.accuracy ?? 0) * 1.2);
    _offRouteCount = prog.offRoute > tolerance ? _offRouteCount + 1 : 0;
    setState(() => _remaining = prog.remaining + prog.offRoute);

    final now = DateTime.now();
    if (_offRouteCount >= 2 && now.difference(_lastReroute).inSeconds > 10) {
      _lastReroute = now;
      _reroute(here);
    }
  }

  Future<void> _reroute(LatLng here) async {
    final target = _selected;
    if (target == null) return;
    setState(() => _rerouting = true);
    try {
      final r = _router!.routes(here, target.id, maxRoutes: 1);
      if (!mounted || _mode != _Mode.navigating) return;
      setState(() {
        _routes = r;
        _routeIndex = 0;
        _offRouteCount = 0;
        _remaining = r.first.distance;
      });
      await _drawRoutes();
    } on RouteException catch (_) {
      // keep the old route; the walker may be briefly off the network
    } finally {
      if (mounted) setState(() => _rerouting = false);
    }
  }

  Future<void> _endNavigation() async {
    if (!kIsWeb) {
      await _map?.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
    }
    final b = _selected;
    await _clearSelection();
    if (b != null) await _selectBuilding(b);
  }

  static double _distance(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  // ---------------------------------------------------------------------------
  // Camera buttons
  // ---------------------------------------------------------------------------

  Future<void> _showWholeCampus() async {
    await _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: CampusMapBounds.centre,
      zoom: _campusZoom,
    )));
  }

  Future<void> _goToMyLocation() async {
    if (!_hasLocation) {
      if (_locationProblem != null) {
        await _fixLocationProblem();
      } else {
        _showMessage('Still finding your location…');
      }
      return;
    }
    if (_mode == _Mode.navigating && !kIsWeb) {
      await _map?.updateMyLocationTrackingMode(MyLocationTrackingMode.trackingCompass);
      return;
    }

    // Start following straight away with the last fix, then refresh it.
    setState(() => _followMe = true);
    await _moveCameraTo(_here!, zoom: 18, duration: const Duration(milliseconds: 900));

    final fresh = await _locationService.freshPosition();
    if (!mounted) return;
    if (fresh != null && shouldUsePosition(_position, fresh)) {
      setState(() => _position = fresh);
      _afterNewPosition();
    }

    if (!_withinMapArea(_here!)) {
      setState(() => _followMe = false);
      final km = (_distance(_here!, CampusMapBounds.centre) / 1000).toStringAsFixed(1);
      _showMessage('You are $km km from CDU Casuarina campus.');
      await _showWholeCampus();
      return;
    }
    if (_followMe) _followTo(_here!);
  }

  // ---------------------------------------------------------------------------
  // Follow me: after the location button is tapped the map keeps the user in
  // the middle as they walk, until they drag the map themselves.
  // ---------------------------------------------------------------------------

  bool _followMe = false;
  LatLng? _lastCameraTarget;

  /// The map can show the campus plus about 3 km around it.
  static final LatLngBounds _mapArea = LatLngBounds(
    southwest: LatLng(CampusMapBounds.bottomLeft.latitude - 0.027,
        CampusMapBounds.bottomLeft.longitude - 0.027),
    northeast: LatLng(CampusMapBounds.topRight.latitude + 0.027,
        CampusMapBounds.topRight.longitude + 0.027),
  );

  static bool _withinMapArea(LatLng p) =>
      p.latitude >= _mapArea.southwest.latitude &&
      p.latitude <= _mapArea.northeast.latitude &&
      p.longitude >= _mapArea.southwest.longitude &&
      p.longitude <= _mapArea.northeast.longitude;

  /// Until this time the camera is flying somewhere the app sent it. GPS
  /// updates must not start a new move meanwhile: on the web a new move
  /// cancels the current one (the zoom-in would stop half-way).
  DateTime _cameraBusyUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _cameraBusy => DateTime.now().isBefore(_cameraBusyUntil);

  Future<void> _moveCameraTo(
    LatLng target, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    _lastCameraTarget = target;
    _cameraBusyUntil = DateTime.now().add(duration + const Duration(milliseconds: 400));
    await _map?.animateCamera(
      zoom == null
          ? CameraUpdate.newLatLng(target)
          : CameraUpdate.newLatLngZoom(target, zoom),
      duration: duration,
    );
  }

  /// Keeps the user in the middle while following, without interrupting a
  /// camera move that is still running and without moving for tiny changes.
  void _followTo(LatLng here) {
    if (_cameraBusy) return; // the next GPS update will catch up
    final last = _lastCameraTarget;
    if (last != null && _distance(last, here) < 2) return;
    _moveCameraTo(here);
  }

  /// When the camera stops far from where the app last put it, the user
  /// dragged the map: stop following.
  void _onCameraIdle() {
    if (!_followMe || _lastCameraTarget == null || _cameraBusy) return;
    final now = _map?.cameraPosition?.target;
    if (now != null && _distance(now, _lastCameraTarget!) > 30) {
      setState(() => _followMe = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: CampusLayers.baseStyle,
            initialCameraPosition: CameraPosition(
              target: CampusMapBounds.centre,
              zoom: _campusZoom,
            ),
            cameraTargetBounds: CameraTargetBounds(_mapArea),
            trackCameraPosition: true,
            onCameraIdle: _onCameraIdle,
            minMaxZoomPreference: const MinMaxZoomPreference(14.5, 20),
            // Flat map only: no tilting.
            tiltGesturesEnabled: false,
            compassEnabled: true,
            compassViewPosition: CompassViewPosition.topRight,
            compassViewMargins: const math.Point(16, 150),
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: _onMapClick,
            // Phones draw the location dot natively; the web app draws its own
            // (CampusLayers.showMyLocation), which is more reliable in browsers.
            myLocationEnabled: _hasLocation && !kIsWeb,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            myLocationRenderMode: _mode == _Mode.navigating
                ? MyLocationRenderMode.compass
                : MyLocationRenderMode.normal,
          ),
          if (!_layersReady && _mapError == null)
            const Center(child: CircularProgressIndicator(color: cduNavy)),
          if (_mode != _Mode.navigating)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchBar(
                      onTap: _openSearch,
                      onAbout: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                      ),
                    ),
                    if (_statusChip() case final chip?) ...[
                      const SizedBox(height: 8),
                      chip,
                    ],
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  alignment: Alignment.centerRight,
                  // On the web the map credit line sits along the bottom edge.
                  padding: EdgeInsets.only(right: 14, bottom: kIsWeb ? 34 : 14),
                  child: _MapButtons(
                    hasLocation: _hasLocation,
                    following: _followMe && _hasLocation,
                    onWholeCampus: _showWholeCampus,
                    onMyLocation: _goToMyLocation,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _bottomPanel() ?? const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _bottomPanel() {
    final b = _selected;
    if (b == null) return null;
    switch (_mode) {
      case _Mode.browse:
        return BuildingCard(
          key: ValueKey('card-${b.id}'),
          building: b,
          onDirections: _openDirections,
          onClose: _clearSelection,
        );
      case _Mode.routes:
        return RoutePanel(
          key: const ValueKey('routes'),
          destination: b,
          fromLabel: _fromLabel,
          routes: _routes,
          selected: _routeIndex,
          error: _routeError,
          canStart: _canStart,
          startHint: _startHint,
          onSelect: _selectRoute,
          onChangeStart: _changeStart,
          onStart: _startNavigation,
          onClose: () => _selectBuilding(b),
        );
      case _Mode.navigating:
        return NavigationPanel(
          key: const ValueKey('nav'),
          destination: b,
          remainingMetres: _remaining,
          arrived: _arrived,
          rerouting: _rerouting,
          onEnd: _endNavigation,
        );
    }
  }

  /// Small status line under the search bar, only when something needs attention.
  Widget? _statusChip() {
    if (_mapError != null) {
      return _Chip(icon: Icons.error_outline, text: _mapError!, colour: Colors.red.shade700);
    }
    if (_locating) {
      return const _Chip(icon: Icons.gps_not_fixed, text: 'Finding your location…');
    }
    if (_locationProblem != null) {
      final problem = LocationException(_locationProblem!);
      return _Chip(
        icon: Icons.location_off,
        text: problem.message,
        colour: Colors.red.shade700,
        action: problem.canOpenSettings ? 'Settings' : 'Try again',
        onAction: problem.canOpenSettings ? _fixLocationProblem : _startLocation,
      );
    }
    final acc = _position?.accuracy;
    if (!_onCampus) {
      return const _Chip(icon: Icons.explore_off, text: 'You are not on campus right now');
    }
    if (acc != null && acc > lowAccuracyMetres) {
      // The pale circle around the dot already shows the uncertainty; only
      // speak up when it is large, and say what helps.
      return _Chip(
        icon: Icons.gps_not_fixed,
        text: 'Location accurate to ±${acc.round()} m. '
            'Go outdoors or turn on precise location.',
        colour: Colors.orange.shade900,
      );
    }
    return null;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap, required this.onAbout});
  final VoidCallback onTap;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(28),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: cduNavy),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search CDU — e.g. Red 6, Library',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'About',
            onPressed: onAbout,
            icon: const Icon(Icons.info_outline, color: cduNavy),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    this.colour,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final Color? colour;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colour),
            const SizedBox(width: 8),
            Flexible(child: Text(text, style: TextStyle(color: colour))),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!))
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _MapButtons extends StatelessWidget {
  const _MapButtons({
    required this.hasLocation,
    required this.following,
    required this.onWholeCampus,
    required this.onMyLocation,
  });

  final bool hasLocation;

  /// The map is keeping the user in the middle (button shown solid blue).
  final bool following;
  final VoidCallback onWholeCampus;
  final VoidCallback onMyLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'whole-campus',
          tooltip: 'Show whole campus',
          backgroundColor: Colors.white,
          onPressed: onWholeCampus,
          child: const Icon(Icons.zoom_out_map, color: cduNavy),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'my-location',
          tooltip: following ? 'Following your location' : 'Go to my location',
          backgroundColor: following ? routeBlue : Colors.white,
          onPressed: onMyLocation,
          child: Icon(
            !hasLocation
                ? Icons.location_disabled
                : following
                    ? Icons.my_location
                    : Icons.location_searching,
            color: following ? Colors.white : routeBlue,
          ),
        ),
      ],
    );
  }
}
