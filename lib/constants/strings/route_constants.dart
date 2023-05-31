class RouteConstants {
  static const String root = '/';
  static const String homePath = '/home';
  static const String meditationPath = '/meditation/:sid';
  static const String dailyPath = '/daily/:did';
  static const String donationPath = '/donation';
  static const String playerPath = '/player';
  static const String articlePath = '/article/:aid';
  static const String folderPath = '/folder/:fid';
  static const String player1 = '/folder/:fid/meditation/:sid';
  static const String folder2Path = '/folder/:fid/folder2/:f2id';
  static const String player2 = '/folder/:fid/folder2/:f2id/meditation/:sid';
  static const String folder3Path = '/folder/:fid/folder2/:f2id/folder3/:f3id';
  static const String player3 =
      '/folder/:fid/folder2/:f2id/folder3/:f3id/meditation/:sid';
  static const String urlPath = '/url';
  static const String collectionPath = '/app';
  static const String webviewPath = '/webview';
  static const String backgroundSoundsPath = '/backgroundsounds';
  static const String joinIntroPath = '/joinIntro';
  static const String joinEmailPath = '/joinEmail';
  static const String joinVerifyOTPPath = '/joinVerifyOTP';
  static const String joinWelcomePath = '/joinWelcome';
}
