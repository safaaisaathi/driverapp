import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

/// PillNav — floating pill bottom nav
/// DESIGN.md Section 3.3 / 4.5
/// Driver: height 80, item circle 64
/// User: height 72, item circle 56
enum PillNavType { driver, user }

enum DriverNavItem { route, notices, reports }
enum UserNavItem { map, complaints, settings }

class PillNav extends ConsumerWidget {
  const PillNav.driver({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.labels,
    this.badges = const {DriverNavItem.notices: 0, DriverNavItem.reports: 0},
  })  : type = PillNavType.driver,
        userCurrentIndex = null,
        onTapUser = null,
        userBadges = const {};

  const PillNav.user({
    super.key,
    required this.userCurrentIndex,
    required this.onTapUser,
    required this.labels,
    this.userBadges = const {UserNavItem.complaints: 0},
  })  : type = PillNavType.user,
        currentIndex = null,
        onTap = null,
        badges = const {};

  final int? currentIndex;
  final int? userCurrentIndex;
  final ValueChanged<int>? onTap;
  final ValueChanged<int>? onTapUser;
  final Map<DriverNavItem, int> badges;
  final Map<UserNavItem, int> userBadges;
  final PillNavType type;

  /// Tab labels, caller-localized (CL-21). Driver: [Route, Notices, Reports]
  /// — User: [Map, Reports, Settings].
  final List<String> labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = type == PillNavType.driver
        ? [
            _PillNavItemConfig(
              icon: Icons.route,
              label: 'Route',
              index: 0,
              badgeCount: badges[DriverNavItem.route] ?? 0,
            ),
            _PillNavItemConfig(
              icon: Icons.notifications,
              label: labels[1],
              index: 1,
              badgeCount: badges[DriverNavItem.notices] ?? 0,
            ),
            _PillNavItemConfig(
              icon: Icons.assignment,
              label: labels[2],
              index: 2,
              badgeCount: badges[DriverNavItem.reports] ?? 0,
            ),
          ]
        : [
            _PillNavItemConfig(
              icon: Icons.map,
              label: labels[0],
              index: 0,
              badgeCount: userBadges[UserNavItem.map] ?? 0,
            ),
            _PillNavItemConfig(
              icon: Icons.report,
              label: labels[1],
              index: 1,
              badgeCount: userBadges[UserNavItem.complaints] ?? 0,
            ),
            _PillNavItemConfig(
              icon: Icons.settings,
              label: labels[2],
              index: 2,
              badgeCount: userBadges[UserNavItem.settings] ?? 0,
            ),
          ];

    final navHeight = type == PillNavType.driver ? AppSize.navHeightDriver : AppSize.navHeight;
    final itemSize = type == PillNavType.driver ? AppSize.navItemDriver : AppSize.navItem;
    final current = type == PillNavType.driver ? currentIndex : userCurrentIndex;
    final onItemTap = type == PillNavType.driver ? onTap : onTapUser;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.lg,
          bottom: AppSpace.lg,
        ),
        child: Container(
          height: navHeight,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: isDark ? AppElevation.elev2Dark : AppElevation.elev2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final config = entry.value;
              final isActive = current == index;

              return _PillNavItem(
                config: config,
                isActive: isActive,
                itemSize: itemSize,
                onTap: () => onItemTap?.call(index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _PillNavItemConfig {
  const _PillNavItemConfig({
    required this.icon,
    required this.label,
    required this.index,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int index;
  final int badgeCount;
}

class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.config,
    required this.isActive,
    required this.itemSize,
    this.onTap,
  });

  final _PillNavItemConfig config;
  final bool isActive;
  final double itemSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Semantics(
      label: config.label,
      selected: isActive,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          splashColor: c.primary.withValues(alpha: 0.08),
          highlightColor: c.primary.withValues(alpha: 0.04),
          child: Container(
            width: itemSize,
            height: itemSize,
            decoration: isActive
                ? BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Icon(
                    config.icon,
                    size: AppSize.icon,
                    color: isActive ? c.onPrimary : c.textMuted,
                    weight: 300,
                  ),
                ),
                if (config.badgeCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      decoration: BoxDecoration(
                        color: c.accentStrong,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          config.badgeCount > 9 ? '9+' : config.badgeCount.toString(),
                          style: t.attribution.copyWith(
                            color: c.onAccent,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}