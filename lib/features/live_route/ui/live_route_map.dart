/// The full-screen flutter_map for the Live Route screen (PRD-2 section 6
/// pins flutter_map + OpenStreetMap; no API key exists in the contract).
///
/// Markers render straight from [LiveRouteData] — no Riverpod here, so the
/// widget is trivially testable from the pure state. Marker keys mirror the
/// list panel's (`liveRoute.wardRow.<wardId>`) to keep tests symmetrical.
///
/// Skin per docs/DESIGN.md §4.10:
/// - ward areas: dashed 2 dp `brand` outline + 8% `brand` fill;
/// - van marker: 44 dp `brand` circle, 3 dp white ring, truck 24 in
///   `onBrand` (white on light `brand`, ink on dark `brandMid` — no
///   brightness branch, CL-20); soft pulse while moving (static under
///   reduced motion); stale = `surfaceMuted` fill + `textMuted` icon +
///   the "Last seen X min ago" bubble above;
/// - OSM attribution bottom-LEFT, above the sheet's collapsed top (it used
///   to sit bottom-right under the PillNav);
/// - Recenter AppIconButton bottom-right above the sheet;
/// - every node labelled for TalkBack (CL-25) — the map is no longer a bare
///   "flutter_map" node.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_colors.dart';
import 'package:driverapp/core/theme/app_text.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/core/theme/app_tokens.dart';
import 'package:driverapp/core/widgets/app_icon_button.dart';
import 'package:driverapp/core/widgets/draggable_sheet.dart'
    show DraggableSheet;

import '../live_route_providers.dart';
import '../domain/live_route_state.dart';
import '../domain/van_marker_state.dart';
import '../domain/ward_steps.dart';

