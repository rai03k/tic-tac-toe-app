import 'package:flutter/material.dart';
import '../models/game_board.dart';  // ゲームロジックをインポート
import '../widgets/game_board_widget.dart';  // ゲームボード描画用のウィジェット
import '../admob/banner_ad_widget.dart';  // バナー広告ウィジェットをインポート

class AIGameScreen extends StatefulWidget {
  const AIGameScreen({super.key});

  @override
  _AIGameScreenState createState() => _AIGameScreenState();
}

class _AIGameScreenState extends State<AIGameScreen> {
  final GameBoard _gameBoard = GameBoard();
  bool _isPlayerTurn = true;

  void _resetBoard() {
    setState(() {
      _gameBoard.resetBoard();
      _isPlayerTurn = true;
    });
  }

  void _handleTap(int index) async {
    if (!_isPlayerTurn || _gameBoard.winner.isNotEmpty) return;

    // プレイヤーのターン
    bool playerMove = await _gameBoard.handleTap(index);

    if (playerMove) {
      setState(() {
        _isPlayerTurn = false;
      });

      // AIのターン（1秒遅延）
      Future.delayed(const Duration(seconds: 1), () async {
        int bestMove = _gameBoard.findBestMove();  // AIが最適な手を選択
        if (bestMove != -1) {
          await _gameBoard.handleTap(bestMove);  // AIが選んだ手を実行
        }
        setState(() {
          _isPlayerTurn = true;  // 再びプレイヤーのターン
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 横幅が1000px以上の場合、goldenRatioを10.6に変更
    final double goldenRatio = screenHeight >= 1000 ? 10.6 : 5.6;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // ヘッダー、ゲームボード、リセットボタンの高さを調整
    final headerHeight = screenHeight / (goldenRatio + 1);

    // リセットボタンの位置を条件に応じて変更
    double resetButtonBottom = 80; // デフォルトは80
    if (screenHeight >= 1000 && screenWidth <= 810) {
      resetButtonBottom = 30;  // 縦が1000以上、横が810以下の場合は30
    }
    if (screenHeight <= 750) {
      resetButtonBottom = 5;   // 縦が750以下の場合は5
    }

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
                height: headerHeight,
                child: Text(
                  _gameBoard.winner.isEmpty
                      ? (_gameBoard.isX ? 'Player 1' : 'AI')
                      : (_gameBoard.winner == 'Draw' ? 'Draw' : '${_gameBoard.winner} Wins!'),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // プレイヤー表示部分
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          radius: 40,
                          child: Icon(Icons.person, color: isDarkMode ? Colors.white : Colors.white, size: 72),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Player 1',
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(width: 40),
                    Text(
                      'VS',
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 40),
                    Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 40,
                          child: Icon(Icons.smart_toy, color: isDarkMode ? Colors.white : Colors.white, size: 72),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI',
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ゲームボード部分
              Expanded(
                child: Container(
                  width: screenWidth,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  child: GameBoardWidget(
                    board: _gameBoard.board,
                    winningBlocks: _gameBoard.winningBlocks,
                    fadedIndex: _gameBoard.fadedIndex,
                    winner: _gameBoard.winner,
                    onTap: _handleTap,
                  ),
                ),
              ),
            ],
          ),

          // リセットボタン
          Positioned(
            bottom: resetButtonBottom,  // 条件に基づいてbottomの値を設定
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _resetBoard,
                child: Text(
                  'RESET',
                  style: TextStyle(color: isDarkMode ? Colors.black : Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),

          // バナー広告
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BannerAdWidget(),  // バナー広告を表示
          ),

          // 戻るボタン
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 30, color: isDarkMode ? Colors.black : Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
