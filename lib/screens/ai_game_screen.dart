import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';  // AdMobのインポート
import '../models/game_board.dart';  // ゲームロジックをインポート
import '../widgets/game_board_widget.dart';  // ゲームボード描画用のウィジェット

class AIGameScreen extends StatefulWidget {
  const AIGameScreen({super.key});

  @override
  _AIGameScreenState createState() => _AIGameScreenState();
}

class _AIGameScreenState extends State<AIGameScreen> {
  final GameBoard _gameBoard = GameBoard();
  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;
  bool _isPlayerTurn = true;  // プレイヤーのターンかどうかを管理するフラグ

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: '<YOUR_AD_UNIT_ID>',  // 実際の広告ユニットIDに置き換えてください
      size: AdSize.banner,
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

  void _resetBoard() {
    setState(() {
      _gameBoard.resetBoard();
      _isPlayerTurn = true;  // リセット時にプレイヤーのターンを再び有効にする
    });
  }

  void _handleTap(int index) {
    if (!_isPlayerTurn || _gameBoard.winner.isNotEmpty) return;  // プレイヤーのターンでない、または勝敗が決まっている場合はタップ無効

    setState(() {
      if (_gameBoard.handleTap(index)) {
        // プレイヤーのターン終了、AIのターン開始
        _isPlayerTurn = false;

        // AIのターンを遅延して実行
        Future.delayed(const Duration(seconds: 1), () {
          setState(() {
            // AIが適当な空きマスに手を打つ（例としてランダムな空きマスを選択）
            _gameBoard.handleTap(_gameBoard.board.indexOf(' '));
            _isPlayerTurn = true;  // AIのターン終了、再びプレイヤーのターンを有効にする
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // 縦幅が800以上1000以下のときだけボタンを移動
    final shouldTranslate = screenHeight >= 800 && screenHeight <= 1000;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              // ヘッダー部分
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _gameBoard.isX ? Colors.redAccent : Colors.blueAccent,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                ),
                alignment: Alignment.bottomCenter,
                height: screenHeight * 0.15,
                child: Text(
                  _gameBoard.winner.isEmpty
                      ? (_gameBoard.isX ? 'Player 1' : 'AI')
                      : (_gameBoard.winner == 'Draw' ? 'Draw' : '${_gameBoard.winner} Wins!'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // プレイヤー表示部分
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          radius: 40,
                          child: Icon(Icons.person, color: Colors.white, size: 72),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Player 1',
                          style: TextStyle(color: Colors.black, fontSize: 20),
                        ),
                      ],
                    ),
                    SizedBox(width: 40),
                    Text(
                      'VS',
                      style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 40),
                    Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 40,
                          child: Icon(Icons.smart_toy, color: Colors.white, size: 72),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'AI',
                          style: TextStyle(color: Colors.black, fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ゲームボードとリセットボタンを包むコンテナ
              Expanded(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  color: Colors.grey[300], // 背景をグレーに設定
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ゲームボード
                      Expanded(
                        flex: 5,
                        child: GameBoardWidget(
                          board: _gameBoard.board,
                          winningBlocks: _gameBoard.winningBlocks,
                          fadedIndex: _gameBoard.fadedIndex,
                          winner: _gameBoard.winner,
                          onTap: _handleTap,
                        ),
                      ),

                      const SizedBox(height: 10), // ゲームボードとリセットボタンの間に余白

                      // リセットボタンを必要に応じて移動
                      Transform.translate(
                        offset: shouldTranslate ? const Offset(0, -50) : const Offset(0, 0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber, // リセットボタンの背景を黄色に設定
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _resetBoard,
                          child: const Text('RESET', style: TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                      ),

                      // バナー広告のためのスペース
                      if (_isBannerAdLoaded)
                        SizedBox(
                          height: _bannerAd.size.height.toDouble(),
                          width: MediaQuery.of(context).size.width,
                          child: AdWidget(ad: _bannerAd),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 戻るボタンを画面の左上に追加
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 30, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);  // 前の画面に戻る
              },
            ),
          ),
        ],
      ),
    );
  }
}
