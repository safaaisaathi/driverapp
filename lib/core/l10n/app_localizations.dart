import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver App – Panchmahal'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get empty;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get offline;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @shiftStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift start'**
  String get shiftStartTitle;

  /// No description provided for @vanLabel.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get vanLabel;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @routeSetByAdmin.
  ///
  /// In en, this message translates to:
  /// **'(set by admin)'**
  String get routeSetByAdmin;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Clean city, one route at a time.'**
  String get splashTagline;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Safaai Saathi is ready for today\'s shift.'**
  String get welcomeBody;

  /// No description provided for @welcomeCta.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeCta;

  /// No description provided for @dutyTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s duty'**
  String get dutyTitle;

  /// No description provided for @dutySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with your van and start the route.'**
  String get dutySubtitle;

  /// No description provided for @startDuty.
  ///
  /// In en, this message translates to:
  /// **'Start duty'**
  String get startDuty;

  /// No description provided for @gettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting the route ready…'**
  String get gettingReady;

  /// No description provided for @pickVanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Pick your van'**
  String get pickVanPrompt;

  /// No description provided for @vansEmpty.
  ///
  /// In en, this message translates to:
  /// **'No vans found'**
  String get vansEmpty;

  /// No description provided for @vanListError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load vans'**
  String get vanListError;

  /// No description provided for @routeLabel.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeLabel;

  /// No description provided for @routeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Route not set'**
  String get routeUnknown;

  /// No description provided for @enterPinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit PIN'**
  String get enterPinPrompt;

  /// No description provided for @verifyPin.
  ///
  /// In en, this message translates to:
  /// **'Verify PIN'**
  String get verifyPin;

  /// No description provided for @readyToStartInfo.
  ///
  /// In en, this message translates to:
  /// **'Van confirmed. Ready to start.'**
  String get readyToStartInfo;

  /// No description provided for @startShift.
  ///
  /// In en, this message translates to:
  /// **'Start Shift'**
  String get startShift;

  /// No description provided for @resumeShift.
  ///
  /// In en, this message translates to:
  /// **'Resume shift'**
  String get resumeShift;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. Try again.'**
  String get wrongPin;

  /// No description provided for @pinLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get pinLockedOut;

  /// No description provided for @shiftStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the shift. Check the connection and try again.'**
  String get shiftStartFailed;

  /// No description provided for @verificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the office server. Check the connection and try again.'**
  String get verificationUnavailable;

  /// No description provided for @shiftStarted.
  ///
  /// In en, this message translates to:
  /// **'Shift started'**
  String get shiftStarted;

  /// No description provided for @basicRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Your route'**
  String get basicRouteTitle;

  /// No description provided for @trackingPending.
  ///
  /// In en, this message translates to:
  /// **'Van tracking will start automatically.'**
  String get trackingPending;

  /// No description provided for @identityStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start shift'**
  String get identityStartTitle;

  /// No description provided for @identityCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get identityCodeLabel;

  /// No description provided for @identityCodeHint.
  ///
  /// In en, this message translates to:
  /// **'XX-0000'**
  String get identityCodeHint;

  /// No description provided for @identityCodeError.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Try again.'**
  String get identityCodeError;

  /// No description provided for @identityCodeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get identityCodeContinue;

  /// No description provided for @identityFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get identityFieldName;

  /// No description provided for @identityFieldWards.
  ///
  /// In en, this message translates to:
  /// **'Wards'**
  String get identityFieldWards;

  /// No description provided for @identityFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get identityFieldPhone;

  /// No description provided for @identityWardsAllotted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ward allotted} other{{count} wards allotted}}'**
  String identityWardsAllotted(int count);

  /// No description provided for @identityNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver not found'**
  String get identityNotFoundTitle;

  /// No description provided for @identityNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Check the code with the office and try again.'**
  String get identityNotFoundBody;

  /// No description provided for @identityLookupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check the code'**
  String get identityLookupFailedTitle;

  /// No description provided for @identityLookupFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get identityLookupFailedBody;

  /// No description provided for @trackingPermissionWhileInUseClaim.
  ///
  /// In en, this message translates to:
  /// **'Tracking needs location access so your van can be seen on the live map.'**
  String get trackingPermissionWhileInUseClaim;

  /// No description provided for @trackingPermissionBackgroundClaim.
  ///
  /// In en, this message translates to:
  /// **'Allow \'All the time\' so tracking keeps working after the screen turns off.'**
  String get trackingPermissionBackgroundClaim;

  /// No description provided for @trackingPermissionNotificationsClaim.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications so the \'Tracking active\' message stays visible.'**
  String get trackingPermissionNotificationsClaim;

  /// No description provided for @trackingPermissionBatteryClaim.
  ///
  /// In en, this message translates to:
  /// **'Allow battery exception so tracking lasts your whole shift.'**
  String get trackingPermissionBatteryClaim;

  /// No description provided for @trackingPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Tracking is off. You can start it again later – your shift is safe.'**
  String get trackingPermissionDenied;

  /// No description provided for @trackingGpsOff.
  ///
  /// In en, this message translates to:
  /// **'Phone location (GPS) is turned off. Turn it on and try again.'**
  String get trackingGpsOff;

  /// No description provided for @trackingNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracking active'**
  String get trackingNotificationTitle;

  /// No description provided for @trackingNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Your van\'s location is shared while on shift.'**
  String get trackingNotificationBody;

  /// No description provided for @trackingOpenLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open location settings'**
  String get trackingOpenLocationSettings;

  /// No description provided for @permissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permissionAllow;

  /// No description provided for @permissionNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get permissionNotNow;

  /// No description provided for @trackingPermissionLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get trackingPermissionLocationTitle;

  /// No description provided for @trackingPermissionBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get trackingPermissionBackgroundTitle;

  /// No description provided for @trackingPermissionNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get trackingPermissionNotificationsTitle;

  /// No description provided for @trackingPermissionBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery exception'**
  String get trackingPermissionBatteryTitle;

  /// No description provided for @mockLocationWarning.
  ///
  /// In en, this message translates to:
  /// **'Your phone is faking its location. Tracking continues, and the office will see this notice.'**
  String get mockLocationWarning;

  /// No description provided for @pendingReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending reports'**
  String get pendingReportsTitle;

  /// No description provided for @pendingReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing pending'**
  String get pendingReportsEmpty;

  /// No description provided for @willRevisit.
  ///
  /// In en, this message translates to:
  /// **'Will Revisit'**
  String get willRevisit;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get markDone;

  /// No description provided for @languageChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get languageChangeHint;

  /// No description provided for @languageNameEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// No description provided for @languageNameGu.
  ///
  /// In en, this message translates to:
  /// **'ગુજરાતી'**
  String get languageNameGu;

  /// No description provided for @liveRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Route'**
  String get liveRouteTitle;

  /// No description provided for @routeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading route…'**
  String get routeLoading;

  /// No description provided for @recenterMap.
  ///
  /// In en, this message translates to:
  /// **'Recenter map'**
  String get recenterMap;

  /// No description provided for @noticesBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get noticesBadgeTooltip;

  /// No description provided for @noticesUnreadSemantic.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Notices, 1 unread} other{Notices, {count} unread}}'**
  String noticesUnreadSemantic(int count);

  /// No description provided for @endOfTripCardPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'End-of-trip summary appears here'**
  String get endOfTripCardPlaceholder;

  /// No description provided for @routeProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} wards done'**
  String routeProgress(int done, int total);

  /// No description provided for @routeProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Route Progress'**
  String get routeProgressTitle;

  /// No description provided for @ofTotalWardsDone.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{ward done} other{wards done}}'**
  String ofTotalWardsDone(int total);

  /// No description provided for @nextWardLabel.
  ///
  /// In en, this message translates to:
  /// **'Next ward'**
  String get nextWardLabel;

  /// No description provided for @markWardDoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark Ward Done: {wardName}'**
  String markWardDoneLabel(String wardName);

  /// No description provided for @markWardDoneSemantic.
  ///
  /// In en, this message translates to:
  /// **'Mark {wardName} as done'**
  String markWardDoneSemantic(String wardName);

  /// No description provided for @noOpenShiftTrip.
  ///
  /// In en, this message translates to:
  /// **'No open shift trip'**
  String get noOpenShiftTrip;

  /// No description provided for @wardListTitle.
  ///
  /// In en, this message translates to:
  /// **'Wards'**
  String get wardListTitle;

  /// No description provided for @doneAtTime.
  ///
  /// In en, this message translates to:
  /// **'Done at {time}'**
  String doneAtTime(String time);

  /// No description provided for @noWardsOnRoute.
  ///
  /// In en, this message translates to:
  /// **'No wards on this route'**
  String get noWardsOnRoute;

  /// No description provided for @noWardsOnRouteBody.
  ///
  /// In en, this message translates to:
  /// **'The route has no wards assigned yet.'**
  String get noWardsOnRouteBody;

  /// No description provided for @nextWardChip.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextWardChip;

  /// No description provided for @vanLastSeen.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =0{Location updated moments ago} =1{Location updated 1 min ago} other{Location updated {minutes} min ago}}'**
  String vanLastSeen(int minutes);

  /// No description provided for @offlineShowingCached.
  ///
  /// In en, this message translates to:
  /// **'Showing saved map data'**
  String get offlineShowingCached;

  /// No description provided for @liveRouteMapSemantic.
  ///
  /// In en, this message translates to:
  /// **'Route map with the van\'s live position'**
  String get liveRouteMapSemantic;

  /// No description provided for @vanMarkerSemantic.
  ///
  /// In en, this message translates to:
  /// **'Your van'**
  String get vanMarkerSemantic;

  /// No description provided for @routeEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'This route has no wards'**
  String get routeEmptyMessage;

  /// No description provided for @routeMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Route not found'**
  String get routeMissingMessage;

  /// No description provided for @markWardDone.
  ///
  /// In en, this message translates to:
  /// **'Mark Ward Done'**
  String get markWardDone;

  /// No description provided for @markWardDoneFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t record. Try again.'**
  String get markWardDoneFailed;

  /// No description provided for @markWardDoneNoTrip.
  ///
  /// In en, this message translates to:
  /// **'No open shift trip'**
  String get markWardDoneNoTrip;

  /// No description provided for @noticesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get noticesTitle;

  /// No description provided for @noticesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notices'**
  String get noticesEmpty;

  /// No description provided for @noNoticesBody.
  ///
  /// In en, this message translates to:
  /// **'There are no notices for your route right now.'**
  String get noNoticesBody;

  /// No description provided for @navRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get navRoute;

  /// No description provided for @navNotices.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get navNotices;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @endShiftPrimary.
  ///
  /// In en, this message translates to:
  /// **'End Shift'**
  String get endShiftPrimary;

  /// No description provided for @endShiftHint.
  ///
  /// In en, this message translates to:
  /// **'All wards done — end your shift'**
  String get endShiftHint;

  /// No description provided for @endShiftDuration.
  ///
  /// In en, this message translates to:
  /// **'{mins, plural, =1{1 min on route} other{{mins} min on route}}'**
  String endShiftDuration(num mins);

  /// No description provided for @shiftEnded.
  ///
  /// In en, this message translates to:
  /// **'Shift ended'**
  String get shiftEnded;

  /// No description provided for @endShiftFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t end the shift. Try again.'**
  String get endShiftFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @settingsVan.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get settingsVan;

  /// No description provided for @settingsNoVan.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get settingsNoVan;

  /// No description provided for @tripHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip history'**
  String get tripHistoryTitle;

  /// No description provided for @tripHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get tripHistoryEmpty;

  /// No description provided for @tripHistoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your past shifts will show here after your first shift.'**
  String get tripHistoryEmptyBody;

  /// No description provided for @chipCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get chipCompleted;

  /// No description provided for @chipPartlyDone.
  ///
  /// In en, this message translates to:
  /// **'Partly done'**
  String get chipPartlyDone;

  /// No description provided for @tripToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tripToday;

  /// No description provided for @tripYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get tripYesterday;

  /// No description provided for @hoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{h} h {m} min'**
  String hoursMinutes(Object h, Object m);

  /// No description provided for @wardsDoneOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} wards'**
  String wardsDoneOf(Object done, Object total);

  /// No description provided for @tripActive.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get tripActive;

  /// No description provided for @helpAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'Help and about'**
  String get helpAboutTitle;

  /// No description provided for @helpAboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Safai Sathi driver app for Safai Sathi vans. Developed for the SFIC demo.'**
  String get helpAboutTagline;

  /// No description provided for @tripHistory.
  ///
  /// In en, this message translates to:
  /// **'Trip history'**
  String get tripHistory;

  /// No description provided for @helpAndAbout.
  ///
  /// In en, this message translates to:
  /// **'Help and about'**
  String get helpAndAbout;

  /// No description provided for @noticeDetailTimeAgo.
  ///
  /// In en, this message translates to:
  /// **'{mins} min ago'**
  String noticeDetailTimeAgo(Object mins);

  /// No description provided for @noticeDetailAppliesToVan.
  ///
  /// In en, this message translates to:
  /// **'Applies to this van'**
  String get noticeDetailAppliesToVan;

  /// No description provided for @noticeDetailAppliesToWard.
  ///
  /// In en, this message translates to:
  /// **'Applies to Ward {wardId}'**
  String noticeDetailAppliesToWard(Object wardId);

  /// No description provided for @noticeDetailAppliesToAll.
  ///
  /// In en, this message translates to:
  /// **'Applies to all vans'**
  String get noticeDetailAppliesToAll;

  /// No description provided for @noticeDetailGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get noticeDetailGotIt;

  /// No description provided for @reportDetailReportsToday.
  ///
  /// In en, this message translates to:
  /// **'{n} reports today'**
  String reportDetailReportsToday(Object n);

  /// No description provided for @reportDetailTimeAgo.
  ///
  /// In en, this message translates to:
  /// **'{mins} min ago'**
  String reportDetailTimeAgo(Object mins);

  /// No description provided for @reportDetailDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reportDetailDone;

  /// No description provided for @reportDetailWillRevisit.
  ///
  /// In en, this message translates to:
  /// **'Will Revisit'**
  String get reportDetailWillRevisit;

  /// No description provided for @reportDetailStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get reportDetailStatusOpen;

  /// No description provided for @reportDetailStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reportDetailStatusDone;

  /// No description provided for @reportDetailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get reportDetailLocation;

  /// No description provided for @reportDetailWard.
  ///
  /// In en, this message translates to:
  /// **'Ward {wardId}'**
  String reportDetailWard(Object wardId);

  /// No description provided for @complaintCategoryMissedCollection.
  ///
  /// In en, this message translates to:
  /// **'Missed collection'**
  String get complaintCategoryMissedCollection;

  /// No description provided for @complaintCategoryGarbageDump.
  ///
  /// In en, this message translates to:
  /// **'Garbage dump'**
  String get complaintCategoryGarbageDump;

  /// No description provided for @complaintCategoryOpenGutter.
  ///
  /// In en, this message translates to:
  /// **'Open gutter'**
  String get complaintCategoryOpenGutter;

  /// No description provided for @complaintCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get complaintCategoryOther;

  /// No description provided for @moreOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsTitle;

  /// No description provided for @moreOptionsSkipWard.
  ///
  /// In en, this message translates to:
  /// **'Skip ward'**
  String get moreOptionsSkipWard;

  /// No description provided for @moreOptionsOnBreak.
  ///
  /// In en, this message translates to:
  /// **'On break'**
  String get moreOptionsOnBreak;

  /// No description provided for @moreOptionsCallForHelp.
  ///
  /// In en, this message translates to:
  /// **'Call for help'**
  String get moreOptionsCallForHelp;

  /// No description provided for @moreOptionsSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moreOptionsSettings;

  /// No description provided for @skipWardTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip ward'**
  String get skipWardTitle;

  /// No description provided for @skipWardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Skip this ward'**
  String get skipWardConfirm;

  /// No description provided for @skipWardCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get skipWardCancel;

  /// No description provided for @skipWardWarning.
  ///
  /// In en, this message translates to:
  /// **'This ward will be dropped from today\'s route. It cannot be restored this shift.'**
  String get skipWardWarning;

  /// No description provided for @onBreakTitle.
  ///
  /// In en, this message translates to:
  /// **'On break'**
  String get onBreakTitle;

  /// No description provided for @onBreakBody.
  ///
  /// In en, this message translates to:
  /// **'Your shift is paused locally — the office can still see your last location. Tap Resume shift when you\'re back.'**
  String get onBreakBody;

  /// No description provided for @onBreakResume.
  ///
  /// In en, this message translates to:
  /// **'Resume shift'**
  String get onBreakResume;

  /// No description provided for @callForHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Call for help'**
  String get callForHelpTitle;

  /// No description provided for @callForHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Call the office for help on today\'s route.'**
  String get callForHelpBody;

  /// No description provided for @callForHelpCall.
  ///
  /// In en, this message translates to:
  /// **'Call office'**
  String get callForHelpCall;

  /// No description provided for @identityWelcomeBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get identityWelcomeBackTitle;

  /// No description provided for @identityWelcomeBackBody.
  ///
  /// In en, this message translates to:
  /// **'This phone remembers you.'**
  String get identityWelcomeBackBody;

  /// No description provided for @identityStartMyShift.
  ///
  /// In en, this message translates to:
  /// **'Start my Shift'**
  String get identityStartMyShift;

  /// No description provided for @identityChangeCode.
  ///
  /// In en, this message translates to:
  /// **'Different driver?'**
  String get identityChangeCode;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
