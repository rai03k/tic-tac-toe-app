import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admob/banner_ad_widget.dart';  // 再利用するバナー広告ウィジェットをインポート
import 'one_vs_one_game.dart';  // 1vs1ゲーム画面をインポート
import 'ai_game_screen.dart';  // 1vsAIゲーム画面をインポート
import '../admob/ad_removal.dart';  // 広告リセット画面をインポート
import '../data/language.dart';  // 言語データをインポート

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _adsRemoved = false; // 広告が削除されているかのフラグ
  String _selectedLanguage = 'en'; // 初期言語

  @override
  void initState() {
    super.initState();
    _loadAdRemovalStatus();  // 広告削除のステータスを読み込む
    _loadLanguage();  // 言語設定を読み込む
  }

  // 言語設定をSharedPreferencesから読み込む
  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('selectedLanguage') ?? 'en';
    });
  }

  // 言語設定をSharedPreferencesに保存する
  Future<void> _saveLanguage(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLanguage', languageCode);
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  // 言語選択用のドロップダウンメニュー
  Widget _buildLanguageDropdown() {
    return DropdownButton<String>(
      value: _selectedLanguage,
      onChanged: (String? newLanguage) {
        if (newLanguage != null) {
          _saveLanguage(newLanguage);
        }
      },
      items: LanguageData.supportedLanguages.map<DropdownMenuItem<String>>((language) {
        return DropdownMenuItem<String>(
          value: language['code'],
          child: Text(language['label']!),
        );
      }).toList(),
    );
  }

  // SharedPreferencesから広告削除のステータスを読み込む関数
  Future<void> _loadAdRemovalStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();  // SharedPreferencesのインスタンスを取得
    setState(() {
      _adsRemoved = prefs.getBool('adsRemoved') ?? false;  // 広告削除状態を取得（デフォルトはfalse）
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
      appBar: AppBar(
        title: Text(LanguageData.getTranslation(_selectedLanguage, 'menuTitle')), // タイトルを翻訳対応
        centerTitle: true,  // タイトルを中央に配置
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildLanguageDropdown(),  // 言語選択ドロップダウンを右上に表示
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,  // ボタンと広告の間にスペースを確保
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,  // メニューオプションを中央に配置
                children: [
                  // 1 vs AIモードのボタン
                  _buildMenuOption(
                    context,
                    Icons.person,
                    Icons.smart_toy,
                    '1 vs AI',
                        () {
                      // 1 vs AIモードへ遷移
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AIGameScreen()),
                      );
                    },
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.lightBlueAccent],  // ボタンのグラデーション
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  const SizedBox(height: 40),  // ボタンの間にスペースを追加

                  // 1 vs 1モードのボタン
                  _buildMenuOption(
                    context,
                    Icons.person,
                    Icons.person,
                    '1 vs 1',
                        () {
                      // 1 vs 1モードへ遷移
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const OneVsOneGame()),
                      );
                    },
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.blueAccent],  // ボタンのグラデーション
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  const SizedBox(height: 40),  // ボタンの間にスペースを追加

                  // "Online" ボタン
                  _buildMenuOption(
                    context,
                    Icons.person,
                    Icons.public,
                    LanguageData.getTranslation(_selectedLanguage, 'onlineButton'), // ボタンを翻訳対応
                        () {
                      // 選択画面に遷移
                      Navigator.pushNamed(context, '/selection');
                    },
                    gradient: const LinearGradient(
                      colors: [Colors.green, Colors.tealAccent],  // グラデーションカラーを設定
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  const SizedBox(height: 40),  // ボタンの間にスペースを追加
                  // 広告リセット画面へのボタン
                  _buildMenuOption(
                    context,
                    Icons.ad_units,
                    Icons.cancel,
                    '-',
                        () {
                      // 広告リセット画面へ遷移
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdRemovalScreen()),
                      ).then((_) {
                        // 戻った後に広告削除状態を再チェック
                        _loadAdRemovalStatus();
                      });
                    },
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrangeAccent],  // 広告リセットボタンのグラデーション
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // バナー広告ウィジェットの再利用。広告が削除されている場合は表示しない
          if (!_adsRemoved)
            const BannerAdWidget(),
        ],
      ),
    );
  }

  // メニューオプションを作成する関数
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
        gradient: gradient,  // グラデーションが指定されていれば使用
        color: gradient == null ? color : null,  // グラデーションがない場合は指定色を使用
        borderRadius: BorderRadius.circular(30),  // 角を丸くする
      ),
      child: ElevatedButton(
        onPressed: onPressed,  // ボタンが押された時の処理
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,  // ボタンの背景色を透明に設定（デフォルトは設定しない）
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),  // パディングを設定
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),  // ボタンの角を丸くする
          ),
          shadowColor: Colors.transparent,  // 影をなくす
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,  // アイコンとテキストの配置を調整
          children: [
            Icon(icon1, size: 60, color: Colors.white),  // 左側のアイコン
            Text(
              text,  // ボタンのテキスト
              style: TextStyle(
                fontSize: text == 'オンライン' ? 25 : 35,  // "coming soon"は小さめのフォントにする
                fontWeight: FontWeight.bold,  // 太字にする
                color: Colors.white,  // テキストの色を白にする
              ),
            ),
            Icon(icon2, size: 60, color: Colors.white),  // 右側のアイコン
          ],
        ),
      ),
    );
  }
}
