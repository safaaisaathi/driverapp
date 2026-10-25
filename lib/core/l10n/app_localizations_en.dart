// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Driver App – Panchmahal';

  @override
  String get loading => 'Loading…';

  @override
  String get empty => 'Nothing here yet';

  @override
  String get error => 'Something went wrong';

  @override
  String get offline => 'You\'re offline';

  @override
  String get retry => 'Retry';

  @override
  String get trackingPermissionWhileInUseClaim =>
      'Tracking needs location access so your van can be seen on the live map.';

  @override
  String get trackingPermissionBackgroundClaim =>
      'Allow ‘All the time’ so tracking keeps working after the screen turns off.';

  @override
  String get trackingPermissionNotificationsClaim =>
      'Allow notifications so the ‘Tracking active’ message stays visible.';

  @override
  String get trackingPermissionBatteryClaim =>
      'Allow battery exception so tracking lasts your whole shift.';

  @override
  String get trackingPermissionDenied =>
      'Tracking is off. You can start it again later – your shift is safe.';

  @override
  String get trackingGpsOff =>
      'Phone location (GPS) is turned off. Turn it on and try again.';

  @override
  String get trackingNotificationTitle => 'Tracking active';

  @override
  String get trackingNotificationBody =>
      'Your van\'s location is shared while on shift.';

  @override
  String get liveRouteTitle => 'Live Route';

  @override
  String get noticesBadgeTooltip => 'Notices';

  @override
  String get endOfTripCardPlaceholder => 'End-of-trip summary appears here';

  @override
  String routeProgress(int done, int total) {
    return '$done of $total wards done';
  }

  @override
  String get nextWardChip => 'Next';

  @override
  String vanLastSeen(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Location updated $minutes min ago',
      one: 'Location updated 1 min ago',
      zero: 'Location updated moments ago',
    );
    return '$_temp0';
  }

  @override
  String get offlineShowingCached => 'Showing saved map data';

  @override
  String get routeEmptyMessage => 'This route has no wards';

  @override
  String get routeMissingMessage => 'Route not found';
}
