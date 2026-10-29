/// Driver identity persistence (ticket 3, PRD-2 §0.16) — pure Dart tests
/// over the [DriverIdentityStore] seam: no widgets, no Firebase, no
/// platform channels.
///
/// The store is DUMB (a bool + a string, verbatim); the controller owns
/// the fresh-vs-returning answer the splash will route on.
library;

import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/identity/driver_identity_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'driver_identity_fakes.dart';

/// Deterministically lands the restore by awaiting the controller's own
/// handle (the LocaleController idiom, Bug Bag fix 2026-10-29: no
/// event-loop pumping games).
Future<void> awaitRestored(ProviderContainer container) =>
    container.read(driverIdentityControllerProvider.notifier).ensureRestored();

void main() {
  group('DriverIdentityController on the in-memory store seam', () {
    late InMemoryDriverIdentityStore store;
    late ProviderContainer container;

    setUp(() {
      store = InMemoryDriverIdentityStore();
      container = ProviderContainer(
        overrides: [driverIdentityStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
    });

    test('fresh install: nothing stored → fresh-device state, not '
        'returning', () async {
      container.read(driverIdentityControllerProvider);
      await awaitRestored(container);

      final state = container.read(driverIdentityControllerProvider);
      expect(state.isSetupDone, isFalse);
      expect(state.rememberedCode, isNull);
      expect(state.isReturning, isFalse);
    });

    test('ensureRestored is one future per controller lifetime', () async {
      final notifier = container.read(driverIdentityControllerProvider.notifier);
      expect(identical(notifier.ensureRestored(), notifier.ensureRestored()),
          isTrue);
      await awaitRestored(container);
    });

    test('restore: stored setupDone + code → a returning driver (what the '
        'splash routes on)', () async {
      store.values[driverSetupDoneKey] = true;
      store.values[driverCodeKey] = 'AB-1234';

      container.read(driverIdentityControllerProvider);
      await awaitRestored(container);

      final state = container.read(driverIdentityControllerProvider);
      expect(state.isSetupDone, isTrue);
      expect(state.rememberedCode, 'AB-1234');
      expect(state.isReturning, isTrue);
    });

    test('corrupt stored values (garbage types) degrade to fresh-device, '
        'never throw', () async {
      store.values[driverSetupDoneKey] = 42; // a bool key holding an int
      store.values[driverCodeKey] = false; // a string key holding a bool

      container.read(driverIdentityControllerProvider);
      await awaitRestored(container);

      final state = container.read(driverIdentityControllerProvider);
      expect(state.isSetupDone, isFalse);
      expect(state.rememberedCode, isNull);
      expect(state.isReturning, isFalse);
    });

    test('an empty stored code degrades to "not remembered" (setupDone '
        'survives)', () async {
      store.values[driverSetupDoneKey] = true;
      store.values[driverCodeKey] = '';

      container.read(driverIdentityControllerProvider);
      await awaitRestored(container);

      final state = container.read(driverIdentityControllerProvider);
      expect(state.isSetupDone, isTrue);
      expect(state.rememberedCode, isNull);
      expect(state.isReturning, isFalse);
    });

    test('persistence: markSetupDone survives a rebuilt container on the '
        'SAME store', () async {
      await container
          .read(driverIdentityControllerProvider.notifier)
          .markSetupDone();

      // "Restart": a fresh controller over the same backing storage.
      final restarted = ProviderContainer(
        overrides: [driverIdentityStoreProvider.overrideWithValue(store)],
      );
      addTearDown(restarted.dispose);
      restarted.read(driverIdentityControllerProvider);
      await awaitRestored(restarted);

      expect(restarted.read(driverIdentityControllerProvider).isSetupDone,
          isTrue);
    });

    test('persistence: a remembered code survives a rebuilt container, and '
        'clearing on the fresh container forgets only the code', () async {
      await container
          .read(driverIdentityControllerProvider.notifier)
          .rememberDriver('AB-1234');

      final restarted = ProviderContainer(
        overrides: [driverIdentityStoreProvider.overrideWithValue(store)],
      );
      addTearDown(restarted.dispose);
      restarted.read(driverIdentityControllerProvider);
      await awaitRestored(restarted);
      expect(
        restarted.read(driverIdentityControllerProvider).rememberedCode,
        'AB-1234',
      );

      await restarted.read(driverIdentityControllerProvider.notifier).clearDriver();
      expect(store.storedDriverCode, isNull);
      expect(store.storedSetupDone, isNull,
          reason: 'clearDriver never plants a setup flag');
    });
  });

  group('driver actions (remember / change / clear)', () {
    late InMemoryDriverIdentityStore store;
    late ProviderContainer container;
    late DriverIdentityController notifier;

    setUp(() {
      store = InMemoryDriverIdentityStore();
      container = ProviderContainer(
        overrides: [driverIdentityStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      notifier = container.read(driverIdentityControllerProvider.notifier);
    });

    test('markSetupDone applies immediately and persists through the seam',
        () async {
      await notifier.markSetupDone();

      final state = container.read(driverIdentityControllerProvider);
      expect(state.isSetupDone, isTrue);
      expect(store.storedSetupDone, isTrue);
    });

    test('rememberDriver persists the code VERBATIM (the store is dumb; '
        'format validation is not this layer\'s job)', () async {
      await notifier.rememberDriver('ab-1234');

      expect(container.read(driverIdentityControllerProvider).rememberedCode,
          'ab-1234');
      expect(store.storedDriverCode, 'ab-1234',
          reason: 'lowercase/dash shape must not be touched on the way in');
    });

    test('change driver: remembering a new code overwrites the old one',
        () async {
      await notifier.rememberDriver('AB-1234');
      await notifier.rememberDriver('CD-5678');

      expect(container.read(driverIdentityControllerProvider).rememberedCode,
          'CD-5678');
      expect(store.storedDriverCode, 'CD-5678');
    });

    test('clearDriver forgets only the code; setupDone stays', () async {
      await notifier.markSetupDone();
      await notifier.rememberDriver('AB-1234');

      await notifier.clearDriver();

      final state = container.read(driverIdentityControllerProvider);
      expect(state.rememberedCode, isNull);
      expect(state.isSetupDone, isTrue);
      expect(store.storedDriverCode, isNull);
      expect(store.storedSetupDone, isTrue);
    });

    test('isReturning flips only when BOTH parts hold, through the whole '
        'lifecycle', () async {
      DriverIdentityState stateOf() =>
          container.read(driverIdentityControllerProvider);

      expect(stateOf().isReturning, isFalse, reason: 'fresh device');
      await notifier.markSetupDone();
      expect(stateOf().isReturning, isFalse,
          reason: 'setup done but no driver remembered yet');
      await notifier.rememberDriver('AB-1234');
      expect(stateOf().isReturning, isTrue,
          reason: 'setup done AND a code remembered');
      await notifier.clearDriver();
      expect(stateOf().isReturning, isFalse,
          reason: 'the driver was forgotten; setupDone alone is not enough');
    });
  });

  group('restore racing an explicit action (slow store)', () {
    test('a driver action made while the restore is still in flight wins',
        () async {
      final slow = DelayedDriverIdentityStore(
        InMemoryDriverIdentityStore()..values[driverCodeKey] = 'AB-1234',
        const Duration(milliseconds: 200),
      );
      final racing = ProviderContainer(
        overrides: [driverIdentityStoreProvider.overrideWithValue(slow)],
      );
      addTearDown(racing.dispose);

      // First read kicks the (slow) restore; the driver acts meanwhile.
      racing.read(driverIdentityControllerProvider);
      await racing
          .read(driverIdentityControllerProvider.notifier)
          .rememberDriver('CD-5678');
      // Deterministic: await the restore itself; the action must win.
      await awaitRestored(racing);

      expect(
        racing.read(driverIdentityControllerProvider).rememberedCode,
        'CD-5678',
        reason: 'the late restore must not clobber the explicit action',
      );
    });

    test('a clear made while the restore is still in flight wins', () async {
      final inner = InMemoryDriverIdentityStore()
        ..values[driverSetupDoneKey] = true
        ..values[driverCodeKey] = 'AB-1234';
      final slow = DelayedDriverIdentityStore(
        inner,
        const Duration(milliseconds: 200),
      );
      final racing = ProviderContainer(
        overrides: [driverIdentityStoreProvider.overrideWithValue(slow)],
      );
      addTearDown(racing.dispose);

      racing.read(driverIdentityControllerProvider);
      await racing
          .read(driverIdentityControllerProvider.notifier)
          .clearDriver();
      await awaitRestored(racing);

      final state = racing.read(driverIdentityControllerProvider);
      expect(state.rememberedCode, isNull,
          reason: 'the late restore must not resurrect the cleared code');
      // The whole-state "action wins" guard (LocaleController's rule)
      // discards the late restore entirely, so in-session setupDone is
      // whatever it was when the clear ran. Restore never writes, so
      // storage still carries the full stored picture for next launch.
      expect(inner.storedSetupDone, isTrue);
      expect(inner.storedDriverCode, isNull,
          reason: 'the clear\'s own write went through too — the action '
              'wins in persistence as well, not just in state');
    });
  });
}
