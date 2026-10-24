/// F-D9 mock-location warning (PRD-2 0.13, `contract-notes` ruling 7).
///
/// The tracking engine latches `trips.mockLocationDetected = true` on the
/// open trip when the position provider reports a mocked fix. The LATCH is
/// the trips doc field itself (kill/restart safe; the app never writes
/// `false`), so this provider simply WATCHES that field — no extra local
/// state to desynchronise.
///
/// SELF-CONTAINED integration piece: [mockLocationWarningProvider] +
/// [MockLocationWarningBanner] are the whole surface. Ticket 06 builds D2
/// (`route_map`) and drops one line into its `Column`/`Stack` — see the
/// ticket report for the exact insertion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';

/// The mock-location LATCH for the van's open trip, read where it lives:
/// `trips.mockLocationDetected` (contract field). `true` for the rest of the
/// shift once a mock fix lands; never unset by the app.
///
/// Family keyed by [vanId] (the banner knows the van, not the trip). Override
/// with `tripsRepositoryProvider.overrideWithValue(FakeTripsRepository(...))`
/// in tests.
final mockLocationWarningProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, vanId) {
  // The screen-name shape the repository takes: the IST calendar day in
  // local Y/M/D fields (Today resolution, GLOSSARY).
  final ist = todayIST(DateTime.now());
  return ref
      .watch(tripsRepositoryProvider)
      .watchTripByVanIdAndDate(
        vanId: vanId,
        date: DateTime(ist.year, ist.month, ist.day),
      )
      .map((trip) => trip?.mockLocationDetected ?? false);
});

/// The localized in-app warning the driver sees while the latch is on:
/// "the office will see this" wording (contract ruling 7 — in-app only; the
/// push side is backend work).
class MockLocationWarningBanner extends ConsumerWidget {
  const MockLocationWarningBanner({
    required this.vanId,
    super.key,
  });

  final String vanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latched =
        ref.watch(mockLocationWarningProvider(vanId)).value ?? false;
    if (!latched) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      key: const Key('mock_location_banner'),
      child: MaterialBanner(
        content: Text(l10n.mockLocationWarning),
        leading: const Icon(Icons.warning_amber_rounded),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        actions: const <Widget>[SizedBox.shrink()],
      ),
    );
  }
}
