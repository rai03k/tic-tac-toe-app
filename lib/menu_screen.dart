import 'package:flutter/material.dart';
import 'main.dart';  // 1vs1ゲーム画面をインポート
import 'ai.dart';  // 1vsAIゲーム画面をインポート

class MenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HOME',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black, // 黒文字でシンプルに
          ),
        ),
        backgroundColor: Colors.white, // ヘッダーも白に統一
        elevation: 0, // ヘッダーの影を消す
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,  // 背景を白に設定
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,  // ボタンを中央に配置
          children: [
            buildMenuOption(
              context,
              Icons.person,
              Icons.smart_toy,
              '1 vs AI',
              null, // 有効化してカスタム色を指定するためにnull
              true, // ボタン有効化
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TicTacToeAI()), // 1vsAIのゲーム画面に遷移
                );
              },
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blue]
              ),
            ),
            const SizedBox(height: 40),  // ボタン間の余白を調整
            buildMenuOption(
              context,
              Icons.person,
              Icons.person,
              '1 vs 1',
              null, // カスタム色を指定するためにnull
              true, // ボタン有効化
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TicTacToe()), // 1vs1のゲーム画面に遷移
                );
              },
              gradient: LinearGradient(
                colors: [Colors.redAccent, Colors.blueAccent],  // 赤から青のグラデーション
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            const SizedBox(height: 40),  // ボタン間の余白を調整
            buildMenuOption(
              context,
              Icons.person,
              Icons.public,
              '1 vs ?',
              Colors.grey, // 未実装のためグレー
              false,       // ボタン無効化
              null,        // ボタン無効
            ),
          ],
        ),
      ),
    );
  }

  // メニュー項目のボタンを作成するためのメソッド
  Widget buildMenuOption(
      BuildContext context,
      IconData icon1,
      IconData icon2,
      String text,
      Color? color,
      bool enabled,
      VoidCallback? onPressed, {
        LinearGradient? gradient, // グラデーションオプション
        Color? icon1Color, // 左のアイコン色
        Color? icon2Color, // 右のアイコン色
      }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient, // グラデーションがあれば適用
        color: color, // グラデーションがない場合の色
        borderRadius: BorderRadius.circular(30), // シンプルな四角に少し丸みを帯びたデザイン
      ),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null, // 未実装ならnullにして押せないようにする
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // ボタン自体の色を透明にし、背景のContainerを見せる
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // 外観はContainerのborderRadiusと一致させる
          ),
          shadowColor: Colors.transparent, // 影を消してシンプルに
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon1, size: 60, color: icon1Color ?? Colors.white),  // 左のアイコン
            Text(
              text,
              style: const TextStyle(
                fontSize: 45,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Icon(icon2, size: 60, color: icon2Color ?? Colors.white),  // 右のアイコン
          ],
        ),
      ),
    );
  }
}
