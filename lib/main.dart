import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // 画面の向きを固定するためのインポート
import 'package:device_preview/device_preview.dart';  // DevicePreviewのインポート
import 'package:flutter/foundation.dart';  // kReleaseMode用
import 'screens/menu_screen.dart';  // メニュー画面をインポート
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // バインディングの初期化
  MobileAds.instance.initialize();  // AdMobの初期化

  // 縦画面（Portrait）のみを許可
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,  // リリースモードでは無効化する
      builder: (context) => const MyApp(),  // アプリの起動
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;  // システムの明るさを取得

    return MaterialApp(
      useInheritedMediaQuery: true,  // これがDevicePreviewに必要
      locale: DevicePreview.locale(context),  // DevicePreviewのロケールを適用
      builder: DevicePreview.appBuilder,  // DevicePreviewのビルダーを適用
      title: 'Tic Tac Toe',
      theme: ThemeData(
        brightness: Brightness.light,  // ライトモードのテーマ
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,  // ダークモードのテーマ
      ),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,  // システム設定に合わせてテーマを切り替え
      home: const MenuScreen(),  // 最初にメニュー画面を表示
    );
  }
}
