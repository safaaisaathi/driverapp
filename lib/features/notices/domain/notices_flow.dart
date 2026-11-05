/// D3 Notices inbox flow controller (F-D4, ticket 09).
///
/// One Riverpod notifier drives the D3 state machine: loading → the list
/// (ready / empty) or the degraded states (error / offline, localized in
/// the UI layer). The list is exactly the notices addressed to the running
/// shift's van, to the route's wards, or to everyone (Glossary: Notice) —
/// the three-shape filter lives in the repository watch (0.7 sendNotice
/// fan-out mirrored client-side); the controller re-asserts the contract
/// sort (newest first) so the screen always reads freshest on top.
///
/// **Unread semantics:** the contract's `notices` shape (0.2) carries no
/// read field and no new storage may be invented (0.15.4), so "unread" is
/// session-local: a notice is unread from the moment the app first sees it
/// (push or stream) until the driver opens it this session. Marking read
/// therefore writes NOTHING to the repository — the red test pins that.
/// Persistence is parked in the bags for the Backend Owner (contract field
/// would be needed).
///
/// Route context comes from the shift session (F-D1 → anywhere seam):
/// `shiftControllerProvider` → `routesRepositoryProvider.readRoute` →
/// `routes.wardIds` in visiting order (the same seam D4 uses). The
/// provider is `autoDispose`: D2's badge and this screen are its only
/// watchers, so the repository listener is open only while something
/// visible watches it and is cancelled on dispose (0.11).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/firebase_bootstrap.dart'
    show sessionGateProvider;
import '../../../core/models/models.dart';
import '../../../core/repositories/repositories.dart';
import '../../shift_start/domain/shift_session.dart';

enum NoticesPhase {
  /// First snapshot pending.
  loading,

  /// Notices on screen (this van / this route's wards / everyone).
  ready,

  /// The watch returned nothing — the quiet "no notices" state.
  empty,

  /// Read failed for reasons other than transport (degraded).
  error,

  /// Transport unavailable (`code == unavailable`) — dead zone / no network.
  offline,
}

/// Immutable D3 state; every string the screen shows comes from l10n.
final class NoticesState {
  const NoticesState({
    required this.phase,
    this.notices = const <Notice>[],
    this.unread = const <String>{},
  });

  final NoticesPhase phase;

  /// The visible notices, newest first.
  final List<Notice> notices;

  /// Ids of the visible notices not yet opened this session — the unread
  /// dots on the rows and the D2 badge count are derived from this set.
  final Set<String> unread;

  NoticesState copyWith({
    NoticesPhase? phase,
    List<Notice>? notices,
    Set<String>? unread,
  }) =>
      NoticesState(
        phase: phase ?? this.phase,
        notices: notices ?? this.notices,
        unread: unread ?? this.unread,
      );
}

/// Riverpod wiring for the D3 flow. `autoDispose`: D2's unread badge and
/// the inbox screen watch through [unreadNoticesCountProvider] / this
/// provider — with both gone, the state and the repository listener die
/// (listeners only while visible, cancelled on dispose). Re-entry (driver
/// reopens the inbox) rebuilds and re-kicks through the loading phase.
final noticesFlowProvider =
    NotifierProvider.autoDispose<NoticesFlowController, NoticesState>(
  NoticesFlowController.new,
);

/// The D2 app-bar badge number: unread notices of [noticesFlowProvider],
/// 0 during loading / empty / degraded phases. D2's badge slot watches
/// only this — keeping the flow alive exactly as long as D2 is visible.
final unreadNoticesCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(noticesFlowProvider).unread.length;
});

/// Drives D3 (public methods = events from the screen).
// Not `final`: tests may subclass to script edge cases (ticket-10 pattern).
class NoticesFlowController extends Notifier<NoticesState> {
  StreamSubscription<List<Notice>>? _sub;

  bool _loadInFlight = false;

  /// Ids the driver opened this session; unread derivation subtracts them
  /// on every re-emission so a fresh snapshot never resurrects a dot.
  final Set<String> _readIds = {};

