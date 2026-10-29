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
  String get shiftStartTitle => 'શિફ્ટ શરૂ કરો';

  @override
  String get vanLabel => 'વેન';

  @override
  String get pinLabel => 'પિન';

  @override
  String get routeSetByAdmin => '(એડમિન દ્વારા સેટ)';

  @override
  String get splashTagline => 'સ્વચ્છ શહેર, એક એક રૂટ.';

  @override
  String get welcomeTitle => 'સ્વાગત છે';

  @override
  String get welcomeBody => 'સફાઈ સાથી આજની શિફ્ટ માટે તૈયાર છે.';

  @override
  String get welcomeCta => 'ચાલો શરૂ કરીએ';

  @override
  String get dutyTitle => 'આજની ડ્યુટી';

  @override
  String get dutySubtitle => 'તમારી વેન સાથે જોડાઈને રૂટ શરૂ કરો.';

  @override
  String get startDuty => 'ડ્યુટી શરૂ કરો';

  @override
  String get gettingReady => 'રૂટ તૈયાર થઈ રહ્યો છે…';

  @override
  String get pickVanPrompt => 'તમારી વેન પસંદ કરો';

  @override
  String get vansEmpty => 'કોઈ વેન મળી નથી';

  @override
  String get vanListError => 'વેન લોડ થઈ શકી નથી';

  @override
  String get routeLabel => 'રૂટ';

  @override
  String get routeUnknown => 'રૂટ સેટ નથી';

  @override
  String get enterPinPrompt => '૪ અંકનો પિન દાખલ કરો';

  @override
  String get verifyPin => 'પિન ચકાસો';

  @override
  String get readyToStartInfo => 'વેન પુષ્ટ થઈ ગઈ. શરૂ કરવા તૈયાર.';

  @override
  String get startShift => 'શિફ્ટ શરૂ કરો';

  @override
  String get resumeShift => 'શિફ્ટ ફરી શરૂ કરો';

  @override
  String get wrongPin => 'પિન ખોટી છે. ફરી પ્રયાસ કરો.';

  @override
  String get pinLockedOut => 'ઘણા વધુ પ્રયાસો. કૃપા કરીને થોડી મિનિટો રાહ જુઓ.';

  @override
  String get shiftStartFailed =>
      'શિફ્ટ શરૂ થઈ શકી નથી. કનેક્શન તપાસીને ફરી પ્રયાસ કરો.';

  @override
  String get verificationUnavailable =>
      'ઓફિસ સર્વર સુધી પહોંચી શક્યા નથી. કનેક્શન તપાસીને ફરી પ્રયાસ કરો.';

  @override
  String get shiftStarted => 'શિફ્ટ શરૂ થઈ ગઈ';

  @override
  String get basicRouteTitle => 'તમારો રૂટ';

  @override
  String get trackingPending => 'વેન ટ્રેકિંગ આપોઆપ શરૂ થશે.';

  @override
  String get identityStartTitle => 'શિફ્ટ શરૂ કરો';

  @override
  String get identityCodeLabel => 'કોડ';

  @override
  String get identityCodeHint => 'XX-0000';

  @override
  String get identityCodeError => 'કોડ ખોટો છે. ફરી પ્રયાસ કરો.';

  @override
  String get identityCodeContinue => 'આગળ વધો';

  @override
  String get identityFieldName => 'નામ';

  @override
  String get identityFieldWards => 'વોર્ડ્સ';

  @override
  String get identityFieldPhone => 'ફોન';

  @override
  String identityWardsAllotted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count વોર્ડ સોંપાયા છે',
      one: '1 વોર્ડ સોંપાયો છે',
    );
    return '$_temp0';
  }

  @override
  String get identityNotFoundTitle => 'ડ્રાઇવર મળ્યો નથી';

  @override
  String get identityNotFoundBody => 'કોડ કચેરી સાથે ચકાસીને ફરી પ્રયાસ કરો.';

  @override
  String get identityLookupFailedTitle => 'કોડ ચકાસી શકાયો નથી';

  @override
  String get identityLookupFailedBody => 'કનેક્શન તપાસીને ફરી પ્રયાસ કરો.';

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
  String get trackingOpenLocationSettings => 'લોકેશન સેટિંગ્સ ખોલો';

  @override
  String get permissionAllow => 'મંજૂર';

  @override
  String get permissionNotNow => 'હાલ માટે નહીં';

  @override
  String get trackingPermissionLocationTitle => 'લોકેશન પહોંચ';

  @override
  String get trackingPermissionBackgroundTitle => 'બેકગ્રાઉન્ડ લોકેશન';

  @override
  String get trackingPermissionNotificationsTitle => 'નોટિફિકેશન';

  @override
  String get trackingPermissionBatteryTitle => 'બેટરી અપવાદ';

  @override
  String get mockLocationWarning =>
      'તમારો ફોન લોકેશન ખોટી રીતે બતાવી રહ્યો છે. ટ્રેકિંગ ચાલુ રહેશે, અને કચેરીને આ નોંધ દેખાશે.';

  @override
  String get pendingReportsTitle => 'પેંડિંગ રિપોર્ટ્સ';

  @override
  String get pendingReportsEmpty => 'કંઈ પેંડિંગ નથી';

  @override
  String get willRevisit => 'ફરી આવીશ';

  @override
  String get markDone => 'પૂરું થયું';

  @override
  String get languageChangeHint => 'ભાષા બદલો';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameGu => 'ગુજરાતી';

  @override
  String get liveRouteTitle => 'લાઇવ રૂટ';

  @override
  String get routeLoading => 'રૂટ લોડ થાય છે…';

  @override
  String get recenterMap => 'નકશો ફરી કેન્દ્રિત કરો';

  @override
  String get noticesBadgeTooltip => 'નોટિસ';

  @override
  String noticesUnreadSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'નોટિસ, $count ન વંચાયેલી',
      one: 'નોટિસ, 1 ન વંચાયેલી',
    );
    return '$_temp0';
  }

  @override
  String get endOfTripCardPlaceholder => 'શિફ્ટ પૂરી વખતે સારાંશ અહીં દેખાય';

  @override
  String routeProgress(int done, int total) {
    return '$total માંથી $done વોર્ડ થયા';
  }

  @override
  String get routeProgressTitle => 'રૂટ પગલાં';

  @override
  String ofTotalWardsDone(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'વોર્ડ પૂરા થયા',
      one: 'વોર્ડ પૂરું થયું',
    );
    return '$_temp0';
  }

  @override
  String get nextWardLabel => 'આગળનો વોર્ડ';

  @override
  String markWardDoneLabel(String wardName) {
    return 'વોર્ડ પૂરું કરો: $wardName';
  }

  @override
  String markWardDoneSemantic(String wardName) {
    return '$wardNameને પૂરું કરો';
  }

  @override
  String get noOpenShiftTrip => 'કોઈ ખુલ્લી શિફ્ટ ટ્રિપ નથી';

  @override
  String get wardListTitle => 'વોર્ડ્સ';

  @override
  String doneAtTime(String time) {
    return '$time વાગ્યે પૂરું થયું';
  }

  @override
  String get noWardsOnRoute => 'આ રૂટમાં કોઈ વોર્ડ નથી';

  @override
  String get noWardsOnRouteBody =>
      'આ રૂટમાં હજી કોઈ વોર્ડ સોંપવામાં આવ્યા નથી.';

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
  String get liveRouteMapSemantic => 'રૂટ મેપ, વેનની લાઇવ સ્થિતિ સાથે';

  @override
  String get vanMarkerSemantic => 'તમારી વેન';

  @override
  String get routeEmptyMessage => 'આ રૂટમાં કોઈ વોર્ડ નથી';

  @override
  String get routeMissingMessage => 'રૂટ મળ્યો નથી';

  @override
  String get markWardDone => 'વોર્ડ પૂરું કરો';

  @override
  String get markWardDoneFailed => 'નોંધણી થઈ શકી નથી. ફરી પ્રયાસ કરો.';

  @override
  String get markWardDoneNoTrip => 'કોઈ ખુલ્લી ટ્રિપ નથી';

  @override
  String get noticesTitle => 'નોટિસ';

  @override
  String get noticesEmpty => 'કોઈ નોટિસ નથી';

  @override
  String get noNoticesBody => 'તમારા રૂટ માટે હજી કોઈ નોટિસ નથી.';

  @override
  String get navRoute => 'રૂટ';

  @override
  String get navNotices => 'નોટિસ';

  @override
  String get navReports => 'રિપોર્ટ';

  @override
  String get endShiftPrimary => 'શિફ્ટ સમાપ્ત કરો';

  @override
  String get endShiftHint => 'તમામ વોર્ડ પૂરા — તમારી શિફ્ટ સમાપ્ત કરો';

  @override
  String endShiftDuration(num mins) {
    String _temp0 = intl.Intl.pluralLogic(
      mins,
      locale: localeName,
      other: 'રૂટ પર $mins મિનિટ',
      one: 'રૂટ પર 1 મિનિટ',
    );
    return '$_temp0';
  }

  @override
  String get shiftEnded => 'શિફ્ટ પૂરી થઈ';

  @override
  String get endShiftFailed => 'શિફ્ટ સમાપ્ત થઈ ન શક્યું. ફરી પ્રયાસ કરો.';

  @override
  String get settingsTitle => 'સેટિંગ્સ';

  @override
  String get settingsLanguage => 'ભાષા';

  @override
  String get settingsTheme => 'થીમ';

  @override
  String get themeLight => 'લાઇટ';

  @override
  String get themeDark => 'ડાર્ક';

  @override
  String get themeSystem => 'સિસ્ટમ';

  @override
  String get settingsVan => 'વેન';

  @override
  String get settingsNoVan => 'કનેક્ટ નથી';

  @override
  String get tripHistoryTitle => 'ટ્રિપ ઇતિહાસ';

  @override
  String get tripHistoryEmpty => 'હજી કોઈ ટ્રિપ નથી';

  @override
  String get tripHistoryEmptyBody =>
      'તમારી પહેલી શિફ્ટ પછી અહીં તમારી ટ્રિપ દેખાશે.';

  @override
  String get chipCompleted => 'પૂર્ણ';

  @override
  String get chipPartlyDone => 'અંશત પૂર્ણ';

  @override
  String get tripToday => 'આજ';

  @override
  String get tripYesterday => 'ગઈકાલ';

  @override
  String hoursMinutes(Object h, Object m) {
    return '$h ક $m મિ';
  }

  @override
  String wardsDoneOf(Object done, Object total) {
    return '$done પૈકી $total વોર્ડ';
  }

  @override
  String get tripActive => 'ચાલુ';

  @override
  String get helpAboutTitle => 'મદદ અને વિશે';

  @override
  String get helpAboutTagline =>
      'સફાઈ સાથી વેન ચાલકો માટે એપ. SFIC ડેમો માટે વિકસિત.';

  @override
  String get tripHistory => 'ટ્રિપ ઇતિહાસ';

  @override
  String get helpAndAbout => 'મદદ અને વિશે';

  @override
  String noticeDetailTimeAgo(Object mins) {
    return '$mins મિનિટ પહેલા';
  }

  @override
  String get noticeDetailAppliesToVan => 'આ વેન માટે લાગુ';

  @override
  String noticeDetailAppliesToWard(Object wardId) {
    return 'વોર્ડ $wardId માટે લાગુ';
  }

  @override
  String get noticeDetailAppliesToAll => 'તમામ વેન માટે લાગુ';

  @override
  String get noticeDetailGotIt => 'ઠીક છે';

  @override
  String reportDetailReportsToday(Object n) {
    return 'આજ $n રિપોર્ટ';
  }

  @override
  String reportDetailTimeAgo(Object mins) {
    return '$mins મિનિટ પહેલા';
  }

  @override
  String get reportDetailDone => 'પૂર્ણ થયું';

  @override
  String get reportDetailWillRevisit => 'ફરી આવીશ';

  @override
  String get reportDetailStatusOpen => 'ખુલ્લું';

  @override
  String get reportDetailStatusDone => 'પૂર્ણ થયું';

  @override
  String get reportDetailLocation => 'સ્થળ';

  @override
  String reportDetailWard(Object wardId) {
    return 'વોર્ડ $wardId';
  }

  @override
  String get complaintCategoryMissedCollection => 'મિસ્ડ કલેક્શન';

  @override
  String get complaintCategoryGarbageDump => 'કૂદરકતિ ઢગલો';

  @override
  String get complaintCategoryOpenGutter => 'ખુલ્લું નાળું';

  @override
  String get complaintCategoryOther => 'અન્ય';

  @override
  String get moreOptionsTitle => 'વિકલ્પો';

  @override
  String get moreOptionsSkipWard => 'વોર્ડ સ્કીપ કરો';

  @override
  String get moreOptionsOnBreak => 'બ્રેક પર';

  @override
  String get moreOptionsCallForHelp => 'મદદ માટે કોલ કરો';

  @override
  String get moreOptionsSettings => 'સેટિંગ્સ';

  @override
  String get skipWardTitle => 'વોર્ડ સ્કીપ કરો';

  @override
  String get skipWardConfirm => 'આ વોર્ડ સ્કીપ કરો';

  @override
  String get skipWardCancel => 'રદ કરો';

  @override
  String get skipWardWarning =>
      'આજના રૂટથી આ વોર્ડ દૂર કરવામાં આવશે. આ શિફ્ટમાં તેને વાપસી લાવી શકાશે નહિ.';

  @override
  String get onBreakTitle => 'બ્રેક પર';

  @override
  String get onBreakBody =>
      'તમારી શિફ્ટ સ્થાનિક રીતે પૌઝ થઈ ગઈ છે — ઓફિસ તમારા છેલ્લા સ્થાનને હજી જોઈ શકે છે. પરત ફર્યા પછી રિઝ્યુમ પર ટૅપ કરો.';

  @override
  String get onBreakResume => 'શિફ્ટ રિઝ્યુમ કરો';

  @override
  String get callForHelpTitle => 'મદદ માટે કોલ કરો';

  @override
  String get callForHelpBody => 'આજના રૂટમાં સહાય માટે ઓફિસને કોલ કરો.';

  @override
  String get callForHelpCall => 'ઓફિસને કોલ કરો';

  @override
  String get identityWelcomeBackTitle => 'ફરી સ્વાગત છે';

  @override
  String get identityWelcomeBackBody => 'આ ફોન તમને ઓળખે છે.';

  @override
  String get identityStartMyShift => 'મારી શિફ્ટ શરૂ કરો';

  @override
  String get identityChangeCode => 'બીજા ડ્રાઇવર?';
}
