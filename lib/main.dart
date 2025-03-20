import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 画面の向きを固定するためのインポート
import 'screens/menu_screen.dart'; // メニュー画面をインポート
import 'screens/selection_screen.dart'; // 選択画面をインポート
import 'screens/matching_screen.dart'; // マッチング画面をインポート
import 'screens/game_screens/online_game_screen.dart'; // オンラインゲーム画面をインポート
import 'package:firebase_core/firebase_core.dart'; // Firebaseコアライブラリをインポート
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestoreを追加
import 'firebase/firebase_options.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:device_preview/device_preview.dart'; // DevicePreviewのインポート
import 'package:flutter/foundation.dart'; // kReleaseMode用

Future<void> _cleanupOldMatchingData() async {
  try {
    final firestore = FirebaseFirestore.instance;
    // 1日以上前のデータを削除する（ミリ秒に変換）
    final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

    final oldMatches = await firestore
        .collection('matching')
        .where('createdAt', isLessThan: Timestamp.fromDate(oneDayAgo))
        .get();

    for (var doc in oldMatches.docs) {
      await doc.reference.delete();
      print('Cleaned up old matching data: ${doc.id}');
    }
  } catch (e) {
    print('Error cleaning up old matching data: $e');
    // クリーンアップエラーは無視
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // バインディングの初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // 各プラットフォームの設定を使用
  );
  // 古いマッチングデータをクリーンアップ（追加）
  await _cleanupOldMatchingData();
  MobileAds.instance.initialize(); // AdMobの初期化

  // 縦画面（Portrait）のみを許可
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp()); // DevicePreviewを削除して通常のアプリ起動
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness; // システムの明るさを取得

    return MaterialApp(
      title: 'Tic Tac Toe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light, // ライトモードのテーマ
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark, // ダークモードのテーマ
      ),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light, // システム設定に合わせてテーマを切り替え
      initialRoute: '/', // 初期画面をメニュー画面に設定
      routes: {
        '/': (context) => const MenuScreen(),
        '/selection': (context) => const SelectionScreen(), // 選択画面
        '/matching': (context) => const MatchingScreen(), // マッチング画面
        '/online-game': (context) => const OnlineGameScreen(), // オンラインゲーム画面
      },
    );
  }
}
