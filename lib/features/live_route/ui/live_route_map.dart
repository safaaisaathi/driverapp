/// The full-screen flutter_map for the Live Route screen (PRD-2 section 6
/// pins flutter_map + OpenStreetMap; no API key exists in the contract).
///
/// Markers render straight from [LiveRouteData] — no Riverpod here, so the
/// widget is trivially testable from the pure state. Marker keys mirror the
/// list panel's (`liveRoute.wardRow.<wardId>`) to keep tests symmetrical.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:driverapp/core/theme/app_theme.dart';

import '../live_route_providers.dart';
import '../domain/live_route_state.dart';
import '../domain/van_marker_state.dart';
import '../domain/ward_steps.dart';

/// The map canvas: ward circles (radius), ward step markers, van marker.
///
/// FOLLOWS THE VAN until the user pans (standard driver-app behaviour, and a
/// real bug otherwise: a van doc that streams in after the first layout can
/// sit kilometres outside the initial camera, and flutter_map then culls its
/// marker — the driver would "see no van"). Any map event NOT sourced from
/// the controller (drag, fling, gestures) stops the follow.
class LiveRouteMap extends ConsumerStatefulWidget {
  final LiveRouteData data;

  const LiveRouteMap({super.key, required this.data});

  @override
  ConsumerState<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends ConsumerState<LiveRouteMap> {
  final MapController _mapController = MapController();
  bool _followingVan = true;
  bool _hadVanLastFrame = false;

  @override
  void didUpdateWidget(covariant LiveRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hadVanLastFrame = oldWidget.data.vanMarker != null;
    _maybeCenterOnVan();
  }

  void _maybeCenterOnVan() {
    final van = widget.data.vanMarker;
    if (!_followingVan || van == null || !mounted) return;
    final pos = LatLng(van.position.lat, van.position.lng);
    final zoomIn = !_hadVanLastFrame; // first fix this session: zoom to street
    // move() outside the build cycle only — the camera mid-layout would throw.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_followingVan) return;
      _mapController.move(
        pos,
        zoomIn ? 15.5 : _mapController.camera.zoom,
      );
    });
  }

  void _onMapEvent(MapEvent event) {
    // Only GESTURE sources mean the driver took over the camera. Layout and
    // programmatic sources (nonRotatedSizeChange fires on every resize —
    // pumps in tests, rotation/keyboard on device) must NOT end the follow.
    const layoutSources = {
      MapEventSource.mapController,
      MapEventSource.fitCamera,
      MapEventSource.custom,
      MapEventSource.nonRotatedSizeChange,
    };
    if (!layoutSources.contains(event.source)) {
      _followingVan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final data = widget.data;
    final tileUrl = ref.watch(tileUrlTemplateProvider);

    final stepPoints = [
      for (final step in data.wardSteps)
        LatLng(step.ward.center.lat, step.ward.center.lng),
    ];

    final van = data.vanMarker;
    final initialCenter = van != null
        ? LatLng(van.position.lat, van.position.lng)
        : stepPoints.isNotEmpty
            ? stepPoints.first
            : const LatLng(22.6, 73.0); // Godhra (Panchmahal DDO) fallback.

    return FlutterMap(
      // Tests assert on this key.
      key: const Key('liveRoute.map'),
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: van == null ? 13 : 15.5,
        onMapEvent: _onMapEvent,
      ),
      children: [
        if (tileUrl != null)
          TileLayer(
            urlTemplate: tileUrl,
            userAgentPackageName: 'com.sfic.driverapp',
          ),
        CircleLayer(
          circles: [
            for (final step in data.wardSteps)
              CircleMarker(
                point: LatLng(step.ward.center.lat, step.ward.center.lng),
                radius: step.ward.radiusM,
                useRadiusInMeter: true,
                color: step.isDone
                    ? AppTheme.colorPrimary.withValues(alpha: 0.15)
                    : AppTheme.colorStatusReceived.withValues(alpha: 0.10),
                borderStrokeWidth: 1.5,
                borderColor: step.isDone
                    ? AppTheme.colorPrimary.withValues(alpha: 0.4)
                    : AppTheme.colorStatusReceived.withValues(alpha: 0.4),
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final step in data.wardSteps) _wardMarker(step),
            if (van != null) _vanMarker(van),
          ],
        ),
        RichAttributionWidget(
          attributions: const [TextSourceAttribution('© OpenStreetMap')],
        ),
      ],
    );
  }

  Marker _wardMarker(WardStep step) {
    final color = switch ((step.isDone, step.isNext)) {
      (true, _) => AppTheme.colorPrimary,
      (false, true) => AppTheme.colorStatusReceived,
      (false, false) => AppTheme.colorTextMuted,
    };
    return Marker(
      point: LatLng(step.ward.center.lat, step.ward.center.lng),
      width: step.isNext ? 44 : 34,
      height: step.isNext ? 44 : 34,
      alignment: Alignment.center,
      child: Container(
        key: Key('liveRoute.wardMarker.${step.ward.id}'),
        decoration: BoxDecoration(
          color: step.isNext
              ? AppTheme.colorPrimary
              : color.withValues(alpha: step.isDone ? 1 : 0.25),
          shape: BoxShape.circle,
          border: Border.all(
            color: step.isNext || step.isDone
                ? AppTheme.colorOnPrimary
                : AppTheme.colorTextMuted,
            width: step.isNext ? 2.5 : 1.5,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Center(
          child: step.isDone
              ? const Icon(Icons.check, size: 18, color: AppTheme.colorOnPrimary)
              : step.isNext
                  ? const Icon(Icons.flag, size: 20, color: AppTheme.colorOnPrimary)
                  : Text(
                      '${step.orderIndex + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.colorTextPrimary,
                      ),
                    ),
        ),
      ),
    );
  }

  Marker _vanMarker(VanMarkerState van) {
    return Marker(
      point: LatLng(van.position.lat, van.position.lng),
      width: 44,
      height: 44,
      alignment: Alignment.center,
      child: Container(
        key: const Key('liveRoute.vanMarker'),
        decoration: BoxDecoration(
          color: (van.isStale
                  ? AppTheme.colorTextMuted
                  : AppTheme.colorStatusAssigned)
              .withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.colorOnPrimary,
            width: 2,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.local_shipping,
            size: 22,
            color: AppTheme.colorOnPrimary,
          ),
        ),
      ),
    );
  }
}
