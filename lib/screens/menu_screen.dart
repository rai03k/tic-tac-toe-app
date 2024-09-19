import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'one_vs_one_game.dart';  // 1vs1ゲーム画面をインポート
import 'ai_game_screen.dart';  // 1vsAIゲーム画面をインポート

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          color: Colors.white,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 28),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          color: Colors.black,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 28),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.system,  // システムのテーマに従って切り替える
      home: const MenuScreen(),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // テスト用ID
      size: const AdSize(width: 320, height: 70), // 高さを20px大きくする
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Failed to load a banner ad: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic Tac Toe Menu'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,  // ボタンと広告を分ける
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,  // ボタンを中央に配置
                children: [
                  _buildMenuOption(
                    context,
                    Icons.person,
                    Icons.smart_toy,
                    '1 vs AI',
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AIGameScreen()),
                      );
                    },
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.lightBlueAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildMenuOption(
                    context,
                    Icons.person,
                    Icons.person,
                    '1 vs 1',
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const OneVsOneGame()),
                      );
                    },
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.blueAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildMenuOption(
                    context,
                    Icons.person,
                    Icons.public,
                    'coming soon',
                    null,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_isBannerAdLoaded)
            SizedBox(
              height: _bannerAd.size.height.toDouble(),
              width: _bannerAd.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(
      BuildContext context,
      IconData icon1,
      IconData icon2,
      String text,
      VoidCallback? onPressed, {
        Color? color,
        LinearGradient? gradient,
      }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? color : null,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          shadowColor: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon1, size: 60, color: Colors.white),
            Text(
              text,
              style: TextStyle(
                fontSize: text == 'coming soon' ? 10 : 35,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Icon(icon2, size: 60, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
