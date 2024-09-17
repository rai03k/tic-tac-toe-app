import 'package:flutter/material.dart';
import 'one_vs_one_game.dart';  // 1vs1ゲーム画面をインポート
import 'ai_game_screen.dart';  // 1vsAIゲーム画面をインポート

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tic Tac Toe Menu',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black, // 黒文字でシンプルに
          ),
        ),
        backgroundColor: Colors.white, // ヘッダーを白に設定
        elevation: 0, // ヘッダーの影を消す
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,  // 背景色を白に設定
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
                  MaterialPageRoute(builder: (context) => const AIGameScreen()), // 1vsAIのゲーム画面に遷移
                );
              },
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],  // 青系のグラデーション
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            const SizedBox(height: 40),  // ボタン間の余白を調整
            _buildMenuOption(
              context,
              Icons.person,
              Icons.person,
              '1 vs 1',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OneVsOneGame()), // 1vs1のゲーム画面に遷移
                );
              },
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.blueAccent],  // 赤から青のグラデーション
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            const SizedBox(height: 40),  // ボタン間の余白を調整
            _buildMenuOption(
              context,
              Icons.person,
              Icons.public,
              '???',
              null,  // 未実装のため無効
              color: Colors.grey,  // 無効状態のグレー
            ),
          ],
        ),
      ),
    );
  }

  // メニュー項目のボタンを作成するためのメソッド
  Widget _buildMenuOption(
      BuildContext context,
      IconData icon1,
      IconData icon2,
      String text,
      VoidCallback? onPressed, {
        Color? color,
        LinearGradient? gradient, // グラデーションオプション
      }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient, // グラデーションがある場合は適用
        color: gradient == null ? color : null, // グラデーションがない場合の色
        borderRadius: BorderRadius.circular(30), // ボタンを丸みを帯びた形にする
      ),
      child: ElevatedButton(
        onPressed: onPressed, // 押せる場合はonPressedを設定
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // 背景の色を透明にしてContainerの色を見せる
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // ボタンの形状を統一
          ),
          shadowColor: Colors.transparent, // 影を消してフラットなデザインに
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon1, size: 60, color: Colors.white),  // 左のアイコン
            Text(
              text,
              style: const TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Icon(icon2, size: 60, color: Colors.white),  // 右のアイコン
          ],
        ),
      ),
    );
  }
}
