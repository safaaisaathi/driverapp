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
  String get shiftStartTitle => 'Shift start';

  @override
  String get pickVanPrompt => 'Pick your van';

  @override
  String get vansEmpty => 'No vans found';

  @override
  String get vanListError => 'Couldn\'t load vans';

  @override
  String get routeLabel => 'Route';

  @override
  String get routeUnknown => 'Route not set';

  @override
  String get enterPinPrompt => 'Enter the 4-digit PIN';

  @override
  String get verifyPin => 'Verify PIN';

  @override
  String get readyToStartInfo => 'Van confirmed. Ready to start.';

  @override
  String get startShift => 'Start Shift';

  @override
  String get resumeShift => 'Resume shift';

  @override
  String get wrongPin => 'Wrong PIN. Try again.';

  @override
  String get pinLockedOut =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get shiftStartFailed =>
      'Couldn\'t start the shift. Check the connection and try again.';

  @override
  String get verificationUnavailable =>
      'Couldn\'t reach the office server. Check the connection and try again.';

  @override
  String get shiftStarted => 'Shift started';

  @override
  String get basicRouteTitle => 'Your route';

  @override
  String get trackingPending => 'Van tracking will start automatically.';

  @override
  String get trackingPermissionWhileInUseClaim =>
      'Tracking needs location access so your van can be seen on the live map.';

  @override
  String get trackingPermissionBackgroundClaim =>
      'Allow \'All the time\' so tracking keeps working after the screen turns off.';

  @override
  String get trackingPermissionNotificationsClaim =>
      'Allow notifications so the \'Tracking active\' message stays visible.';

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
  String get mockLocationWarning =>
      'Your phone is faking its location. Tracking continues, and the office will see this notice.';

  @override
  String get pendingReportsTitle => 'Pending reports';

  @override
  String get pendingReportsEmpty => 'Nothing pending';

  @override
  String get willRevisit => 'Will Revisit';

  @override
  String get markDone => 'Done';

  @override
  String get languageChangeHint => 'Change language';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameGu => 'ગુજરાતી';

  @override
  String get liveRouteTitle => 'Live Route';

  @override
  String get routeLoading => 'Loading route…';

  @override
  String get recenterMap => 'Recenter map';

  @override
  String get noticesBadgeTooltip => 'Notices';

  @override
  String get endOfTripCardPlaceholder => 'End-of-trip summary appears here';

  @override
  String routeProgress(int done, int total) {
    return '$done of $total wards done';
  }

  @override
  String get routeProgressTitle => 'Route Progress';

  @override
  String ofTotalWardsDone(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'wards done',
      one: 'ward done',
    );
    return '$_temp0';
  }

  @override
  String get nextWardLabel => 'Next ward';

  @override
  String markWardDoneLabel(String wardName) {
    return 'Mark Ward Done: $wardName';
  }

  @override
  String markWardDoneSemantic(String wardName) {
    return 'Mark $wardName as done';
  }

  @override
  String get noOpenShiftTrip => 'No open shift trip';

  @override
  String get wardListTitle => 'Wards';

  @override
  String doneAtTime(String time) {
    return 'Done at $time';
  }

  @override
  String get noWardsOnRoute => 'No wards on this route';

  @override
  String get noWardsOnRouteBody => 'The route has no wards assigned yet.';

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

  @override
  String get markWardDone => 'Mark Ward Done';

  @override
  String get markWardDoneFailed => 'Couldn\'t record. Try again.';

  @override
  String get markWardDoneNoTrip => 'No open shift trip';

  @override
  String get noticesTitle => 'Notices';

  @override
  String get noticesEmpty => 'No notices';

  @override
  String get noNoticesBody => 'There are no notices for your route right now.';

  @override
  String get navRoute => 'Route';

  @override
  String get navNotices => 'Notices';

  @override
  String get navReports => 'Reports';

  @override
  String get endShiftPrimary => 'End Shift';

  @override
  String get endShiftHint => 'All wards done — end your shift';

  @override
  String endShiftDuration(num mins) {
    String _temp0 = intl.Intl.pluralLogic(
      mins,
      locale: localeName,
      other: '$mins min on route',
      one: '1 min on route',
    );
    return '$_temp0';
  }

  @override
  String get shiftEnded => 'Shift ended';

  @override
  String get endShiftFailed => 'Couldn\'t end the shift. Try again.';
}
