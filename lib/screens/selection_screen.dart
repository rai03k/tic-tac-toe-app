import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 数字入力のみを許可するために追加
import 'package:shared_preferences/shared_preferences.dart';
import '../data/language.dart'; // LanguageData クラスをインポート

class SelectionScreen extends StatefulWidget { // StatefulWidgetに変更
  const SelectionScreen({super.key});

  @override
  _SelectionScreenState createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  final TextEditingController codeController = TextEditingController();
  String _selectedLanguage = 'en'; // 初期言語
  bool isJoinButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage(); // 言語設定を読み込む
    codeController.addListener(_checkCodeLength); // リスナーを追加
  }

  // 言語設定をSharedPreferencesから読み込む
  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('selectedLanguage') ?? 'en';
    });
  }

  // コードの長さをチェックするメソッド
  void _checkCodeLength() {
    setState(() {
      isJoinButtonEnabled = codeController.text.length == 4;
    });
  }

  // 翻訳を取得する関数
  String _getTranslation(String key) {
    return LanguageData.getTranslation(_selectedLanguage, key);
  }

  // カードスタイルのボタン
  Widget _buildCardButton({
    required IconData icon,
    required String textKey, // 翻訳対応のためのキー
    required VoidCallback onTap,
    required Color color1,
    required Color color2,
    bool isEnabled = true, // ボタンの有効・無効状態
  }) {
    String buttonText = _getTranslation(textKey);
    return GestureDetector(
      onTap: isEnabled ? onTap : null, // 無効の場合はnull
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: isEnabled ? 5 : 0,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
        child: Container(
          decoration: BoxDecoration(
            gradient: isEnabled
                ? LinearGradient(
              colors: [color1, color2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isEnabled ? null : Colors.grey, // 無効時はグレー色
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 45, color: Colors.white),
              Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 23,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 5),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTranslation('selectMode')),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 50.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCardButton(
              icon: Icons.shuffle,
              textKey: 'randomMatch',
              onTap: () {
                Navigator.pushNamed(context, '/matching', arguments: {'isRandom': true});
              },
              color1: Colors.blueAccent,
              color2: Colors.lightBlueAccent,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0, left: 30.0, right: 30.0),
              child: TextField(
                controller: codeController,
                maxLength: 4, // 最大文字数を4に設定
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // 数字のみ許可
                ],
                textAlign: TextAlign.center, // テキストを中央揃えに設定
                style: const TextStyle(fontSize: 30), // テキストのサイズを大きく
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  labelText: '  ${_getTranslation('enterCode')}', // 言語対応
                  hintText: '****', // 例として****を表示
                  labelStyle: const TextStyle(
                    fontSize: 30, // ラベルのテキストサイズを設定
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildCardButton(
              icon: Icons.vpn_key,
              textKey: 'joinWithCode',
              onTap: () {
                Navigator.pushNamed(context, '/matching', arguments: {
                  'isRandom': false,
                  'code': codeController.text,
                });
              },
              color1: Colors.green,
              color2: Colors.teal,
              isEnabled: isJoinButtonEnabled, // 4桁入力でボタンが有効に
            ),
          ],
        ),
      ),
    );
  }
}
