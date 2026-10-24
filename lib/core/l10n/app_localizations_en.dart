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
}
