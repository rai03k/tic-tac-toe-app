import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/game_board.dart';  // ゲームロジックをインポート
import '../widgets/game_board_widget.dart';  // ゲームボード描画用のウィジェット

class OneVsOneGame extends StatefulWidget {
  const OneVsOneGame({super.key});

  @override
  _OneVsOneGameState createState() => _OneVsOneGameState();
}

class _OneVsOneGameState extends State<OneVsOneGame> {
  final GameBoard _gameBoard = GameBoard();
  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;

  static const double goldenRatio = 5.6;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/9214589741', // 実際の広告ユニットIDに置き換えてください
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
    });
  }

  void _handleTap(int index) {
    setState(() {
      _gameBoard.handleTap(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 縦幅が800以上1000以下のときだけボタンを移動
    final shouldTranslate = screenHeight >= 800 && screenHeight <= 1000;

    // ヘッダー、ゲームボード、リセットボタンの高さを調整
    final headerHeight = screenHeight / (goldenRatio + 1); // 基づくヘッダーの高さ

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              // ヘッダー部分（基づいて高さを調整）
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
                height: headerHeight,  // ヘッダーの高さ
                child: Text(
                  _gameBoard.winner.isEmpty
                      ? (_gameBoard.isX ? 'Player 1' : 'Player 2')
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
                          child: Icon(Icons.person, color: Colors.white, size: 72),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Player 2',
                          style: TextStyle(color: Colors.black, fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ゲームボードとリセットボタン
              Expanded(
                child: Container(
                  width: screenWidth,
                  color: Colors.grey[300],
                  child: Column(
                    children: [
                      // ゲームボード部分
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
                      const SizedBox(height: 10),

                      // リセットボタンを条件に応じて移動
                      Transform.translate(
                        offset: shouldTranslate ? const Offset(0, -50) : const Offset(0, 0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _resetBoard,
                          child: const Text('RESET', style: TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                      ),

                      // 広告との間にスペースを確保
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // バナー広告
              if (_isBannerAdLoaded)
                SizedBox(
                  height: _bannerAd.size.height.toDouble(),
                  width: _bannerAd.size.width.toDouble(),
                  child: AdWidget(ad: _bannerAd),
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
