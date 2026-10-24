// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Gujarati (`gu`).
class AppLocalizationsGu extends AppLocalizations {
  AppLocalizationsGu([String locale = 'gu']) : super(locale);

  @override
  String get appTitle => 'ડ્રાઇવર એપ – પંચમહાલ';

  @override
  String get loading => 'લોડ થાય છે…';

  @override
  String get empty => 'અહીં હજી કંઈ નથી';

  @override
  String get error => 'કંઈક ખોટું થયું';

  @override
  String get offline => 'તમે ઓફલાઇન છો';

  @override
  String get retry => 'ફરી પ્રયાસ કરો';

  @override
  String get trackingPermissionWhileInUseClaim =>
      'ટ્રેકિંગ માટે લોકેશનની પરવાનગી આપો, જેથી તમારી વેન લાઇવ નકશામાં દેખાય.';

  @override
  String get trackingPermissionBackgroundClaim =>
      'લોકેશનને ‘બધી વખત’ મંજૂરી આપો, જેથી સ્ક્રીન બંધ થાય પછી પણ ટ્રેકિંગ ચાલુ રહે.';

  @override
  String get trackingPermissionNotificationsClaim =>
      '‘ટ્રેકિંગ ચાલુ છે’ સંદેશ દેખાય તે માટે નોટિફિકેશન મંજૂર કરો.';

  @override
  String get trackingPermissionBatteryClaim =>
      'તમારી શિફ્ટ દરમિયાન ટ્રેકિંગ ચાલુ રહે તે માટે બેટરી બચતનો અપવાદ મંજૂર કરો.';

  @override
  String get trackingPermissionDenied =>
      'ટ્રેકિંગ બંધ છે. તમે પછી ફરી શરૂ કરી શકશો – તમારી શિફ્ટ સુરક્ષિત છે.';

  @override
  String get trackingGpsOff =>
      'ફોનનું લોકેશન (GPS) બંધ છે. તે ચાલુ કરો અને ફરી પ્રયાસ કરો.';

  @override
  String get trackingNotificationTitle => 'ટ્રેકિંગ ચાલુ છે';

  @override
  String get trackingNotificationBody =>
      'શિફ્ટ દરમિયાન તમારી વેનની લોકેશન શેર થાય છે.';

  @override
  String get mockLocationWarning =>
      'તમારો ફોન લોકેશન ખોટી રીતે બતાવી રહ્યો છે. ટ્રેકિંગ ચાલુ રહેશે, અને કચેરીને આ નોંધ દેખાશે.';
}