/// The map canvas: ward areas + markers, van marker, attribution, recenter.
///
/// FOLLOWS THE VAN until the user pans (standard driver-app behaviour, and a
/// real bug otherwise: a van doc that streams in after the first layout can
/// sit kilometres outside the initial camera, and flutter_map then culls its
/// marker — the driver would "see no van"). Any map event NOT sourced from
/// the controller (drag, fling, gestures) stops the follow; the Recenter
/// button resumes it.
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
      _mapController.move(pos, zoomIn ? 15.5 : _mapController.camera.zoom);
    });
  }

  /// The Recenter button: take the camera back to the van AND resume the
  /// follow (that is what "recenter" means here — pan only had stopped it).
  void _recenter() {
    final van = widget.data.vanMarker;
    final target = van != null
        ? LatLng(van.position.lat, van.position.lng)
        : _initialCenter();
    _followingVan = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(target, 15.5);
    });
  }

  LatLng _initialCenter() {
    final van = widget.data.vanMarker;
    if (van != null) return LatLng(van.position.lat, van.position.lng);
    final points = _stepPoints();
    return points.isNotEmpty ? points.first : const LatLng(22.6, 73.0);
  }

  List<LatLng> _stepPoints() => [
    for (final step in widget.data.wardSteps)
      LatLng(step.ward.center.lat, step.ward.center.lng),
  ];

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
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;
    final tileUrl = ref.watch(tileUrlTemplateProvider);

    final van = data.vanMarker;
    final initialCenter = _initialCenter();
    // Bottom free zone: everything anchored at the map's bottom must clear
    // the sheet's collapsed top (the sheet slides over both when expanded —
    // the map content it covers is not interactive then).
    final collapsedTop =
        MediaQuery.sizeOf(context).height * DraggableSheet.collapsedFraction;

    return Stack(
      children: [
        Semantics(
          label: l10n.liveRouteMapSemantic,
          child: FlutterMap(
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
              // Ward areas (§4.10): dashed 2 dp brand outline + 8% brand
              // fill. One Polygon per ward — a circular polygon gives both
              // the fill and the dashed border in one layer (v8 StrokePattern).
              PolygonLayer(
                polygons: [
                  for (final step in data.wardSteps)
                    Polygon(
                      points: _circlePoints(
                        step.ward.center.lat,
                        step.ward.center.lng,
                        step.ward.radiusM,
                      ).toList(),
                      color: c.brand.withValues(alpha: 0.08),
                      borderStrokeWidth: 2,
                      borderColor: c.brand.withValues(alpha: 0.9),
                      pattern: StrokePattern.dashed(
                        segments: const [8, 8],
                      ),
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final step in data.wardSteps) _wardMarker(step, l10n, c),
                  if (van != null) _vanMarker(van, l10n, c),
                  if (van != null && van.isStale) _staleBubble(van, l10n, c),
                ],
              ),
              // OSM attribution: bottom-left, above the sheet's collapsed
              // top (§4.10; it must never sit under the PillNav again).
              Padding(
                padding: EdgeInsets.only(bottom: collapsedTop + AppSpace.xs),
                child: RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: const [
                    TextSourceAttribution('© OpenStreetMap'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Recenter (§4.10): AppIconButton 48, bottom-right, above the sheet.
        Positioned(
          right: AppSpace.lg,
          bottom: collapsedTop + AppSize.navHeightDriver + AppSpace.lg,
          child: AppIconButton(
            key: const Key('liveRoute.recenter'),
            onPressed: _recenter,
            icon: Icons.my_location,
            size: AppSize.iconButton,
            isGlass: true,
            semanticsLabel: l10n.recenterMap,
            tooltip: l10n.recenterMap,
          ),
        ),
      ],
    );
  }

  /// A circle approximated as a 48-gon — enough smoothness at ward radii.
  static Iterable<LatLng> _circlePoints(
    double lat,
    double lng,
    double radiusM,
  ) sync* {
    const steps = 48;
    final latRad = lat * math.pi / 180;
    final latDelta = radiusM / 111320;
    final lngDelta = radiusM / (111320 * math.cos(latRad));
    for (var i = 0; i < steps; i++) {
      final angle = 2 * math.pi * i / steps;
      yield LatLng(
        lat + latDelta * math.sin(angle),
        lng + lngDelta * math.cos(angle),
      );
    }
  }

  Marker _wardMarker(WardStep step, AppLocalizations l10n, AppColors c) {
    // Same color language as the sheet rows (§4.17): primary = next,
    // brand = done, surface = pending.
    final semantic = step.isDone
        ? '${step.ward.name}, ${l10n.markDone}'
        : step.isNext
        ? '${step.ward.name}, ${l10n.nextWardLabel}'
        : step.ward.name;

    return Marker(
      point: LatLng(step.ward.center.lat, step.ward.center.lng),
      width: step.isNext ? AppSize.vanMarker : 34,
      height: step.isNext ? AppSize.vanMarker : 34,
      alignment: Alignment.center,
      child: Semantics(
        label: semantic,
        child: Container(
          key: Key('liveRoute.wardMarker.${step.ward.id}'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: step.isDone
                ? c.brand
                : step.isNext
                ? c.primary
                : c.surface,
            border: Border.all(
              color: step.isNext || step.isDone
                  ? AppTheme.colorOnPrimary
                  : c.textMuted,
              width: step.isNext ? 2.5 : 1.5,
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: Center(
            child: step.isDone
                ? Icon(Icons.check, size: 18, color: c.onBrand)
                : step.isNext
                ? Icon(Icons.flag, size: 20, color: c.onPrimary)
                : Text(
                    '${step.orderIndex + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Marker _vanMarker(VanMarkerState van, AppLocalizations l10n, AppColors c) {
    // 44 dp circle + 3 dp white ring + truck 24 (§4.10). The pulse ring may
    // overflow the 44 box, so the marker box is larger and the circle sits
    // centred inside it.
    final moving = !van.isStale && van.speedKmph > 1;
    final animate = moving && !MediaQuery.of(context).disableAnimations;

    return Marker(
      point: LatLng(van.position.lat, van.position.lng),
      width: AppSize.vanMarker * 1.6,
      height: AppSize.vanMarker * 1.6,
      alignment: Alignment.center,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (animate) _VanPulseRing(color: c.brand),
            Semantics(
              label: van.isStale
                  ? l10n.vanLastSeen(van.minutesSinceUpdate)
                  : l10n.vanMarkerSemantic,
              child: Container(
                key: const Key('liveRoute.vanMarker'),
                width: AppSize.vanMarker,
                height: AppSize.vanMarker,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: van.isStale ? c.surfaceMuted : c.brand,
                  border: Border.all(color: AppTheme.colorOnPrimary, width: 3),
                ),
                child: Icon(
                  Icons.local_shipping,
                  size: 24,
                  color: van.isStale ? c.textMuted : c.onBrand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The "Last seen X min ago" bubble (§4.10 EtaBubble): surface pill above
  /// the van marker — stale position must never present as live (0.13).
  Marker _staleBubble(VanMarkerState van, AppLocalizations l10n, AppColors c) {
    return Marker(
      point: LatLng(van.position.lat, van.position.lng),
      width: 220,
      height: 100,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: Theme.of(context).brightness == Brightness.dark
                  ? AppElevation.elev2Dark
                  : AppElevation.elev2,
            ),
            child: Text(
              l10n.vanLastSeen(van.minutesSinceUpdate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.label.copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(height: AppSize.vanMarker),
        ],
      ),
    );
  }
}

/// The soft pulse ring of a moving van (§4.10): 2400 ms ambient cycle, the
/// SAME duration as the mascot bob; disabled under reduced motion.
class _VanPulseRing extends StatefulWidget {
  final Color color;

  const _VanPulseRing({required this.color});

  @override
  State<_VanPulseRing> createState() => _VanPulseRingState();
}

class _VanPulseRingState extends State<_VanPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.ambient,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final size = AppSize.vanMarker * (1.0 + 0.45 * t);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.30 * (1 - t)),
          ),
        );
      },
    );
  }
}
