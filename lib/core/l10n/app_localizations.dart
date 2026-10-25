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

  /// No description provided for @trackingPermissionWhileInUseClaim.
  ///
  /// In en, this message translates to:
  /// **'Tracking needs location access so your van can be seen on the live map.'**
  String get trackingPermissionWhileInUseClaim;

  /// No description provided for @trackingPermissionBackgroundClaim.
  ///
  /// In en, this message translates to:
  /// **'Allow ‘All the time’ so tracking keeps working after the screen turns off.'**
  String get trackingPermissionBackgroundClaim;

  /// No description provided for @trackingPermissionNotificationsClaim.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications so the ‘Tracking active’ message stays visible.'**
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

  /// No description provided for @noticesBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get noticesBadgeTooltip;

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
