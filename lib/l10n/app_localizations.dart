import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Medito'**
  String get appName;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @unableToOpenPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Unable to open privacy policy'**
  String get unableToOpenPrivacyPolicy;

  /// No description provided for @meditoUrl.
  ///
  /// In en, this message translates to:
  /// **'https://meditofoundation.org/'**
  String get meditoUrl;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @backgroundSoundDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download. Tap to try again.'**
  String get backgroundSoundDownloadFailed;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @removed.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get removed;

  /// No description provided for @meditationProducts.
  ///
  /// In en, this message translates to:
  /// **'Shop to Support'**
  String get meditationProducts;

  /// No description provided for @blackFridayTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Free Meditation'**
  String get blackFridayTitle;

  /// No description provided for @blackFridaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'This Black Friday, support free meditation for everyone. Your purchase helps keep Medito free and accessible to millions worldwide'**
  String get blackFridaySubtitle;

  /// No description provided for @blackFridaySeeAllButton.
  ///
  /// In en, this message translates to:
  /// **'Visit store'**
  String get blackFridaySeeAllButton;

  /// No description provided for @fromPrefix.
  ///
  /// In en, this message translates to:
  /// **'From '**
  String get fromPrefix;

  /// No description provided for @emptyDownloadsMessage.
  ///
  /// In en, this message translates to:
  /// **'It looks like you haven\'t downloaded anything yet. Downloads are useful to save mobile data or to access sessions in places without signal.'**
  String get emptyDownloadsMessage;

  /// No description provided for @meanWhileListen.
  ///
  /// In en, this message translates to:
  /// **'Meanwhile, you can listen to your'**
  String get meanWhileListen;

  /// No description provided for @retrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get retrying;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @statsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Stats updated'**
  String get statsSuccess;

  /// No description provided for @shareStatsText.
  ///
  /// In en, this message translates to:
  /// **'Discover calmness for FREE with #Medito I\'ve found my inner peace; now it\'s your turn! Join me on this mindful journey and start exploring today 💜 Download https://medito.app #Calm #Meditation #Headspace'**
  String get shareStatsText;

  /// No description provided for @backgroundSounds.
  ///
  /// In en, this message translates to:
  /// **'Background Sound'**
  String get backgroundSounds;

  /// No description provided for @x06.
  ///
  /// In en, this message translates to:
  /// **'x0.6'**
  String get x06;

  /// No description provided for @x07.
  ///
  /// In en, this message translates to:
  /// **'x0.7'**
  String get x07;

  /// No description provided for @x08.
  ///
  /// In en, this message translates to:
  /// **'x0.8'**
  String get x08;

  /// No description provided for @x09.
  ///
  /// In en, this message translates to:
  /// **'x0.9'**
  String get x09;

  /// No description provided for @x1.
  ///
  /// In en, this message translates to:
  /// **'x1'**
  String get x1;

  /// No description provided for @searchMeditations.
  ///
  /// In en, this message translates to:
  /// **'Search meditations'**
  String get searchMeditations;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @tapToShare.
  ///
  /// In en, this message translates to:
  /// **'Tap to share'**
  String get tapToShare;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'id'**
  String get id;

  /// No description provided for @env.
  ///
  /// In en, this message translates to:
  /// **'env'**
  String get env;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'email'**
  String get email;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'appVersion'**
  String get appVersion;

  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'deviceModel'**
  String get deviceModel;

  /// No description provided for @deviceOs.
  ///
  /// In en, this message translates to:
  /// **'deviceOs'**
  String get deviceOs;

  /// No description provided for @devicePlatform.
  ///
  /// In en, this message translates to:
  /// **'devicePlatform'**
  String get devicePlatform;

  /// No description provided for @buildNumber.
  ///
  /// In en, this message translates to:
  /// **'buildNumber'**
  String get buildNumber;

  /// Accessibility label for dismiss/close buttons
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @debugInfo.
  ///
  /// In en, this message translates to:
  /// **'Debug info'**
  String get debugInfo;

  /// Text indicating where to write in debug reports
  ///
  /// In en, this message translates to:
  /// **'--- Write below this line ---'**
  String get writeBelowThisLine;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'👋 Welcome'**
  String get welcome;

  /// No description provided for @thanksForSharing.
  ///
  /// In en, this message translates to:
  /// **'Thanks for sharing  💜'**
  String get thanksForSharing;

  /// No description provided for @thanksForSharingNeutral.
  ///
  /// In en, this message translates to:
  /// **'Happy face'**
  String get thanksForSharingNeutral;

  /// No description provided for @thanksForSharingHappy.
  ///
  /// In en, this message translates to:
  /// **'Neutral face'**
  String get thanksForSharingHappy;

  /// No description provided for @thanksForSharingSad.
  ///
  /// In en, this message translates to:
  /// **'Sad face'**
  String get thanksForSharingSad;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @hey.
  ///
  /// In en, this message translates to:
  /// **'👋 Hey'**
  String get hey;

  /// No description provided for @someThingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get someThingWentWrong;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid Email.'**
  String get invalidEmail;

  /// No description provided for @emailForReceipt.
  ///
  /// In en, this message translates to:
  /// **'Email for Receipt'**
  String get emailForReceipt;

  /// No description provided for @emailForReceiptDescription.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send your donation receipt to this email address. This helps us identify your payment for support and records.'**
  String get emailForReceiptDescription;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Field is Required'**
  String get fieldRequired;

  /// No description provided for @invalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid Input'**
  String get invalidInput;

  /// No description provided for @connectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Error connection timeout'**
  String get connectionTimeout;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @badRequest.
  ///
  /// In en, this message translates to:
  /// **'Bad request'**
  String get badRequest;

  /// No description provided for @unauthorizedRequest.
  ///
  /// In en, this message translates to:
  /// **'Session expired - please sign in again'**
  String get unauthorizedRequest;

  /// No description provided for @accessForbidden.
  ///
  /// In en, this message translates to:
  /// **'Access forbidden'**
  String get accessForbidden;

  /// No description provided for @apiNotFound.
  ///
  /// In en, this message translates to:
  /// **'Api not found'**
  String get apiNotFound;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred. Either we\'re having issues or you\'re offline.'**
  String get anErrorOccurred;

  /// No description provided for @unableToLoadAudio.
  ///
  /// In en, this message translates to:
  /// **'Unable to load audio. Please go back and try again'**
  String get unableToLoadAudio;

  /// No description provided for @loadingError.
  ///
  /// In en, this message translates to:
  /// **'It looks like you\'re offline or there was little hiccup from our end'**
  String get loadingError;

  /// No description provided for @timeout.
  ///
  /// In en, this message translates to:
  /// **'Oops! It seems like there was an error. If the problem persists, Close the app and try again.'**
  String get timeout;

  /// No description provided for @connectivityError.
  ///
  /// In en, this message translates to:
  /// **'Make sure you are connected to the internet to use Medito'**
  String get connectivityError;

  /// No description provided for @howDoYouFeel.
  ///
  /// In en, this message translates to:
  /// **'How do you feel after this session?'**
  String get howDoYouFeel;

  /// No description provided for @yourFeedbackHelpsUs.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps us improve our content and allows you to reflect on your experience.'**
  String get yourFeedbackHelpsUs;

  /// No description provided for @didYouKnow.
  ///
  /// In en, this message translates to:
  /// **'Did you know?'**
  String get didYouKnow;

  /// No description provided for @meditoReliesOnYourDonationsToSurvive.
  ///
  /// In en, this message translates to:
  /// **'Medito relies only on your donations to survive. We produce free content to help humanity.'**
  String get meditoReliesOnYourDonationsToSurvive;

  /// Body text for daily meditation reminder notifications
  ///
  /// In en, this message translates to:
  /// **'It\'s time for your daily meditation. Take a moment to relax and focus.'**
  String get reminderNotificationBody;

  /// Title for daily meditation reminder notifications
  ///
  /// In en, this message translates to:
  /// **'Daily Meditation Reminder'**
  String get reminderNotificationTitle;

  /// No description provided for @pickTimeHelpText.
  ///
  /// In en, this message translates to:
  /// **'Select your daily reminder time'**
  String get pickTimeHelpText;

  /// No description provided for @reminderNotificationScheduled.
  ///
  /// In en, this message translates to:
  /// **'Reminder notification scheduled at'**
  String get reminderNotificationScheduled;

  /// No description provided for @dailyReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder'**
  String get dailyReminderTitle;

  /// No description provided for @setFor.
  ///
  /// In en, this message translates to:
  /// **'Set for'**
  String get setFor;

  /// No description provided for @signInSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign in / Sign up'**
  String get signInSignUp;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @reminderNotificationCleared.
  ///
  /// In en, this message translates to:
  /// **'Reminder cancelled'**
  String get reminderNotificationCleared;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @requestPermission.
  ///
  /// In en, this message translates to:
  /// **'Request Permission'**
  String get requestPermission;

  /// No description provided for @reminderPermissions.
  ///
  /// In en, this message translates to:
  /// **'Reminder Permissions'**
  String get reminderPermissions;

  /// No description provided for @weNeedYourPermissionReminder.
  ///
  /// In en, this message translates to:
  /// **'We need permission to send you reminders about tracking your meditation progress. This helps you maintain consistency in your practice.'**
  String get weNeedYourPermissionReminder;

  /// No description provided for @syncWithHealth.
  ///
  /// In en, this message translates to:
  /// **'Sync with Apple Health'**
  String get syncWithHealth;

  /// No description provided for @syncWithHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Sync with Health Connect'**
  String get syncWithHealthConnect;

  /// No description provided for @permissionExplanation.
  ///
  /// In en, this message translates to:
  /// **'Permissions set. To change them, go to Settings > Privacy and Security > Health > Medito'**
  String get permissionExplanation;

  /// No description provided for @permissionExplanationAndroid.
  ///
  /// In en, this message translates to:
  /// **'Permissions set. To change them, open Health Connect from your device settings.'**
  String get permissionExplanationAndroid;

  /// No description provided for @healthConnectNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is required to sync. Install it from the Play Store?'**
  String get healthConnectNotInstalled;

  /// No description provided for @confirmDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirmDeletionTitle;

  /// No description provided for @confirmDeletionFromPlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Already Downloaded'**
  String get confirmDeletionFromPlayerTitle;

  /// No description provided for @confirmDeletionFromPlayerMessage.
  ///
  /// In en, this message translates to:
  /// **'This meditation is already in your downloads. Do you want to delete it?'**
  String get confirmDeletionFromPlayerMessage;

  /// No description provided for @confirmDeletionMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get confirmDeletionMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @debugInfoCopied.
  ///
  /// In en, this message translates to:
  /// **'Debug info copied to clipboard'**
  String get debugInfoCopied;

  /// No description provided for @goToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Go to Downloads'**
  String get goToDownloads;

  /// No description provided for @signInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sign in successful'**
  String get signInSuccess;

  /// No description provided for @signInError.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Please try again.'**
  String get signInError;

  /// No description provided for @backgroundSoundsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Background sounds are disabled for this track'**
  String get backgroundSoundsDisabled;

  /// No description provided for @neww.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get neww;

  /// No description provided for @statsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load stats. Please try again later.'**
  String get statsLoadError;

  /// No description provided for @statsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading stats...'**
  String get statsLoading;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @statsErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get statsErrorRetry;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get currentStreak;

  /// No description provided for @longestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest Streak'**
  String get longestStreak;

  /// No description provided for @consistencyScore.
  ///
  /// In en, this message translates to:
  /// **'Consistency Score'**
  String get consistencyScore;

  /// No description provided for @totalTracksCompleted.
  ///
  /// In en, this message translates to:
  /// **'Total Tracks Completed'**
  String get totalTracksCompleted;

  /// No description provided for @totalTimeListened.
  ///
  /// In en, this message translates to:
  /// **'Total Time Listened'**
  String get totalTimeListened;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get day;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hours;

  /// No description provided for @hoursFull.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hoursFull;

  /// No description provided for @hourFull.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get hourFull;

  /// Short placeholder text for duration input
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @minute.
  ///
  /// In en, this message translates to:
  /// **'minute'**
  String get minute;

  /// No description provided for @showConsistencyScore.
  ///
  /// In en, this message translates to:
  /// **'Show Consistency Score'**
  String get showConsistencyScore;

  /// No description provided for @showCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Show Current Streak'**
  String get showCurrentStreak;

  /// No description provided for @alwaysShowStreakOnHomepage.
  ///
  /// In en, this message translates to:
  /// **'Always show streak on homepage'**
  String get alwaysShowStreakOnHomepage;

  /// No description provided for @displayPreferenceSaved.
  ///
  /// In en, this message translates to:
  /// **'Display preference saved'**
  String get displayPreferenceSaved;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @signUpLogInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Medito'**
  String get signUpLogInTitle;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountTitle;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Error message for invalid email format
  ///
  /// In en, this message translates to:
  /// **'Invalid Email.'**
  String get invalidEmailError;

  /// No description provided for @createAccountButtonText.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountButtonText;

  /// No description provided for @createAccountLogInButtonText.
  ///
  /// In en, this message translates to:
  /// **'Sign in or Sign up'**
  String get createAccountLogInButtonText;

  /// No description provided for @sendMeMyPasswordText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sendMeMyPasswordText;

  /// No description provided for @logInButtonText.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get logInButtonText;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get authenticationFailed;

  /// No description provided for @invalidVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code. Please try again.'**
  String get invalidVerificationCode;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get errorPrefix;

  /// No description provided for @retryInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Retry in {seconds} s'**
  String retryInSeconds(Object seconds);

  /// No description provided for @resendCodeInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
  String resendCodeInSeconds(Object seconds);

  /// No description provided for @byContinuingAgreeTo.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get byContinuingAgreeTo;

  /// No description provided for @andText.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andText;

  /// No description provided for @streakFreezeEarned.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You earned a streak freeze for reaching a 7-day milestone!'**
  String get streakFreezeEarned;

  /// No description provided for @emailVerificationText.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a code by email to verify your account'**
  String get emailVerificationText;

  /// No description provided for @createAccountBenefits.
  ///
  /// In en, this message translates to:
  /// **'• Track your mindfulness journey\n• Never lose your meditation progress\n• Build a lasting meditation practice 💜'**
  String get createAccountBenefits;

  /// No description provided for @loginBenefits.
  ///
  /// In en, this message translates to:
  /// **'• Download your previously saved data\\n• Continue your meditation journey from where you left off'**
  String get loginBenefits;

  /// No description provided for @accountTransitionWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Wait!'**
  String get accountTransitionWarningTitle;

  /// No description provided for @loginWarningQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to continue with this email?'**
  String get loginWarningQuestion;

  /// No description provided for @loginWarningExplanation.
  ///
  /// In en, this message translates to:
  /// **'If you already have a Medito account:\n• Your previous meditation data will be downloaded\n• Your current unsaved progress will be lost\n\nIf you\'re new to Medito:\n• A new account will be created\n• Your current progress will be saved to this account'**
  String get loginWarningExplanation;

  /// No description provided for @createNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get createNewAccount;

  /// No description provided for @continueLogin.
  ///
  /// In en, this message translates to:
  /// **'Yes, continue'**
  String get continueLogin;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @userProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get userProfileTitle;

  /// No description provided for @userProfileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email:'**
  String get userProfileEmailLabel;

  /// No description provided for @signOutButtonText.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutButtonText;

  /// No description provided for @signOutSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'You have been signed out successfully'**
  String get signOutSuccessMessage;

  /// No description provided for @signOutErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out. Please try again.'**
  String get signOutErrorMessage;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone and you must follow the instructions on the next page.'**
  String get deleteAccountConfirmation;

  /// No description provided for @deleteAccountButtonText.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountButtonText;

  /// No description provided for @accountMarkedForDeletion.
  ///
  /// In en, this message translates to:
  /// **'Your account has been marked for deletion.'**
  String get accountMarkedForDeletion;

  /// No description provided for @deleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account.'**
  String get deleteAccountError;

  /// No description provided for @accountMarkedForDeletionError.
  ///
  /// In en, this message translates to:
  /// **'This account has been marked for deletion and cannot be accessed.'**
  String get accountMarkedForDeletionError;

  /// No description provided for @faqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqTitle;

  /// No description provided for @editStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit stats'**
  String get editStatsTitle;

  /// No description provided for @telegramTitle.
  ///
  /// In en, this message translates to:
  /// **'Join our Telegram community'**
  String get telegramTitle;

  /// No description provided for @whatsappTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow us on WhatsApp'**
  String get whatsappTitle;

  /// No description provided for @donateTitle.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donateTitle;

  /// No description provided for @contactUsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUsTitle;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @stepTitle.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get stepTitle;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @loadingPath.
  ///
  /// In en, this message translates to:
  /// **'Loading your path...'**
  String get loadingPath;

  /// No description provided for @pathLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load path. Please try again.'**
  String get pathLoadError;

  /// No description provided for @stepCompleted.
  ///
  /// In en, this message translates to:
  /// **'Step completed!'**
  String get stepCompleted;

  /// No description provided for @stepCompletionError.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete step. Please try again.'**
  String get stepCompletionError;

  /// No description provided for @meditatedOutsideApp.
  ///
  /// In en, this message translates to:
  /// **'You meditated outside the app? Listen to the last unlocked session to unlock the next step in the path'**
  String get meditatedOutsideApp;

  /// No description provided for @enterMeditationDuration.
  ///
  /// In en, this message translates to:
  /// **'Please enter the duration of your meditation outside the app'**
  String get enterMeditationDuration;

  /// No description provided for @meditationMarkingError.
  ///
  /// In en, this message translates to:
  /// **'Failed to mark meditation. Please try again.'**
  String get meditationMarkingError;

  /// No description provided for @listenToUnlockNextStep.
  ///
  /// In en, this message translates to:
  /// **'Listen to the last unlocked session to unlock the next step in the app'**
  String get listenToUnlockNextStep;

  /// No description provided for @unknownTaskType.
  ///
  /// In en, this message translates to:
  /// **'Unknown task type'**
  String get unknownTaskType;

  /// No description provided for @invalidDuration.
  ///
  /// In en, this message translates to:
  /// **'Invalid duration. Please enter a positive number.'**
  String get invalidDuration;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @journalEntry.
  ///
  /// In en, this message translates to:
  /// **'Journal Entry'**
  String get journalEntry;

  /// No description provided for @writeYourJournalEntryHere.
  ///
  /// In en, this message translates to:
  /// **'Write your journal entry here...'**
  String get writeYourJournalEntryHere;

  /// No description provided for @journalEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Journal entry saved'**
  String get journalEntrySaved;

  /// No description provided for @sessionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Session completed successfully!'**
  String get sessionCompleted;

  /// No description provided for @taskUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update task. Please try again.'**
  String get taskUpdateError;

  /// No description provided for @syncingPath.
  ///
  /// In en, this message translates to:
  /// **'Syncing your progress...'**
  String get syncingPath;

  /// No description provided for @stepLocked.
  ///
  /// In en, this message translates to:
  /// **'Complete previous steps to unlock'**
  String get stepLocked;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @tapToReadArticle.
  ///
  /// In en, this message translates to:
  /// **'Tap to read article'**
  String get tapToReadArticle;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get sunday;

  /// No description provided for @dailyPracticeMessage.
  ///
  /// In en, this message translates to:
  /// **'Practicing daily grows your streak, but it also makes you more mindful and happier!'**
  String get dailyPracticeMessage;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get dayStreak;

  /// No description provided for @dailyQuote.
  ///
  /// In en, this message translates to:
  /// **'Daily Quote'**
  String get dailyQuote;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'You are now in offline mode due to an error.'**
  String get offlineMode;

  /// No description provided for @addToSiri.
  ///
  /// In en, this message translates to:
  /// **'Add to Siri'**
  String get addToSiri;

  /// No description provided for @shareTrack.
  ///
  /// In en, this message translates to:
  /// **'Share Track'**
  String get shareTrack;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @shareTrackText.
  ///
  /// In en, this message translates to:
  /// **'Take a moment to breathe. Try this meditation session: \"{trackName}\" on Medito. {link}'**
  String shareTrackText(Object link, Object trackName);

  /// No description provided for @sharePackText.
  ///
  /// In en, this message translates to:
  /// **'Check out {packName} on Medito! {link} #Meditation #Mindfulness'**
  String sharePackText(Object link, Object packName);

  /// No description provided for @followingDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Following deep link...'**
  String get followingDeepLink;

  /// No description provided for @invalidDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid deep link'**
  String get invalidDeepLink;

  /// No description provided for @deepLinkError.
  ///
  /// In en, this message translates to:
  /// **'Unable to handle deep link'**
  String get deepLinkError;

  /// No description provided for @statsInitError.
  ///
  /// In en, this message translates to:
  /// **'Stats sync may have failed. Please check your connection.'**
  String get statsInitError;

  /// No description provided for @appInitError.
  ///
  /// In en, this message translates to:
  /// **'App initialization failed. Entering offline mode.'**
  String get appInitError;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get noConnection;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAsGuest;

  /// No description provided for @isMonthlyDonor.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get isMonthlyDonor;

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get otpLabel;

  /// No description provided for @invalidOtpError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 6-digit code'**
  String get invalidOtpError;

  /// No description provided for @otpSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check your email for the verification code'**
  String get otpSentSuccess;

  /// No description provided for @otpInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we just sent to'**
  String get otpInstructions;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get the code? Resend it'**
  String get resendCode;

  /// No description provided for @verifyOtpButtonText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get verifyOtpButtonText;

  /// No description provided for @warningTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warningTitle;

  /// No description provided for @localStatsWarning.
  ///
  /// In en, this message translates to:
  /// **'Signing into a new account will result in the loss of your current local stats. Do you wish to proceed?'**
  String get localStatsWarning;

  /// No description provided for @proceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get proceed;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Resource not found'**
  String get errorNotFound;

  /// No description provided for @requestOtpBeforeDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Please request an OTP first before using a deep link'**
  String get requestOtpBeforeDeepLink;

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @carouselTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get carouselTitle;

  /// No description provided for @quoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Quote'**
  String get quoteTitle;

  /// No description provided for @customization.
  ///
  /// In en, this message translates to:
  /// **'Customisation'**
  String get customization;

  /// No description provided for @customiseHomeLayout.
  ///
  /// In en, this message translates to:
  /// **'Organize Home Layout'**
  String get customiseHomeLayout;

  /// No description provided for @featuresIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Features & Integrations'**
  String get featuresIntegrations;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @supportCommunity.
  ///
  /// In en, this message translates to:
  /// **'Support & Community'**
  String get supportCommunity;

  /// No description provided for @helpLegal.
  ///
  /// In en, this message translates to:
  /// **'Help & Legal'**
  String get helpLegal;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @restorePreviousStats.
  ///
  /// In en, this message translates to:
  /// **'Restore previous stats'**
  String get restorePreviousStats;

  /// No description provided for @restorePreviousStatsExplainer.
  ///
  /// In en, this message translates to:
  /// **'Pick a snapshot to restore. Snapshots are saved automatically when your stats sync, and the most recent 20 are kept on this device — including snapshots taken from other accounts you\'ve signed into here.'**
  String get restorePreviousStatsExplainer;

  /// No description provided for @noBackupsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No stats snapshots are stored on this device yet.'**
  String get noBackupsAvailable;

  /// No description provided for @backupSummary.
  ///
  /// In en, this message translates to:
  /// **'Streak {streak} · {sessions, plural, =1{1 session} other{{sessions} sessions}} · {minutes} min'**
  String backupSummary(int streak, int sessions, int minutes);

  /// No description provided for @restoreStatsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore these stats?'**
  String get restoreStatsConfirmTitle;

  /// No description provided for @restoreStatsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your current stats on this device will be replaced with the selected snapshot, and the snapshot will be uploaded for the currently signed-in account. This can\'t be undone.'**
  String get restoreStatsConfirmBody;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreStatsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Stats restored'**
  String get restoreStatsSuccess;

  /// No description provided for @restoreStatsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore stats. Please try again.'**
  String get restoreStatsFailed;

  /// No description provided for @daysSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day selected} other{{count} days selected}}'**
  String daysSelected(int count);

  /// No description provided for @newStreak.
  ///
  /// In en, this message translates to:
  /// **'New streak'**
  String get newStreak;

  /// No description provided for @newSessions.
  ///
  /// In en, this message translates to:
  /// **'New sessions'**
  String get newSessions;

  /// No description provided for @addSessionsToSelectedDays.
  ///
  /// In en, this message translates to:
  /// **'Add sessions to selected days'**
  String get addSessionsToSelectedDays;

  /// No description provided for @addSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 session} other{Add {count} sessions}}'**
  String addSessionsTitle(int count);

  /// No description provided for @daysAlreadyHaveSession.
  ///
  /// In en, this message translates to:
  /// **'{filled, plural, =1{1 of {total} days already has a session and will be skipped.} other{{filled} of {total} days already have a session and will be skipped.}}'**
  String daysAlreadyHaveSession(int filled, int total);

  /// No description provided for @minutesPerDayOptional.
  ///
  /// In en, this message translates to:
  /// **'Minutes per day (optional)'**
  String get minutesPerDayOptional;

  /// Title for the onboarding section in settings
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get onboarding;

  /// No description provided for @enableNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay on Track with Meditation Reminders'**
  String get enableNotificationsTitle;

  /// No description provided for @enableNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications so you never miss a session.'**
  String get enableNotificationsBody;

  /// Notifications screen title for users who want to learn to meditate (intent: learn_properly)
  ///
  /// In en, this message translates to:
  /// **'Keep the learning going'**
  String get enableNotificationsTitleLearn;

  /// Notifications screen body for users who want to learn to meditate (intent: learn_properly)
  ///
  /// In en, this message translates to:
  /// **'A daily reminder is the single biggest thing that helps beginners stick with it.'**
  String get enableNotificationsBodyLearn;

  /// Notifications screen title for users who want to build a habit (intent: build_habit)
  ///
  /// In en, this message translates to:
  /// **'Build the habit you\'re after'**
  String get enableNotificationsTitleHabit;

  /// Notifications screen body for users who want to build a habit (intent: build_habit)
  ///
  /// In en, this message translates to:
  /// **'People who set a reminder are far more likely to meditate regularly.'**
  String get enableNotificationsBodyHabit;

  /// Notifications screen title for users managing stress, sleep, or emotions (intent: stress_sleep_emotions)
  ///
  /// In en, this message translates to:
  /// **'Make it part of your day'**
  String get enableNotificationsTitleStress;

  /// Notifications screen body for users managing stress, sleep, or emotions (intent: stress_sleep_emotions)
  ///
  /// In en, this message translates to:
  /// **'Just a few minutes daily is enough to start feeling the difference.'**
  String get enableNotificationsBodyStress;

  /// No description provided for @enableNotificationsCta.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotificationsCta;

  /// Timestamp shown on a fake iOS notification preview, mirroring iOS's 'now' label for a notification that just arrived
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get notificationPreviewTimestamp;

  /// Title of the fake notification shown in the onboarding notifications screen preview
  ///
  /// In en, this message translates to:
  /// **'A quieter mind starts here'**
  String get notificationPreviewTitleB;

  /// Body of the fake notification shown in the onboarding notifications screen preview
  ///
  /// In en, this message translates to:
  /// **'Your daily breath is waiting. Just tap to begin.'**
  String get notificationPreviewBodyB;

  /// Question above the time-of-day chips in the onboarding notifications screen (chips arm of the reminder experiment)
  ///
  /// In en, this message translates to:
  /// **'When will you meditate?'**
  String get reminderChipsQuestion;

  /// Time-of-day chip label; shown with a concrete time, e.g. 'Morning · 8:00 AM'
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get reminderSlotMorning;

  /// Time-of-day chip label; shown with a concrete time, e.g. 'Afternoon · 1:00 PM'. CURRENTLY UNUSED — the afternoon preset was swapped for reminderSlotNight, and is kept so that swap is a one-line revert.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get reminderSlotAfternoon;

  /// Time-of-day chip label; shown with a concrete time, e.g. 'Evening · 8:00 PM'
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get reminderSlotEvening;

  /// Time-of-day chip label; shown with a concrete time, e.g. 'Night · 10:00 PM'
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get reminderSlotNight;

  /// Option below the time-of-day chips that opens a time picker
  ///
  /// In en, this message translates to:
  /// **'Pick my own time'**
  String get reminderSlotCustom;

  /// Title of the dialog shown when notification permission is permanently denied, so no OS prompt can be raised and the phone's settings are the only route
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off'**
  String get notificationsBlockedTitle;

  /// Body of the dialog shown when notification permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'Medito can\'t send reminders because notifications are switched off for the app in your phone\'s settings. You can switch them back on there.'**
  String get notificationsBlockedBody;

  /// Button that opens the phone's settings app on the Medito page
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Call to action replacing 'Turn on Smart Reminders' when notification permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'Turn On in Settings'**
  String get turnOnInSettings;

  /// Subtitle on the settings smart-reminder tile when notification permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'Switched off in phone settings'**
  String get notificationsBlockedSubtitle;

  /// Title of the confirmation dialog shown before the OS notification permission prompt on the end-screen reminder card
  ///
  /// In en, this message translates to:
  /// **'One quick thing'**
  String get reminderPrimerTitle;

  /// Body of the confirmation dialog shown before the OS notification permission prompt
  ///
  /// In en, this message translates to:
  /// **'Your phone will ask you to allow notifications next. Say yes so that we can send you a daily nudge to meditate.'**
  String get reminderPrimerBody;

  /// Button on the pre-permission dialog that proceeds to the OS notification permission prompt
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get reminderPrimerContinue;

  /// Feedback shown when the user opens the custom time picker and dismisses it without choosing, so the tap is not a silent dead end
  ///
  /// In en, this message translates to:
  /// **'No time picked yet — choose one above, or skip for now.'**
  String get reminderCustomCancelled;

  /// No description provided for @onboardingBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'One Setting, Smoother Meditations'**
  String get onboardingBatteryTitle;

  /// No description provided for @onboardingBatteryBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone can pause Medito mid-session. One quick change prevents this.'**
  String get onboardingBatteryBody;

  /// No description provided for @onboardingBatteryOptimize.
  ///
  /// In en, this message translates to:
  /// **'Update Setting'**
  String get onboardingBatteryOptimize;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for Now'**
  String get skipForNow;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @packSetAsUpNext.
  ///
  /// In en, this message translates to:
  /// **'This pack will now appear in the Your Path section on the homepage'**
  String get packSetAsUpNext;

  /// No description provided for @packUnpinnedFromUpNext.
  ///
  /// In en, this message translates to:
  /// **'This pack has been removed from the Your Path section'**
  String get packUnpinnedFromUpNext;

  /// Label for the smart reminders feature toggle
  ///
  /// In en, this message translates to:
  /// **'Smart Reminders'**
  String get smartReminders;

  /// Button text to enable smart reminders
  ///
  /// In en, this message translates to:
  /// **'Turn on Smart Reminders'**
  String get turnOnSmartReminders;

  /// Status text when smart reminders are enabled
  ///
  /// In en, this message translates to:
  /// **'Smart Reminders On'**
  String get smartRemindersOn;

  /// No description provided for @donationTitle.
  ///
  /// In en, this message translates to:
  /// **'Millions find calm here for free. Help keep it that way.'**
  String get donationTitle;

  /// No description provided for @donationBody.
  ///
  /// In en, this message translates to:
  /// **'Medito is run by a small nonprofit team — no ads, no investors, no paywalls. It stays free because people like you choose to support it.'**
  String get donationBody;

  /// CTA button on the onboarding donation primer screen, opens the donation paywall
  ///
  /// In en, this message translates to:
  /// **'See how to help'**
  String get donationPrimerCta;

  /// No description provided for @donateNow.
  ///
  /// In en, this message translates to:
  /// **'Become a supporter'**
  String get donateNow;

  /// No description provided for @noThanks.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get noThanks;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @remindLater.
  ///
  /// In en, this message translates to:
  /// **'Remind Me Later'**
  String get remindLater;

  /// No description provided for @allSetTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get allSetTitle;

  /// No description provided for @startMeditating.
  ///
  /// In en, this message translates to:
  /// **'Start Meditating'**
  String get startMeditating;

  /// No description provided for @trackingPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Us Improve Medito'**
  String get trackingPermissionTitle;

  /// No description provided for @trackingPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Your privacy matters. We use anonymous data to understand how people use Medito, so we can make it better for everyone. We never collect personal information or sell your data.'**
  String get trackingPermissionBody;

  /// No description provided for @trackingPermissionPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your data stays anonymous and is never shared with third parties.'**
  String get trackingPermissionPrivacyNote;

  /// No description provided for @trackingPermissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get trackingPermissionAllow;

  /// No description provided for @onboardingFirstMeditationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first meditation'**
  String get onboardingFirstMeditationTitle;

  /// No description provided for @onboardingFirstMeditationHook.
  ///
  /// In en, this message translates to:
  /// **'Your first moment of calm.'**
  String get onboardingFirstMeditationHook;

  /// No description provided for @onboardingFirstMeditationDuration.
  ///
  /// In en, this message translates to:
  /// **'Just over 2 minutes'**
  String get onboardingFirstMeditationDuration;

  /// No description provided for @onboardingFirstMeditationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to get right. Just sit back and listen.'**
  String get onboardingFirstMeditationSubtitle;

  /// No description provided for @onboardingFirstMeditationBegin.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingFirstMeditationBegin;

  /// No description provided for @onboardingFirstMeditationSkip.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get onboardingFirstMeditationSkip;

  /// No description provided for @onboardingFirstMeditationSkipShort.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingFirstMeditationSkipShort;

  /// No description provided for @onboardingFirstMeditationDone.
  ///
  /// In en, this message translates to:
  /// **'That\'s it. You just meditated.'**
  String get onboardingFirstMeditationDone;

  /// No description provided for @onboardingFirstMeditationContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingFirstMeditationContinue;

  /// No description provided for @splashHeadline.
  ///
  /// In en, this message translates to:
  /// **'Meditation Made Simple'**
  String get splashHeadline;

  /// No description provided for @splashBenefit1Title.
  ///
  /// In en, this message translates to:
  /// **'Free for Everyone, Forever'**
  String get splashBenefit1Title;

  /// No description provided for @splashBenefit1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore hours of guided meditations, advanced courses, and more. No paywall.'**
  String get splashBenefit1Subtitle;

  /// No description provided for @splashBenefit2Title.
  ///
  /// In en, this message translates to:
  /// **'Challenges & Reminders'**
  String get splashBenefit2Title;

  /// No description provided for @splashBenefit2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Stay motivated daily, track progress, and build lasting habits.'**
  String get splashBenefit2Subtitle;

  /// No description provided for @splashBenefit3Title.
  ///
  /// In en, this message translates to:
  /// **'Not-for-profit & Ad-Free'**
  String get splashBenefit3Title;

  /// No description provided for @splashBenefit3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Donations keep us going so everyone can access mindfulness—no ads needed.'**
  String get splashBenefit3Subtitle;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// CTA on the onboarding notifications screen
  ///
  /// In en, this message translates to:
  /// **'Remind Me Daily'**
  String get setReminderB;

  /// No description provided for @donationEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get donationEmailLabel;

  /// No description provided for @donationEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'For your receipt and to manage your donation.'**
  String get donationEmailHelper;

  /// No description provided for @donationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email so we can send a receipt.'**
  String get donationEmailRequired;

  /// No description provided for @donationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'That email address does not look right.'**
  String get donationEmailInvalid;

  /// No description provided for @donationThankYouTitle.
  ///
  /// In en, this message translates to:
  /// **'Thank You for Your Support!'**
  String get donationThankYouTitle;

  /// No description provided for @donationThankYouBody.
  ///
  /// In en, this message translates to:
  /// **'Your generosity helps keep Medito free and accessible to everyone. We\'re deeply grateful for your contribution to spreading mindfulness worldwide.'**
  String get donationThankYouBody;

  /// No description provided for @donationVisitFoundation.
  ///
  /// In en, this message translates to:
  /// **'Visit Medito Foundation'**
  String get donationVisitFoundation;

  /// No description provided for @donationContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get donationContinue;

  /// No description provided for @streakFreezesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Streak Freezes Available'**
  String get streakFreezesAvailable;

  /// No description provided for @freezeUsedMessage.
  ///
  /// In en, this message translates to:
  /// **'A streak freeze was used to maintain your streak!'**
  String get freezeUsedMessage;

  /// No description provided for @streakAtRisk.
  ///
  /// In en, this message translates to:
  /// **'You missed a day'**
  String get streakAtRisk;

  /// No description provided for @streakFreezeAvailable.
  ///
  /// In en, this message translates to:
  /// **'You have 1 streak freeze available. Would you like to use it to protect your current streak?'**
  String get streakFreezeAvailable;

  /// No description provided for @streakFreezesAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'But it\'s OK! You have {count} streak freezes available. Would you like to use one to protect your current streak?'**
  String streakFreezesAvailableMessage(Object count);

  /// No description provided for @useStreakFreeze.
  ///
  /// In en, this message translates to:
  /// **'Use Streak Freeze'**
  String get useStreakFreeze;

  /// No description provided for @streakFreezesBeta.
  ///
  /// In en, this message translates to:
  /// **'Streak Freezes (Beta)'**
  String get streakFreezesBeta;

  /// No description provided for @streakFreezesBetaDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable the ability to use streak freezes to maintain your meditation streak when you miss a day'**
  String get streakFreezesBetaDescription;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTitle;

  /// No description provided for @meditationInterruptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Meditations stop unexpectedly'**
  String get meditationInterruptionTitle;

  /// No description provided for @meditationInterruptionContent.
  ///
  /// In en, this message translates to:
  /// **'This is likely due to your phone\'s battery optimization settings. Visit DontKillMyApp.com for specific instructions on how to allow Medito to run properly in the background on your device.'**
  String get meditationInterruptionContent;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'I want to support you'**
  String get supportTitle;

  /// No description provided for @supportContent.
  ///
  /// In en, this message translates to:
  /// **'You can support Medito Foundation through several methods'**
  String get supportContent;

  /// No description provided for @stopDonationTitle.
  ///
  /// In en, this message translates to:
  /// **'I want to stop my monthly donation'**
  String get stopDonationTitle;

  /// No description provided for @stopDonationContent.
  ///
  /// In en, this message translates to:
  /// **'Go to the donation portal. You need the email address you used to set them up'**
  String get stopDonationContent;

  /// No description provided for @statsWrongTitle.
  ///
  /// In en, this message translates to:
  /// **'My stats are wrong'**
  String get statsWrongTitle;

  /// No description provided for @statsWrongContent.
  ///
  /// In en, this message translates to:
  /// **'You can edit them at the dedicated stats editing page.'**
  String get statsWrongContent;

  /// No description provided for @contactUsContent.
  ///
  /// In en, this message translates to:
  /// **'If you have any questions not addressed on this page, any feedback, or if you need assistance, try updating the app. If that doesn\'t help, please reach out to us. We\'re here to help!'**
  String get contactUsContent;

  /// No description provided for @contactUsActionText.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUsActionText;

  /// No description provided for @downloadTracksTitle.
  ///
  /// In en, this message translates to:
  /// **'How to download tracks'**
  String get downloadTracksTitle;

  /// No description provided for @downloadTracksContent.
  ///
  /// In en, this message translates to:
  /// **'To download a track, start playing it and then look for the download icon (a down arrow) at the bottom of the player screen—it\'s the second icon.\\n\\nOnce downloaded, you can access your tracks by tapping the \"Downloads\" tile on the home screen.'**
  String get downloadTracksContent;

  /// No description provided for @openBatterySettingsText.
  ///
  /// In en, this message translates to:
  /// **'Visit DontKillMyApp.com'**
  String get openBatterySettingsText;

  /// No description provided for @dontKillMyAppUrl.
  ///
  /// In en, this message translates to:
  /// **'https://dontkillmyapp.com'**
  String get dontKillMyAppUrl;

  /// No description provided for @goToDonationPortalText.
  ///
  /// In en, this message translates to:
  /// **'Go to Donation Portal'**
  String get goToDonationPortalText;

  /// No description provided for @editStatsActionText.
  ///
  /// In en, this message translates to:
  /// **'Edit Stats'**
  String get editStatsActionText;

  /// No description provided for @donateViaDonationFormText.
  ///
  /// In en, this message translates to:
  /// **'Donate via Donation Form'**
  String get donateViaDonationFormText;

  /// No description provided for @donateViaPayPalText.
  ///
  /// In en, this message translates to:
  /// **'Donate via PayPal'**
  String get donateViaPayPalText;

  /// No description provided for @donateViaBankTransferText.
  ///
  /// In en, this message translates to:
  /// **'Donate via Bank Transfer'**
  String get donateViaBankTransferText;

  /// No description provided for @donationFormUrl.
  ///
  /// In en, this message translates to:
  /// **'https://donate.meditofoundation.org'**
  String get donationFormUrl;

  /// No description provided for @payPalDonationUrl.
  ///
  /// In en, this message translates to:
  /// **'https://paypal.me/meditofoundation'**
  String get payPalDonationUrl;

  /// No description provided for @bankTransferDetailsUrl.
  ///
  /// In en, this message translates to:
  /// **'https://meditofoundation.org/about/bank-details'**
  String get bankTransferDetailsUrl;

  /// No description provided for @donationPortalUrl.
  ///
  /// In en, this message translates to:
  /// **'https://bit.ly/3yFqVbM'**
  String get donationPortalUrl;

  /// No description provided for @contactFormBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'https://tally.so/r/wLGBaO'**
  String get contactFormBaseUrl;

  /// No description provided for @batteryOptimizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your device has additional battery optimization'**
  String get batteryOptimizationTitle;

  /// No description provided for @batteryOptimizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow the steps and disable the optimizations to allow smooth functioning of this app'**
  String get batteryOptimizationDescription;

  /// No description provided for @autoStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Auto Start'**
  String get autoStartTitle;

  /// No description provided for @autoStartDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow the steps and enable the auto start of this app'**
  String get autoStartDescription;

  /// No description provided for @batteryOptimizationAlreadyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization is already disabled for Medito'**
  String get batteryOptimizationAlreadyDisabled;

  /// No description provided for @donationRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Please Reconsider'**
  String get donationRetentionTitle;

  /// No description provided for @donationRetentionMainMessage.
  ///
  /// In en, this message translates to:
  /// **'Millions of people rely on Medito, and we operate solely on donations.'**
  String get donationRetentionMainMessage;

  /// No description provided for @donationRetentionBenefitsHeading.
  ///
  /// In en, this message translates to:
  /// **'Your support helps us:'**
  String get donationRetentionBenefitsHeading;

  /// No description provided for @donationRetentionBenefit1.
  ///
  /// In en, this message translates to:
  /// **'Add new meditation content regularly'**
  String get donationRetentionBenefit1;

  /// No description provided for @donationRetentionBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Develop new features to improve your experience'**
  String get donationRetentionBenefit2;

  /// No description provided for @donationRetentionBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Keep Medito free and accessible for everyone'**
  String get donationRetentionBenefit3;

  /// No description provided for @donationRetentionFinancialMessage.
  ///
  /// In en, this message translates to:
  /// **'If you\'re experiencing financial difficulties, we understand. But if you can continue your support, even at a reduced amount, it would make a significant difference.'**
  String get donationRetentionFinancialMessage;

  /// No description provided for @stayAsDonorButtonText.
  ///
  /// In en, this message translates to:
  /// **'Stay as a donor'**
  String get stayAsDonorButtonText;

  /// No description provided for @continueToCancellationButtonText.
  ///
  /// In en, this message translates to:
  /// **'Continue to cancellation'**
  String get continueToCancellationButtonText;

  /// No description provided for @donationRetentionThankYouMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your continued support means the world to us and helps millions of people access meditation.'**
  String get donationRetentionThankYouMessage;

  /// No description provided for @errorNetworkMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to server'**
  String get errorNetworkMessage;

  /// No description provided for @errorNoInternetMessage.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNoInternetMessage;

  /// No description provided for @errorTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get errorTimeoutMessage;

  /// No description provided for @errorUnauthorizedMessage.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please sign in again'**
  String get errorUnauthorizedMessage;

  /// No description provided for @errorNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Content not found'**
  String get errorNotFoundMessage;

  /// No description provided for @errorServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Server error, please try again later'**
  String get errorServerMessage;

  /// No description provided for @errorUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong, please try again'**
  String get errorUnknownMessage;

  /// No description provided for @inactiveEmailError.
  ///
  /// In en, this message translates to:
  /// **'This email address is currently unable to receive messages due to email provider restrictions or delivery issues. Please try using a different email address.'**
  String get inactiveEmailError;

  /// No description provided for @enableDndDuringMeditation.
  ///
  /// In en, this message translates to:
  /// **'Silence phone during meditation'**
  String get enableDndDuringMeditation;

  /// Title for zen mode setting in customization section
  ///
  /// In en, this message translates to:
  /// **'Zen Mode'**
  String get zenMode;

  /// Subtitle for zen mode setting in customization section
  ///
  /// In en, this message translates to:
  /// **'Hide all stats, streak, scores app-wide'**
  String get zenModeSubtitle;

  /// Message shown when zen mode is enabled
  ///
  /// In en, this message translates to:
  /// **'Stats will be hidden throughout the app'**
  String get zenModeEnabledMessage;

  /// Message shown in zen mode after completing meditation
  ///
  /// In en, this message translates to:
  /// **'Mind Clear'**
  String get mindClear;

  /// No description provided for @donateToMedito.
  ///
  /// In en, this message translates to:
  /// **'Donate Now'**
  String get donateToMedito;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom Amount'**
  String get custom;

  /// No description provided for @payWithPaypal.
  ///
  /// In en, this message translates to:
  /// **'Donate with PayPal'**
  String get payWithPaypal;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @changeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Change Currency'**
  String get changeCurrency;

  /// No description provided for @chooseAmount.
  ///
  /// In en, this message translates to:
  /// **'Choose an amount'**
  String get chooseAmount;

  /// No description provided for @otherPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Other donation methods'**
  String get otherPaymentMethods;

  /// No description provided for @donationSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'All donations are securely processed. We are a registered non-profit organisation dedicated to making meditation accessible to everyone.'**
  String get donationSecurityMessage;

  /// No description provided for @donationImpactTitle.
  ///
  /// In en, this message translates to:
  /// **'Your donation helps us to:'**
  String get donationImpactTitle;

  /// No description provided for @donationImpactPoints.
  ///
  /// In en, this message translates to:
  /// **'• Create new free meditation content\n• Maintain the app without ads\n• Make mental wellbeing accessible to all\n• Helps us keep meditation free for everyone'**
  String get donationImpactPoints;

  /// No description provided for @donationSecurityInfo.
  ///
  /// In en, this message translates to:
  /// **'We do not sell or trade your information with anyone.'**
  String get donationSecurityInfo;

  /// No description provided for @foundationRegistrationInfo.
  ///
  /// In en, this message translates to:
  /// **'Medito Foundation or in Dutch, Stichting Medito is a non-profit organisation registered in the Netherlands.'**
  String get foundationRegistrationInfo;

  /// No description provided for @foundationContactInfo.
  ///
  /// In en, this message translates to:
  /// **'KvK-nummer: 75284251\nRSIN: 860222627\nEmail: hello@meditofoundation.org'**
  String get foundationContactInfo;

  /// No description provided for @redirectingToSecurePayment.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to a secure payment page...'**
  String get redirectingToSecurePayment;

  /// No description provided for @couldNotOpenDonationPage.
  ///
  /// In en, this message translates to:
  /// **'Could not open the donation page.'**
  String get couldNotOpenDonationPage;

  /// No description provided for @monthlyDonation.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyDonation;

  /// No description provided for @singleDonation.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get singleDonation;

  /// No description provided for @monthlyDonationImpact.
  ///
  /// In en, this message translates to:
  /// **'£10/month can bring meditation to hundreds, helping fight depression and anxiety.'**
  String get monthlyDonationImpact;

  /// No description provided for @oneTimeDonationImpact.
  ///
  /// In en, this message translates to:
  /// **'Your donation directly supports free mindfulness resources, bringing peace to thousands today.'**
  String get oneTimeDonationImpact;

  /// Shown in donate button when payment completes successfully
  ///
  /// In en, this message translates to:
  /// **'Donation Successful!'**
  String get donationSuccessful;

  /// Shown in donate button when Stripe bottom sheet is open
  ///
  /// In en, this message translates to:
  /// **'Complete payment in the form below'**
  String get completePaymentInForm;

  /// Helper text when Stripe bottom sheet is open
  ///
  /// In en, this message translates to:
  /// **'Please complete your payment in the secure form'**
  String get pleaseCompletePayment;

  /// Helper text when payment is being processed
  ///
  /// In en, this message translates to:
  /// **'Processing your donation...'**
  String get processingDonation;

  /// Helper text shown after successful donation
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support!'**
  String get thankYouForSupport;

  /// Default helper text in donate button
  ///
  /// In en, this message translates to:
  /// **'Tap an amount above to start your donation'**
  String get tapAmountToStart;

  /// No description provided for @impactCardHelpMessage.
  ///
  /// In en, this message translates to:
  /// **'Help millions worldwide access free meditation'**
  String get impactCardHelpMessage;

  /// No description provided for @impactCardTestimonial.
  ///
  /// In en, this message translates to:
  /// **'\"Medito pulled me through a seriously dark period in my life\" - Medito meditator'**
  String get impactCardTestimonial;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @noFavoriteTracksYet.
  ///
  /// In en, this message translates to:
  /// **'No favorite tracks yet'**
  String get noFavoriteTracksYet;

  /// No description provided for @noFavoritePacksYet.
  ///
  /// In en, this message translates to:
  /// **'No favorite packs yet'**
  String get noFavoritePacksYet;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @addItemsToFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'Add items to your favorites to see them here'**
  String get addItemsToFavoritesMessage;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @packs.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get packs;

  /// No description provided for @shopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopTitle;

  /// No description provided for @emailExistsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Existing Account Found'**
  String get emailExistsDialogTitle;

  /// No description provided for @emailExistsDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Looks like you have signed in with an email address before. Would you like to sign in with your email address again?'**
  String get emailExistsDialogMessage;

  /// No description provided for @emailExistsContinueNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get emailExistsContinueNewAccount;

  /// No description provided for @emailExistsSignInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Email'**
  String get emailExistsSignInWithEmail;

  /// No description provided for @analyticsTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Collection'**
  String get analyticsTrackingTitle;

  /// No description provided for @analyticsTrackingContent.
  ///
  /// In en, this message translates to:
  /// **'We collect usage data and limited identifiers (such as a user ID and, where permitted, device or advertising identifiers) to help us improve the app and understand feature usage. You can turn analytics off at any time. See our Privacy Policy for details.'**
  String get analyticsTrackingContent;

  /// No description provided for @turnOffAnalyticsText.
  ///
  /// In en, this message translates to:
  /// **'Turn Off Analytics'**
  String get turnOffAnalyticsText;

  /// No description provided for @turnOnAnalyticsText.
  ///
  /// In en, this message translates to:
  /// **'Turn On Analytics'**
  String get turnOnAnalyticsText;

  /// No description provided for @analyticsDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Analytics tracking has been disabled'**
  String get analyticsDisabledMessage;

  /// No description provided for @analyticsEnabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Analytics tracking has been enabled'**
  String get analyticsEnabledMessage;

  /// No description provided for @iosTrackingDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Collection'**
  String get iosTrackingDialogTitle;

  /// No description provided for @iosTrackingDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will disable analytics tracking in the app. We may collect limited identifiers (e.g. user ID and, where permitted, device/advertising IDs) to measure usage and improve features. You can also control tracking permissions in iOS Settings > Privacy & Security > Tracking.'**
  String get iosTrackingDialogContent;

  /// No description provided for @androidTrackingDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will disable analytics tracking in the app. We may collect limited identifiers (e.g. user ID and, where permitted, device/advertising IDs) to measure usage and improve features.'**
  String get androidTrackingDialogContent;

  /// No description provided for @iosTrackingDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get iosTrackingDialogCancel;

  /// No description provided for @iosTrackingDialogDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable Tracking'**
  String get iosTrackingDialogDisable;

  /// No description provided for @newProductLabel.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newProductLabel;

  /// No description provided for @packsSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get packsSectionHeader;

  /// No description provided for @tracksSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracksSectionHeader;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found for your search'**
  String get noResultsFound;

  /// No description provided for @consistencyScoreInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Consistency Score'**
  String get consistencyScoreInfoTitle;

  /// No description provided for @consistencyScoreInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'Your consistency score reflects how regularly you\'ve meditated since you started. Recent days carry more weight, but earlier missed days still gently affect the score. Unlike streaks, it doesn\'t reset on a missed day.'**
  String get consistencyScoreInfoMessage;

  /// No description provided for @accountDeletionInitiated.
  ///
  /// In en, this message translates to:
  /// **'Account deletion process initiated. Please complete the steps in your browser.'**
  String get accountDeletionInitiated;

  /// No description provided for @reportError.
  ///
  /// In en, this message translates to:
  /// **'Report Error'**
  String get reportError;

  /// No description provided for @errorReportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you, your report has been sent.'**
  String get errorReportedMessage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get languageSubtitle;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Español (beta)'**
  String get spanish;

  /// Title for reporting issues with a meditation track
  ///
  /// In en, this message translates to:
  /// **'Report Track'**
  String get reportTrack;

  /// Button text to report issues for the entire track
  ///
  /// In en, this message translates to:
  /// **'Report for this track'**
  String get reportForThisTrack;

  /// Button text to report issues at the current playback position
  ///
  /// In en, this message translates to:
  /// **'Report at'**
  String get reportAtCurrentPosition;

  /// Dialog description text for reporting track issues
  ///
  /// In en, this message translates to:
  /// **'Report an issue with \"{trackTitle}\"'**
  String reportTrackDescription(String trackTitle);

  /// Question shown in the report dialog
  ///
  /// In en, this message translates to:
  /// **'What would you like to report?'**
  String get reportDialogQuestion;

  /// Help link text in the report dialog
  ///
  /// In en, this message translates to:
  /// **'Please check the help page if your issue has been addressed'**
  String get reportDialogHelpLink;

  /// Label for the help page link
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpPage;

  /// Error message when reading from local storage fails
  ///
  /// In en, this message translates to:
  /// **'Failed to read data from local storage'**
  String get storageReadError;

  /// Error message when account is inactive
  ///
  /// In en, this message translates to:
  /// **'This email address is currently unable to receive messages due to email provider restrictions or delivery issues. Please try using a different email address.'**
  String get accountInactiveError;

  /// Error message for rate limit errors
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get rateLimitError;

  /// Title for the 'no background sound' option
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get backgroundSoundNone;

  /// Label for custom donation amount
  ///
  /// In en, this message translates to:
  /// **'Custom Amount'**
  String get customAmount;

  /// Label for debug information
  ///
  /// In en, this message translates to:
  /// **'Debug info'**
  String get debugInfoLabel;

  /// Error message when a required field is empty
  ///
  /// In en, this message translates to:
  /// **'Field is Required'**
  String get fieldRequiredError;

  /// Error message for invalid input
  ///
  /// In en, this message translates to:
  /// **'Invalid Input'**
  String get invalidInputError;

  /// Error message when there's no internet connection
  ///
  /// In en, this message translates to:
  /// **'Make sure you are connected to the internet to use Medito'**
  String get connectivityErrorMessage;

  /// Error message for timeout errors
  ///
  /// In en, this message translates to:
  /// **'Oops! It seems like there was an error. If the problem persists, Close the app and try again.'**
  String get timeoutErrorMessage;

  /// Generic error message for unknown errors
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred. Either we\'re having issues or you\'re offline.'**
  String get anErrorOccurredMessage;

  /// Section title for help settings
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpLegalSection;

  /// Section title for support and community settings
  ///
  /// In en, this message translates to:
  /// **'Support & Community'**
  String get supportCommunitySection;

  /// Section title for customization settings
  ///
  /// In en, this message translates to:
  /// **'Customisation'**
  String get customizationSection;

  /// Title for adding home screen widget option in customization section
  ///
  /// In en, this message translates to:
  /// **'Add Home Screen Widget'**
  String get addHomeScreenWidget;

  /// Title for theme selection setting in customization section
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// Title for app icon selection setting in customization section
  ///
  /// In en, this message translates to:
  /// **'App Icon'**
  String get appIconTitle;

  /// Label for the default app icon option
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get appIconDefault;

  /// Label for the near-black app icon option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appIconNearBlack;

  /// Label for the dusk gradient app icon option (now the default)
  ///
  /// In en, this message translates to:
  /// **'Dusk'**
  String get appIconDusk;

  /// Label for the original purple app icon option
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get appIconPurple;

  /// Label for the classic app icon option (purple M on white)
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get appIconClassic;

  /// Label for the blush pink gradient app icon option
  ///
  /// In en, this message translates to:
  /// **'Blush'**
  String get appIconBlush;

  /// Label for the ocean blue gradient app icon option
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get appIconOcean;

  /// Label for the forest green gradient app icon option
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get appIconForest;

  /// Label for the pink-to-gold sunset gradient app icon option
  ///
  /// In en, this message translates to:
  /// **'Golden'**
  String get appIconPink;

  /// Snackbar message shown on Android after changing the app icon
  ///
  /// In en, this message translates to:
  /// **'Icon updated. Restarting…'**
  String get appIconChanged;

  /// System theme option that follows device settings
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// Dialog title for theme selection
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// Loading text shown while processing donation
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// Success message shown after successful donation
  ///
  /// In en, this message translates to:
  /// **'Thank you for your donation! Your support helps us continue our mission.'**
  String get thankYouForDonationMessage;

  /// Message shown when payment is cancelled
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get paymentCancelled;

  /// Loading text while payment is being processed
  ///
  /// In en, this message translates to:
  /// **'Processing payment...'**
  String get processingPayment;

  /// Loading text while preparing donation
  ///
  /// In en, this message translates to:
  /// **'Preparing donation...'**
  String get preparingDonation;

  /// Helper text shown while loading donation options
  ///
  /// In en, this message translates to:
  /// **'This may take a moment'**
  String get thisMayTakeAMoment;

  /// Success message shown after successful payment
  ///
  /// In en, this message translates to:
  /// **'Payment successful! Thank you for your donation of {amount} {currency}.'**
  String paymentSuccessMessage(String amount, String currency);

  /// Error message shown when payment fails
  ///
  /// In en, this message translates to:
  /// **'Payment failed for payment intent id: {paymentIntentId}'**
  String paymentFailedMessage(String paymentIntentId);

  /// Message shown when payment is cancelled by user
  ///
  /// In en, this message translates to:
  /// **'Payment was cancelled.'**
  String get paymentCancelledMessage;

  /// Fallback text for notifications when no body is provided
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessageFallback;

  /// Action label for notification actions
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewAction;

  /// Title shown to existing donors in the donation widget
  ///
  /// In en, this message translates to:
  /// **'Thank You for Your Support'**
  String get thankYouForYourSupport;

  /// Message shown to existing donors explaining their importance
  ///
  /// In en, this message translates to:
  /// **'We rely on donors like you to continue providing mindfulness to everyone.'**
  String get donorSupportMessage;

  /// Button text for donating again after a previous donation
  ///
  /// In en, this message translates to:
  /// **'Donate Again'**
  String get donateAgain;

  /// Title for the donation info dialog explaining why users might see the donation ask
  ///
  /// In en, this message translates to:
  /// **'Why You Might See This'**
  String get donationInfoTitle;

  /// Message explaining why users might see the donation ask even if they've donated
  ///
  /// In en, this message translates to:
  /// **'Sometimes we don\'t know when someone has donated. We are looking at how to improve this. You can hide this message for a while if you\'ve already donated.'**
  String get donationInfoMessage;

  /// Button text to temporarily hide the donation ask
  ///
  /// In en, this message translates to:
  /// **'I\'ve Already Donated'**
  String get hideForNow;

  /// Message shown after hiding the donation ask
  ///
  /// In en, this message translates to:
  /// **'Donation ask hidden for 30 days'**
  String get donationAskHiddenMessage;

  /// Message shown when user dismisses the reminder prompt on the end screen
  ///
  /// In en, this message translates to:
  /// **'You can turn reminders on or off in Settings'**
  String get reminderPromptDismissedMessage;

  /// Smart reminder day 1 title variant 1
  ///
  /// In en, this message translates to:
  /// **'Keep your streak going 🌱'**
  String get smartReminderDay1TitleVar1;

  /// Smart reminder day 1 body variant 1
  ///
  /// In en, this message translates to:
  /// **'You are on a {streak} day streak. Keep it going?'**
  String smartReminderDay1BodyVar1(String streak);

  /// Smart reminder day 1 title variant 2
  ///
  /// In en, this message translates to:
  /// **'Strong step ✨'**
  String get smartReminderDay1TitleVar2;

  /// Smart reminder day 1 body variant 2
  ///
  /// In en, this message translates to:
  /// **'Consistency {consistency}%. Let’s keep it going.'**
  String smartReminderDay1BodyVar2(String consistency);

  /// Smart reminder day 1 title variant 3
  ///
  /// In en, this message translates to:
  /// **'Tiny wins add up 💜'**
  String get smartReminderDay1TitleVar3;

  /// Smart reminder day 1 body variant 3
  ///
  /// In en, this message translates to:
  /// **'A few minutes now keeps your momentum alive.'**
  String get smartReminderDay1BodyVar3;

  /// Smart reminder day 1 title variant 4
  ///
  /// In en, this message translates to:
  /// **'Your practice awaits 🌸'**
  String get smartReminderDay1TitleVar4;

  /// Smart reminder day 1 body variant 4
  ///
  /// In en, this message translates to:
  /// **'Take a moment to reconnect with yourself.'**
  String get smartReminderDay1BodyVar4;

  /// Smart reminder day 1 title variant 5
  ///
  /// In en, this message translates to:
  /// **'One breath at a time 🫧'**
  String get smartReminderDay1TitleVar5;

  /// Smart reminder day 1 body variant 5
  ///
  /// In en, this message translates to:
  /// **'Every session counts, no matter how short.'**
  String get smartReminderDay1BodyVar5;

  /// Smart reminder day 2 title variant 1
  ///
  /// In en, this message translates to:
  /// **'Keep the flow 🔁'**
  String get smartReminderDay2TitleVar1;

  /// Smart reminder day 2 body variant 1
  ///
  /// In en, this message translates to:
  /// **'Let’s get that streak going again. Just a few minutes can make a big difference.'**
  String get smartReminderDay2BodyVar1;

  /// Smart reminder day 2 title variant 2
  ///
  /// In en, this message translates to:
  /// **'Build your rhythm 🧘'**
  String get smartReminderDay2TitleVar2;

  /// Smart reminder day 2 body variant 2
  ///
  /// In en, this message translates to:
  /// **'Another gentle practice awaits.'**
  String get smartReminderDay2BodyVar2;

  /// Smart reminder day 2 title variant 3
  ///
  /// In en, this message translates to:
  /// **'You have got this 🌟'**
  String get smartReminderDay2TitleVar3;

  /// Smart reminder day 2 body variant 3
  ///
  /// In en, this message translates to:
  /// **'Return to your breath, one moment at a time.'**
  String get smartReminderDay2BodyVar3;

  /// Smart reminder day 2 title variant 4
  ///
  /// In en, this message translates to:
  /// **'Small steps forward 🚶'**
  String get smartReminderDay2TitleVar4;

  /// Smart reminder day 2 body variant 4
  ///
  /// In en, this message translates to:
  /// **'Consistency builds strength. Start with just a few minutes.'**
  String get smartReminderDay2BodyVar4;

  /// Smart reminder day 2 title variant 5
  ///
  /// In en, this message translates to:
  /// **'Gentle return 💚'**
  String get smartReminderDay2TitleVar5;

  /// Smart reminder day 2 body variant 5
  ///
  /// In en, this message translates to:
  /// **'Your mindful practice is here whenever you are ready.'**
  String get smartReminderDay2BodyVar5;

  /// Smart reminder day 3 title variant 1
  ///
  /// In en, this message translates to:
  /// **'Build the habit 📆'**
  String get smartReminderDay3TitleVar1;

  /// Smart reminder day 3 body variant 1
  ///
  /// In en, this message translates to:
  /// **'Momentum matters. You have got this.'**
  String get smartReminderDay3BodyVar1;

  /// Smart reminder day 3 title variant 2
  ///
  /// In en, this message translates to:
  /// **'Three day spark ✴️'**
  String get smartReminderDay3TitleVar2;

  /// Smart reminder day 3 body variant 2
  ///
  /// In en, this message translates to:
  /// **'Your practice is taking shape.'**
  String get smartReminderDay3BodyVar2;

  /// Smart reminder day 3 title variant 3
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge 🤍'**
  String get smartReminderDay3TitleVar3;

  /// Smart reminder day 3 body variant 3
  ///
  /// In en, this message translates to:
  /// **'Two mindful minutes is enough.'**
  String get smartReminderDay3BodyVar3;

  /// Smart reminder day 3 title variant 4
  ///
  /// In en, this message translates to:
  /// **'Growing stronger 🌿'**
  String get smartReminderDay3TitleVar4;

  /// Smart reminder day 3 body variant 4
  ///
  /// In en, this message translates to:
  /// **'Each day you practice, you build something meaningful.'**
  String get smartReminderDay3BodyVar4;

  /// Smart reminder day 3 title variant 5
  ///
  /// In en, this message translates to:
  /// **'Find your calm 🕊️'**
  String get smartReminderDay3TitleVar5;

  /// Smart reminder day 3 body variant 5
  ///
  /// In en, this message translates to:
  /// **'A brief pause can reset your entire day.'**
  String get smartReminderDay3BodyVar5;

  /// Smart reminder day 4 title
  ///
  /// In en, this message translates to:
  /// **'Small steps 🪴'**
  String get smartReminderDay4Title;

  /// Smart reminder day 4 body
  ///
  /// In en, this message translates to:
  /// **'It has been 4 days since you meditated. Resume your practice with a short session.'**
  String get smartReminderDay4Body;

  /// Smart reminder day 5 title
  ///
  /// In en, this message translates to:
  /// **'Time to reconnect 💪'**
  String get smartReminderDay5Title;

  /// Smart reminder day 5 body
  ///
  /// In en, this message translates to:
  /// **'It has been 5 days. A calm pause now can help you get back on track.'**
  String get smartReminderDay5Body;

  /// Smart reminder day 6 title
  ///
  /// In en, this message translates to:
  /// **'Almost a week ⏰'**
  String get smartReminderDay6Title;

  /// Smart reminder day 6 body
  ///
  /// In en, this message translates to:
  /// **'It has been almost a week since you meditated. Close the loop with a mindful moment.'**
  String get smartReminderDay6Body;

  /// Smart reminder day 7 title
  ///
  /// In en, this message translates to:
  /// **'One week check in 📅'**
  String get smartReminderDay7Title;

  /// Smart reminder day 7 body
  ///
  /// In en, this message translates to:
  /// **'It has been a week since you meditated. Take a moment for yourself now.'**
  String get smartReminderDay7Body;

  /// Smart reminder day 8 title
  ///
  /// In en, this message translates to:
  /// **'Fresh start 🌤️'**
  String get smartReminderDay8Title;

  /// Smart reminder day 8 body
  ///
  /// In en, this message translates to:
  /// **'It has been over a week. A fresh start with just a few mindful minutes.'**
  String get smartReminderDay8Body;

  /// Smart reminder day 9 title
  ///
  /// In en, this message translates to:
  /// **'Find your centre 🎯'**
  String get smartReminderDay9Title;

  /// Smart reminder day 9 body
  ///
  /// In en, this message translates to:
  /// **'A short session can reset your day.'**
  String get smartReminderDay9Body;

  /// Smart reminder day 10 title
  ///
  /// In en, this message translates to:
  /// **'Double digits 🔟'**
  String get smartReminderDay10Title;

  /// Smart reminder day 10 body
  ///
  /// In en, this message translates to:
  /// **'It has been 10 days since you meditated. Pick up where you left off.'**
  String get smartReminderDay10Body;

  /// Smart reminder day 11 title
  ///
  /// In en, this message translates to:
  /// **'Gentle nudge 🤍'**
  String get smartReminderDay11Title;

  /// Smart reminder day 11 body
  ///
  /// In en, this message translates to:
  /// **'Pause, breathe, and notice how you feel.'**
  String get smartReminderDay11Body;

  /// Smart reminder day 12 title
  ///
  /// In en, this message translates to:
  /// **'Keep steady 🧭'**
  String get smartReminderDay12Title;

  /// Smart reminder day 12 body
  ///
  /// In en, this message translates to:
  /// **'A calm moment is waiting for you.'**
  String get smartReminderDay12Body;

  /// Smart reminder day 13 title
  ///
  /// In en, this message translates to:
  /// **'Approaching two weeks ⏳'**
  String get smartReminderDay13Title;

  /// Smart reminder day 13 body
  ///
  /// In en, this message translates to:
  /// **'It has been almost two weeks since you meditated. Try a two minute restart.'**
  String get smartReminderDay13Body;

  /// Smart reminder day 14 title
  ///
  /// In en, this message translates to:
  /// **'Two week check in 🔔'**
  String get smartReminderDay14Title;

  /// Smart reminder day 14 body
  ///
  /// In en, this message translates to:
  /// **'It has been 14 days since you meditated. Resume your practice now, gently.'**
  String get smartReminderDay14Body;

  /// Smart reminder day 15 title
  ///
  /// In en, this message translates to:
  /// **'Pausing reminders 🌿'**
  String get smartReminderDay15Title;

  /// Smart reminder day 15 body
  ///
  /// In en, this message translates to:
  /// **'We\'re pausing reminders for now. We are here whenever you are ready.'**
  String get smartReminderDay15Body;

  /// Smart reminder day 30 title
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge 🤗'**
  String get smartReminderDay30Title;

  /// Smart reminder day 30 body
  ///
  /// In en, this message translates to:
  /// **'It\'s been a month since you meditated. Just 2 minutes can help you feel better. We\'re here when you\'re ready.'**
  String get smartReminderDay30Body;

  /// Tooltip text for repeat mode when set to normal (no repeat)
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get repeatModeNormal;

  /// Tooltip text for repeat mode when set to repeat once
  ///
  /// In en, this message translates to:
  /// **'Repeat Once'**
  String get repeatModeOnce;

  /// Tooltip text for repeat mode when set to repeat forever
  ///
  /// In en, this message translates to:
  /// **'Repeat Forever'**
  String get repeatModeForever;

  /// Title for adding a manual meditation session
  ///
  /// In en, this message translates to:
  /// **'Add Session'**
  String get addSession;

  /// Title for the dialog confirming deletion of a tracked session
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get deleteSessionTitle;

  /// Confirmation message shown when the user long-presses a session to delete it
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this session? This will update your streak and stats.'**
  String get deleteSessionConfirmation;

  /// Error snackbar shown when deleting a session fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete session.'**
  String get deleteSessionError;

  /// Label for date selection
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Label for time selection
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Placeholder text for date selection
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// Tab label for adding a session on a single day
  ///
  /// In en, this message translates to:
  /// **'Single day'**
  String get singleDay;

  /// Tab label for adding sessions across a range of days
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRange;

  /// Label for the start date in a range picker
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// Label for the end date in a range picker
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// Validation error when the end date precedes the start date
  ///
  /// In en, this message translates to:
  /// **'End date must be on or after the start date'**
  String get endDateBeforeStartError;

  /// Placeholder text for time selection
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// Placeholder text for duration input in minutes
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get durationInMinutes;

  /// Text to indicate an optional field
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Title for morning meditation sessions
  ///
  /// In en, this message translates to:
  /// **'Morning meditation'**
  String get morningMeditation;

  /// Title for afternoon meditation sessions
  ///
  /// In en, this message translates to:
  /// **'Afternoon meditation'**
  String get afternoonMeditation;

  /// Title for evening meditation sessions
  ///
  /// In en, this message translates to:
  /// **'Evening meditation'**
  String get eveningMeditation;

  /// Title for night meditation sessions
  ///
  /// In en, this message translates to:
  /// **'Night meditation'**
  String get nightMeditation;

  /// Button text to add a session
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Text shown for manually added meditation sessions
  ///
  /// In en, this message translates to:
  /// **'Added manually'**
  String get addedManually;

  /// Placeholder text shown for manually added sessions when no custom title is provided
  ///
  /// In en, this message translates to:
  /// **'Manually added session'**
  String get manuallyAddedSession;

  /// Explanation text for the add session dialog
  ///
  /// In en, this message translates to:
  /// **'If you\'ve done a meditation session outside the app, you can add it here to track it in your stats.'**
  String get addSessionExplanation;

  /// Error message shown when trying to add a session with a future date/time
  ///
  /// In en, this message translates to:
  /// **'Cannot add sessions in the future'**
  String get cannotAddFutureSession;

  /// Label prefix for meditation completion time
  ///
  /// In en, this message translates to:
  /// **'Completed at'**
  String get completedAt;

  /// Title for the Your Path section on the home screen
  ///
  /// In en, this message translates to:
  /// **'Your Path'**
  String get upNextTitle;

  /// Headline on the Up Next card when every session in the pinned pack is complete
  ///
  /// In en, this message translates to:
  /// **'You finished {packTitle}'**
  String upNextPackCompletedTitle(String packTitle);

  /// Supporting line on the completed Up Next card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session complete} other{{count} sessions complete}}'**
  String upNextPackCompletedSubtitle(int count);

  /// Fallback button label on the completed Up Next card, used while the next pack's title is still loading
  ///
  /// In en, this message translates to:
  /// **'Start the next pack'**
  String get upNextPackCompletedCta;

  /// Button on the completed Up Next card, naming the next pack it will pin
  ///
  /// In en, this message translates to:
  /// **'Start {packTitle}'**
  String upNextPackCompletedCtaNamed(String packTitle);

  /// Headline shown when the user finishes the final pack in the curated sequence
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed your path'**
  String get upNextPathCompletedTitle;

  /// Supporting line shown when there is no next pack to offer
  ///
  /// In en, this message translates to:
  /// **'Every pack in your path is done. Explore the library to choose what\'s next.'**
  String get upNextPathCompletedSubtitle;

  /// Snackbar confirming the next pack was pinned as Up Next
  ///
  /// In en, this message translates to:
  /// **'Your next pack is ready in Your Path'**
  String get upNextNextPackPinnedSnack;

  /// Shows the current session number out of total sessions
  ///
  /// In en, this message translates to:
  /// **'Session {current} of {total}'**
  String upNextSessionCount(int current, int total);

  /// Title for the manage defaults screen
  ///
  /// In en, this message translates to:
  /// **'Manage Defaults'**
  String get manageDefaults;

  /// Section title for defaults
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get defaults;

  /// Label for default guide name setting
  ///
  /// In en, this message translates to:
  /// **'Default Guide Name'**
  String get defaultGuideName;

  /// Label for default duration setting
  ///
  /// In en, this message translates to:
  /// **'Default Duration'**
  String get defaultDuration;

  /// Message shown when default guide name is cleared
  ///
  /// In en, this message translates to:
  /// **'Default guide name cleared'**
  String get defaultGuideNameCleared;

  /// Message shown when default duration is cleared
  ///
  /// In en, this message translates to:
  /// **'Default duration cleared'**
  String get defaultDurationCleared;

  /// Text shown when a default value is not set
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// Note explaining how defaults work in Up Next
  ///
  /// In en, this message translates to:
  /// **'These defaults are set from your last selection on any track. Your Path uses them to skip the selection screen.'**
  String get defaultsNote;

  /// Text shown when a streak freeze was used on a particular day
  ///
  /// In en, this message translates to:
  /// **'Streak freeze used'**
  String get streakFreezeUsed;

  /// Singular form of session
  ///
  /// In en, this message translates to:
  /// **'session'**
  String get session;

  /// Plural form of sessions
  ///
  /// In en, this message translates to:
  /// **'sessions'**
  String get sessions;

  /// Accessibility label for the play button in the player
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Accessibility label for the pause button in the player
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Accessibility label for the skip-back button in the player
  ///
  /// In en, this message translates to:
  /// **'Skip back 10 seconds'**
  String get skipBackward10Seconds;

  /// Accessibility label for the skip-forward button in the player
  ///
  /// In en, this message translates to:
  /// **'Skip forward 10 seconds'**
  String get skipForward10Seconds;

  /// Accessibility label for the repeat button in the player
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// Accessibility label for the close button in the player
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Accessibility label for the download button in the player
  ///
  /// In en, this message translates to:
  /// **'Download audio'**
  String get downloadAudio;

  /// Accessibility label for the delete-download button in the player
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get deleteDownload;

  /// Accessibility label for the playback speed control in the player
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// Accessibility label for the report button in the player
  ///
  /// In en, this message translates to:
  /// **'Report issue'**
  String get reportIssue;

  /// Accessibility label for the streak circle button on the home screen
  ///
  /// In en, this message translates to:
  /// **'View streak'**
  String get viewStreak;

  /// Accessibility label for the retry/refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Accessibility label prefix for the Your Path card on the home screen
  ///
  /// In en, this message translates to:
  /// **'Your Path'**
  String get upNext;

  /// Accessibility label for the donation information button
  ///
  /// In en, this message translates to:
  /// **'Donation info'**
  String get donationInfo;

  /// Accessibility label for the clear search button
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Accessibility label for the save button in the journal entry screen
  ///
  /// In en, this message translates to:
  /// **'Save journal entry'**
  String get saveJournalEntry;

  /// Accessibility label for the button that clears the saved default guide preference
  ///
  /// In en, this message translates to:
  /// **'Clear default guide'**
  String get clearDefault;

  /// Accessibility label for a locked track item
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockedContent;

  /// Stage 1 text in the Your Path explainer strip shown below the card on the home screen
  ///
  /// In en, this message translates to:
  /// **'Learn meditation one minute at a time. Sessions get longer as you learn.'**
  String get yourPathExplainerText;

  /// Stage 2 text in the Your Path explainer strip, shown after the user taps Got it
  ///
  /// In en, this message translates to:
  /// **'Swipe left to skip.'**
  String get yourPathExplainerSwipeHint;

  /// Step indicator label on onboarding question screen 1 (of 2)
  ///
  /// In en, this message translates to:
  /// **'1 of 2'**
  String get onboardingStep1of2;

  /// Step indicator label on onboarding question screen 2 (of 2)
  ///
  /// In en, this message translates to:
  /// **'2 of 2'**
  String get onboardingStep2of2;

  /// Question on onboarding screen 1 — asking about the user's meditation experience
  ///
  /// In en, this message translates to:
  /// **'Have you meditated before?'**
  String get onboardingExperienceQuestion;

  /// Subtext below the question on onboarding screen 1
  ///
  /// In en, this message translates to:
  /// **'This helps us show you the right starting point.'**
  String get onboardingExperienceSubtext;

  /// Option 1 on onboarding screen 1 — user has never meditated
  ///
  /// In en, this message translates to:
  /// **'Never tried it'**
  String get onboardingExperienceNever;

  /// Option 2 on onboarding screen 1 — user has meditated a little
  ///
  /// In en, this message translates to:
  /// **'A little, here and there'**
  String get onboardingExperienceALittle;

  /// Option 3 on onboarding screen 1 — user has a regular meditation practice
  ///
  /// In en, this message translates to:
  /// **'I have a regular practice'**
  String get onboardingExperienceRegular;

  /// Question on onboarding screen 2 — asking about the user's intention
  ///
  /// In en, this message translates to:
  /// **'What are you hoping to get from Medito?'**
  String get onboardingIntentQuestion;

  /// Subtext below the question on onboarding screen 2
  ///
  /// In en, this message translates to:
  /// **'Pick whichever feels most true right now.'**
  String get onboardingIntentSubtext;

  /// Option 1 on onboarding screen 2 — user wants to learn to meditate
  ///
  /// In en, this message translates to:
  /// **'Learn how to meditate properly'**
  String get onboardingIntentLearn;

  /// Option 2 on onboarding screen 2 — user wants to build a regular habit
  ///
  /// In en, this message translates to:
  /// **'Build a regular habit'**
  String get onboardingIntentHabit;

  /// Option 3 on onboarding screen 2 — user wants to manage stress, sleep, or emotions
  ///
  /// In en, this message translates to:
  /// **'Manage stress, sleep, or emotions'**
  String get onboardingIntentStress;

  /// Question on onboarding attribution screen — asking how the user discovered Medito
  ///
  /// In en, this message translates to:
  /// **'How did you hear about Medito?'**
  String get onboardingAttributionQuestion;

  /// Subtext below the attribution question on onboarding
  ///
  /// In en, this message translates to:
  /// **'This helps us reach more people who need it.'**
  String get onboardingAttributionSubtext;

  /// Attribution option — user found Medito via a Google ad
  ///
  /// In en, this message translates to:
  /// **'Google ad'**
  String get onboardingAttributionGoogleAd;

  /// Attribution option — user found Medito via an Instagram or Facebook ad
  ///
  /// In en, this message translates to:
  /// **'Instagram or Facebook ad'**
  String get onboardingAttributionSocialAd;

  /// Attribution option — user heard about Medito from a friend
  ///
  /// In en, this message translates to:
  /// **'A friend told me'**
  String get onboardingAttributionFriend;

  /// Attribution option — user was recommended Medito by a therapist or healthcare professional
  ///
  /// In en, this message translates to:
  /// **'Therapist or healthcare professional'**
  String get onboardingAttributionTherapist;

  /// Attribution option (iOS only) — user found Medito by browsing the App Store
  ///
  /// In en, this message translates to:
  /// **'App Store'**
  String get onboardingAttributionAppStore;

  /// Attribution option (Android only) — user found Medito by browsing the Play Store
  ///
  /// In en, this message translates to:
  /// **'Play Store'**
  String get onboardingAttributionPlayStore;

  /// Attribution option — user found Medito via some other means
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get onboardingAttributionOther;

  /// Label above the free-text field on the attribution question, prompting users to type their own answer
  ///
  /// In en, this message translates to:
  /// **'Something else?'**
  String get onboardingAttributionOtherLabel;

  /// Placeholder text inside the free-text attribution field
  ///
  /// In en, this message translates to:
  /// **'Tell us where you heard about us'**
  String get onboardingAttributionOtherHint;

  /// Heading on the onboarding result screen for users who are new or want to learn (State A)
  ///
  /// In en, this message translates to:
  /// **'You\'re in the right place.'**
  String get onboardingResultLearnHeading;

  /// Body text on the onboarding result screen for State A
  ///
  /// In en, this message translates to:
  /// **'We\'ll start you off with just 1 minute and build from there. No experience needed — just show up.'**
  String get onboardingResultLearnBody;

  /// Heading on the onboarding result screen for users with some experience (State B)
  ///
  /// In en, this message translates to:
  /// **'Good to have you here.'**
  String get onboardingResultEaseInHeading;

  /// Body text on the onboarding result screen for State B
  ///
  /// In en, this message translates to:
  /// **'We\'ll ease you back in with short sessions that build on each other. Go at whatever pace suits you.'**
  String get onboardingResultEaseInBody;

  /// Heading on the onboarding result screen for users with a regular practice (State C)
  ///
  /// In en, this message translates to:
  /// **'Welcome to Medito.'**
  String get onboardingResultPracticeHeading;

  /// Body text on the onboarding result screen for State C
  ///
  /// In en, this message translates to:
  /// **'Your Daily is a great place to keep your practice going. A fresh session is waiting for you every day.'**
  String get onboardingResultPracticeBody;

  /// CTA button label on the onboarding result screen
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingResultCta;

  /// Accessibility label for the favorite button when the item is not yet favorited
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// Accessibility label for the favorite button when the item is already favorited
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// Accessibility label for the pin button when the pack is not pinned
  ///
  /// In en, this message translates to:
  /// **'Pin to Your Path'**
  String get pinToUpNext;

  /// Accessibility label for the pin button when the pack is already pinned
  ///
  /// In en, this message translates to:
  /// **'Unpin from Your Path'**
  String get unpinFromUpNext;

  /// Title shown when the donation paywall webview fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load paywall'**
  String get connectionErrorTitle;

  /// Body text shown when the donation paywall webview fails to load
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get connectionErrorMessage;

  /// Retry button on the paywall load-error screen
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgainButton;

  /// Close button on the paywall load-error screen
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// Button at the bottom of a pack track list that marks every track complete
  ///
  /// In en, this message translates to:
  /// **'Mark all complete'**
  String get markAllComplete;

  /// Button at the bottom of a pack track list that clears completion on every track
  ///
  /// In en, this message translates to:
  /// **'Mark all incomplete'**
  String get markAllIncomplete;

  /// Accessibility label for the per-track toggle when the track is not complete
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get markTrackComplete;

  /// Accessibility label for the per-track toggle when the track is complete
  ///
  /// In en, this message translates to:
  /// **'Mark incomplete'**
  String get markTrackIncomplete;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
