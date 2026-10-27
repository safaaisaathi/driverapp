/// D-Settings — Settings screen (wireframe WF-21).
///
/// A chevron header + large headline, then cards: Language (ગુ/EN),
/// Theme (Light/Dark/System — WF-21; dark variant exists on WF-14),
/// the shift's Van (plate · route), Trip history →, Help and about →.
///
/// Local slice: every control works offline on app-owned state — the
/// language and theme choices persist through app-owned SharedPreferences
/// seams; the van/route row is a plain repository read. Nothing here
/// writes backend data or talks to a Cloud Function.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../settings_flow.dart';
import 'trip_history_screen.dart';
import 'help_about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale =
        (ref.watch(localeControllerProvider) ?? const Locale('en'))
            .languageCode;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: AppIconButton(
                key: const Key('settings.back'),
                onPressed: () => Navigator.of(context).pop(),
                icon: Icons.arrow_back,
                size: 48,
                semanticsLabel: MaterialLocalizations.of(context)
                    .backButtonTooltip,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsTitle,
              key: const Key('settings.title'),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 24),

            // Language card (F-D10; the same persisted choice as the D1
            // toggle and the D2 glass bar — one more control on it).
            _SettingsCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsLanguage,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'gu',
                        label: Text('ગુ'),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text('EN'),
                      ),
                    ],
                    selected: {locale},
                    onSelectionChanged: (selection) => ref
                        .read(localeControllerProvider.notifier)
                        .setLocale(Locale(selection.first)),
                    showSelectedIcon: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Theme card — Light / Dark / System (wireframe WF-21).
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    l10n.settingsTheme,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: 4),
                  SegmentedButton<ThemeMode>(
                    key: const Key('settings.themeSegments'),
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l10n.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeDark),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l10n.themeSystem),
                      ),
                    ],
                    selected: {ref.watch(themeModeControllerProvider)},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeControllerProvider.notifier)
                        .setThemeMode(selection.first),
                    showSelectedIcon: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // The shift's van (plate · route). Degrades to "Not connected"
            // with no running session — never reads a wrong van.
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    l10n.settingsVan,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                  ),
                  _VanRowLabel(
                    van: ref.watch(settingsVanProvider),
                    route: ref.watch(settingsRouteProvider),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SettingsCard(
              child: ListTile(
                key: const Key('settings.tripHistoryRow'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.tripHistory),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const TripHistoryScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _SettingsCard(
              child: ListTile(
                key: const Key('settings.helpRow'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.helpAndAbout),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const HelpAboutScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VanRowLabel extends ConsumerWidget {
  final AsyncValue<Van?> van;
  final AsyncValue<RouteModel?> route;

  const _VanRowLabel({required this.van, required this.route});

  static const _vanRow = Key('settings.vanRow');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    // Loading: skeleton-ish plain muted text; the screen is reachable
    // in-shift where both reads are already warm.
    final vanValue = van.value;
    final routeValue = route.value;
    if (van.isLoading || route.isLoading) {
      return Text(
        '…',
        key: const Key('settings.vanLoading'),
        style: textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.4,
              ),
        ),
      );
    }
    if (vanValue == null) {
      return Text(
        l10n.settingsNoVan,
        key: _vanRow,
        style: textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.45,
              ),
        ),
      );
    }
    final label = routeValue == null
        ? vanValue.plateNo
        : '${vanValue.plateNo} · ${routeValue.name}';
    return Text(
      label,
      key: _vanRow,
      style: textTheme.bodyLarge,
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
