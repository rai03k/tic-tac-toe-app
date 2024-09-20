import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admob/banner_ad_widget.dart';  // 再利用するバナー広告ウィジェットをインポート
import 'one_vs_one_game.dart';  // 1vs1ゲーム画面をインポート
import 'ai_game_screen.dart';  // 1vsAIゲーム画面をインポート
import '../admob/ad_removal.dart';  // 広告リセット画面をインポート

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _adsRemoved = false;

  @override
  void initState() {
    super.initState();
    _loadAdRemovalStatus();
  }

  // SharedPreferencesから広告削除のステータスを読み込む
  Future<void> _loadAdRemovalStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _adsRemoved = prefs.getBool('adsRemoved') ?? false;  // 広告削除状態を取得
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 広告削除状態を再度チェック
    _loadAdRemovalStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 40),

                  // 広告リセット画面遷移ボタンを追加
                  _buildMenuOption(
                    context,
                    Icons.ad_units,
                    Icons.cancel,
                    '-',
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdRemovalScreen()),
                      ).then((_) {
                        // AdRemovalScreenから戻った後に再度広告削除の状態をチェック
                        _loadAdRemovalStatus();
                      });
                    },
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrangeAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // バナー広告ウィジェットの再利用。広告が削除されている場合は非表示。
          if (!_adsRemoved)
            const BannerAdWidget(),
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
                fontSize: text == 'coming soon' ? 15 : 35,
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
