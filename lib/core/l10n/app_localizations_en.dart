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
  String get vanLabel => 'Van';

  @override
  String get pinLabel => 'PIN';

  @override
  String get routeSetByAdmin => '(set by admin)';

  @override
  String get splashTagline => 'Clean city, one route at a time.';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeBody => 'Safaai Saathi is ready for today\'s shift.';

  @override
  String get welcomeCta => 'Get started';

  @override
  String get dutyTitle => 'Today\'s duty';

  @override
  String get dutySubtitle => 'Connect with your van and start the route.';

  @override
  String get startDuty => 'Start duty';

  @override
  String get gettingReady => 'Getting the route ready…';

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
  String get identityStartTitle => 'Start shift';

  @override
  String get identityCodeLabel => 'Code';

  @override
  String get identityCodeHint => 'XX-0000';

  @override
  String get identityCodeError => 'Wrong code. Try again.';

  @override
  String get identityCodeContinue => 'Continue';

  @override
  String get identityFieldName => 'Name';

  @override
  String get identityFieldWards => 'Wards';

  @override
  String get identityFieldPhone => 'Phone';

  @override
  String identityWardsAllotted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wards allotted',
      one: '1 ward allotted',
    );
    return '$_temp0';
  }

  @override
  String get identityNotFoundTitle => 'Driver not found';

  @override
  String get identityNotFoundBody =>
      'Check the code with the office and try again.';

  @override
  String get identityLookupFailedTitle => 'Couldn\'t check the code';

  @override
  String get identityLookupFailedBody => 'Check your connection and try again.';

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
  String get trackingOpenLocationSettings => 'Open location settings';

  @override
  String get permissionAllow => 'Allow';

  @override
  String get permissionNotNow => 'Not now';

  @override
  String get trackingPermissionLocationTitle => 'Location access';

  @override
  String get trackingPermissionBackgroundTitle => 'Background location';

  @override
  String get trackingPermissionNotificationsTitle => 'Notifications';

  @override
  String get trackingPermissionBatteryTitle => 'Battery exception';

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
  String noticesUnreadSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notices, $count unread',
      one: 'Notices, 1 unread',
    );
    return '$_temp0';
  }

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
  String get liveRouteMapSemantic => 'Route map with the van\'s live position';

  @override
  String get vanMarkerSemantic => 'Your van';

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

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get settingsVan => 'Van';

  @override
  String get settingsNoVan => 'Not connected';

  @override
  String get tripHistoryTitle => 'Trip history';

  @override
  String get tripHistoryEmpty => 'No trips yet';

  @override
  String get tripHistoryEmptyBody =>
      'Your past shifts will show here after your first shift.';

  @override
  String get chipCompleted => 'Completed';

  @override
  String get chipPartlyDone => 'Partly done';

  @override
  String get tripToday => 'Today';

  @override
  String get tripYesterday => 'Yesterday';

  @override
  String hoursMinutes(Object h, Object m) {
    return '$h h $m min';
  }

  @override
  String wardsDoneOf(Object done, Object total) {
    return '$done of $total wards';
  }

  @override
  String get tripActive => 'Running';

  @override
  String get helpAboutTitle => 'Help and about';

  @override
  String get helpAboutTagline =>
      'Safai Sathi driver app for Safai Sathi vans. Developed for the SFIC demo.';

  @override
  String get tripHistory => 'Trip history';

  @override
  String get helpAndAbout => 'Help and about';

  @override
  String noticeDetailTimeAgo(Object mins) {
    return '$mins min ago';
  }

  @override
  String get noticeDetailAppliesToVan => 'Applies to this van';

  @override
  String noticeDetailAppliesToWard(Object wardId) {
    return 'Applies to Ward $wardId';
  }

  @override
  String get noticeDetailAppliesToAll => 'Applies to all vans';

  @override
  String get noticeDetailGotIt => 'Got it';

  @override
  String reportDetailReportsToday(Object n) {
    return '$n reports today';
  }

  @override
  String reportDetailTimeAgo(Object mins) {
    return '$mins min ago';
  }

  @override
  String get reportDetailDone => 'Done';

  @override
  String get reportDetailWillRevisit => 'Will Revisit';

  @override
  String get reportDetailStatusOpen => 'Open';

  @override
  String get reportDetailStatusDone => 'Done';

  @override
  String get reportDetailLocation => 'Location';

  @override
  String reportDetailWard(Object wardId) {
    return 'Ward $wardId';
  }

  @override
  String get complaintCategoryMissedCollection => 'Missed collection';

  @override
  String get complaintCategoryGarbageDump => 'Garbage dump';

  @override
  String get complaintCategoryOpenGutter => 'Open gutter';

  @override
  String get complaintCategoryOther => 'Other';

  @override
  String get moreOptionsTitle => 'More options';

  @override
  String get moreOptionsSkipWard => 'Skip ward';

  @override
  String get moreOptionsOnBreak => 'On break';

  @override
  String get moreOptionsCallForHelp => 'Call for help';

  @override
  String get moreOptionsSettings => 'Settings';

  @override
  String get skipWardTitle => 'Skip ward';

  @override
  String get skipWardConfirm => 'Skip this ward';

  @override
  String get skipWardCancel => 'Cancel';

  @override
  String get skipWardWarning =>
      'This ward will be dropped from today\'s route. It cannot be restored this shift.';

  @override
  String get onBreakTitle => 'On break';

  @override
  String get onBreakBody =>
      'Your shift is paused locally — the office can still see your last location. Tap Resume shift when you\'re back.';

  @override
  String get onBreakResume => 'Resume shift';

  @override
  String get callForHelpTitle => 'Call for help';

  @override
  String get callForHelpBody => 'Call the office for help on today\'s route.';

  @override
  String get callForHelpCall => 'Call office';

  @override
  String get identityWelcomeBackTitle => 'Welcome back';

  @override
  String get identityWelcomeBackBody => 'This phone remembers you.';

  @override
  String get identityStartMyShift => 'Start my Shift';

  @override
  String get identityChangeCode => 'Different driver?';
}
