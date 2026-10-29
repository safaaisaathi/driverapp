/// Driver identity controller (ticket 3, PRD-2 §0.16): the device-local
/// `setupDone` flag and the last confirmed driver code as Riverpod state.
///
/// The splash routes on [DriverIdentityState.isReturning]: returning =
/// setupDone AND a code remembered; fresh otherwise. Absent or corrupt
/// stored values degrade to fresh-device, never throw. Code-format
/// validation is NOT this layer's job (the flow layer validates when the
/// code is used; a stale code falls back at fetch time, ticket 5).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_identity_store.dart';

/// Storage seam for the driver identity; overridden with an in-memory
/// fake in tests so nothing touches the SharedPreferences channel.
final driverIdentityStoreProvider = Provider<DriverIdentityStore>(
  (ref) => const SharedPreferencesDriverIdentityStore(),
);

/// Whether the phone is set up and who it remembers.
final class DriverIdentityState {
  const DriverIdentityState({this.isSetupDone = false, this.rememberedCode});

  /// The one-time guided setup (0.13 permission flow) was completed.
  final bool isSetupDone;

  /// The last confirmed driver code, verbatim (normalized by the flow
  /// layer before it gets here; never validated here).
  final String? rememberedCode;

  /// What the splash routes on: a returning driver needs BOTH the
  /// setup-done flag and a remembered code.
  bool get isReturning => isSetupDone && rememberedCode != null;
}

/// The driver identity: remember setup and the confirmed code across
/// launches through [DriverIdentityStore].
class DriverIdentityController extends Notifier<DriverIdentityState> {
  Future<void>? _restoring;

  /// Set by every explicit action, so a restore still in flight never
  /// clobbers it (the LocaleController "the tap wins" rule, generalized:
  /// clearDriver lands on the pristine default, which a state comparison
  /// cannot tell apart from "nothing happened yet").
  bool _touched = false;

  @override
  DriverIdentityState build() {
    // Fire-and-forget restore: the app renders its fresh-device fallback
    // while storage answers — the same degrade-don't-crash idiom as
    // LocaleController. main() awaits the SAME future before runApp, so
    // the first frame already knows fresh-vs-returning.
    unawaited(ensureRestored());
    return const DriverIdentityState();
  }

  /// Awaitable restore handle. [build] fires it unawaited; main() awaits
  /// it before runApp; tests await it instead of sleeping on the event
  /// loop. One future per controller lifetime (the provider builds once).
  Future<void> ensureRestored() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      final store = ref.read(driverIdentityStoreProvider);
      final setupDone = await store.readSetupDone();
      final storedCode = await store.readDriverCode();
      // An empty stored string is corrupt for our purposes (no code is a
      // better answer than "" as an identity); any other string is kept
      // verbatim.
      final code = (storedCode == null || storedCode.isEmpty) ? null : storedCode;
      // An action made while restoring wins over the stored values.
      if (ref.mounted && !_touched) {
        state = DriverIdentityState(
          isSetupDone: setupDone ?? false,
          rememberedCode: code,
        );
      }
    } on Exception {
      // Storage unavailable (tests without an override, or a broken
      // disk): degrade to fresh-device, never crash.
    }
  }

  /// The one-time guided setup finished: latches the flag in state and
  /// storage. Never un-done (clearDriver forgets only the code).
  Future<void> markSetupDone() async {
    _touched = true;
    state = DriverIdentityState(
      isSetupDone: true,
      rememberedCode: state.rememberedCode,
    );
    try {
      await ref.read(driverIdentityStoreProvider).writeSetupDone(true);
    } on Exception {
      // Keep the in-session flag on a failed write; the next launch
      // simply degrades to fresh-device and replays the setup.
    }
  }

  /// The driver confirmed their identity: remembers the code VERBATIM.
  /// Change-driver = calling this again with the new code overwrites.
  Future<void> rememberDriver(String code) async {
    _touched = true;
    state = DriverIdentityState(
      isSetupDone: state.isSetupDone,
      rememberedCode: code,
    );
    try {
      await ref.read(driverIdentityStoreProvider).writeDriverCode(code);
    } on Exception {
      // Keep the in-session code on a failed write; the next launch
      // simply asks for it again.
    }
  }

  /// "Not you?" — forgets only the code; setupDone stays (the phone is
  /// still set up, the next driver just types their own code).
  Future<void> clearDriver() async {
    _touched = true;
    state = DriverIdentityState(isSetupDone: state.isSetupDone);
    try {
      await ref.read(driverIdentityStoreProvider).writeDriverCode(null);
    } on Exception {
      // The in-session code is already gone; a failed write only means
      // the stale code resurfaces on the next launch (and falls back at
      // fetch time, ticket 5).
    }
  }
}

final driverIdentityControllerProvider = NotifierProvider<DriverIdentityController,
    DriverIdentityState>(DriverIdentityController.new);
