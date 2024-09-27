import 'dart:io';

class AdHelper {

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1187210314934709/9243517580'; // Androidのバナー広告ユニットID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-1187210314934709/7887834192'; // iOSのバナー広告ユニットID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

}
