import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // 画面の向きを固定するためのインポート
import 'screens/menu_screen.dart';  // メニュー画面をインポート
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // バインディングの初期化
  MobileAds.instance.initialize();  // AdMobの初期化

  // 縦画面（Portrait）のみを許可
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());  // DevicePreviewを削除して通常のアプリ起動
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;  // システムの明るさを取得

    return MaterialApp(
      title: 'Tic Tac Toe',
      debugShowCheckedModeBanner: false,
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
