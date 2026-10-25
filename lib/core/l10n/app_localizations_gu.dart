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
  String get liveRouteTitle => 'લાઇવ રૂટ';

  @override
  String get noticesBadgeTooltip => 'નોટિસ';

  @override
  String get endOfTripCardPlaceholder => 'શિફ્ટ પૂરી વખતે સારાંશ અહીં દેખાય';

  @override
  String routeProgress(int done, int total) {
    return '$total માંથી $done વોર્ડ થયા';
  }

  @override
  String get nextWardChip => 'આગળ';

  @override
  String vanLastSeen(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'લોકેશન $minutes મિનિટ પહેલાં અપડેટ થયું',
      one: 'લોકેશન 1 મિનિટ પહેલાં અપડેટ થયું',
      zero: 'લોકેશન હમણાં જ અપડેટ થયું',
    );
    return '$_temp0';
  }

  @override
  String get offlineShowingCached => 'સેવ થયેલો નકશો દેખાય છે';

  @override
  String get routeEmptyMessage => 'આ રૂટમાં કોઈ વોર્ડ નથી';

  @override
  String get routeMissingMessage => 'રૂટ મળ્યો નથી';
}