  @override
  NoticesState build() {
    // The shift session is the one reactive dependency: activating (or
    // ending) a shift rebuilds this flow; the kick below (re)loads.
    final session = ref.watch(shiftControllerProvider);
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _sub = null;
    });
    if (session == null) {
      // D3 without a running shift has no van/route context to watch
      // (dev/demo misuse); surface the boring degraded state now — the
      // Retry button re-runs the load (session still null → stays error).
      return const NoticesState(phase: NoticesPhase.error);
    }
    // Self-serve kick: D2's badge starts the flow without any screen
    // post-frame callback (the D4 pattern needs a widget kick; the badge
    // may be the first and only watcher). A microtask keeps the build
    // pure; the guards inside [ensureLoaded] make double kicks no-ops.
    scheduleMicrotask(() => ensureLoaded());
    return const NoticesState(phase: NoticesPhase.loading);
  }

  // Imperative reads (not watches): this controller drives kicks and
  // retried loads; repository providers must not rebuild it (the D1
  // lesson — a rebuild would loop through the loading phase).
  NoticesRepository get _notices => ref.read(noticesRepositoryProvider);

  RoutesRepository get _routes => ref.read(routesRepositoryProvider);

  /// A no-op once a watch is active — re-subscription goes through [retry].
  Future<void> ensureLoaded() async {
    if (_sub != null) return;
    await _load();
  }

  /// Retry entry point for the error / offline states.
  Future<void> retry() => _load();

  Future<void> _load() async {
    // Re-entrancy guard: a self-serve kick racing the screen's post-frame
    // kick must not layer subscriptions.
    if (_loadInFlight) return;
    _loadInFlight = true;
    try {
      await _runLoad();
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> _runLoad() async {
    // The kick can land after disposal (late microtask) — bail instead of
    // reading from a dead ref.
    if (!ref.mounted) return;
    final session = ref.read(shiftControllerProvider);
    if (session == null) {
      // D3 without a running shift has no van/route context (dev/demo
      // misuse); surface the boring degraded state — Retry re-runs.
      state = const NoticesState(phase: NoticesPhase.error);
      return;
    }
    state = const NoticesState(phase: NoticesPhase.loading);
    try {
      // F-11: the route read is Firestore work; never race boot on a cold or
      // degraded launch.
      await ref.read(sessionGateProvider);
      final route = await _routes.readRoute(session.routeId);
      if (!ref.mounted) return;
      if (route == null) {
        // A missing route doc invents no wards — degraded state.
        state = const NoticesState(phase: NoticesPhase.error);
        return;
      }
      // Fire-and-forget: awaiting a subscription cancel never completes
      // inside the widget-test FakeAsync zone (ruling 21) — the same
      // pattern as the dispose hook above and the ticket-10 flow.
      unawaited(_sub?.cancel());
      _sub = _notices
          .watchNotices(
        vanId: session.vanId,
        wardIds: route.wardIds,
      )
          .listen(_onList, onError: _onListError);
    } on Exception {
      state = const NoticesState(phase: NoticesPhase.error);
    }
  }

  void _onList(List<Notice> notices) {
    if (!ref.mounted) return;
    // Defensive re-sort: the repository owns the newest-first contract
    // sort (ruling 10); asserting it here keeps the screen honest even
    // against a seam drift (the same belt-and-braces as ticket 10).
    final sorted = List<Notice>.of(notices)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final unread = <String>{
      for (final notice in sorted)
        if (!_readIds.contains(notice.id)) notice.id,
    };
    state = sorted.isEmpty
        ? const NoticesState(phase: NoticesPhase.empty)
        : NoticesState(
            phase: NoticesPhase.ready,
            notices: List.unmodifiable(sorted),
            unread: unread,
          );
  }

  void _onListError(Object error) => state = NoticesState(
        phase: _isUnavailable(error)
            ? NoticesPhase.offline
            : NoticesPhase.error,
      );

  /// Opening (tapping) a notice marks it read for this session: the dot
  /// clears and [unreadNoticesCountProvider] drops. No repository write —
  /// the contract's notices shape has no read field (see library doc).
  void markRead(String noticeId) {
    final phase = state.phase;
    if (phase != NoticesPhase.ready || !state.unread.contains(noticeId)) {
      return;
    }
    _readIds.add(noticeId);
    state = state.copyWith(
      unread: <String>{
        for (final id in state.unread)
          if (id != noticeId) id,
      },
    );
  }

  /// Whether [error] is a transport-availability failure. Firestore
  /// surfaces it as a `unavailable` code; the shape is duck-typed so this
  /// feature file keeps its hands off Firebase (0.11) and the fake can
  /// throw the same shape (the ticket-10 precedent).
  bool _isUnavailable(Object error) {
    try {
      return (error as dynamic).code == 'unavailable';
    } on NoSuchMethodError {
      return false;
    }
  }
}
