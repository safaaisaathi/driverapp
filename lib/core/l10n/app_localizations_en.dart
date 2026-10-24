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
}
