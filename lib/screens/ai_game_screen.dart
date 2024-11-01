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
  final GameBoard _gameBoard = GameBoard(); // ゲームボードのインスタンスを作成
  bool _isPlayerTurn = true; // プレイヤーのターンかどうかを管理

  // ボードをリセットする関数
  void _resetBoard() {
    setState(() {
      _gameBoard.resetBoard();  // ゲームボードをリセット
      _isPlayerTurn = true;  // プレイヤーのターンにリセット
    });
  }

  // タップを処理する関数
  void _handleTap(int index) async {
    // プレイヤーのターンでない、またはすでに勝敗が決定している場合は無視
    if (!_isPlayerTurn || _gameBoard.winner.isNotEmpty) return;

    // プレイヤーのターン処理
    bool playerMove = await _gameBoard.handleTap(index);

    if (playerMove) {
      // プレイヤーのターンが終了したらAIに移行
      setState(() {
        _isPlayerTurn = false;  // プレイヤーのターン終了
      });

      // AIのターン（0.5秒遅延）
      Future.delayed(const Duration(milliseconds: 500), () async {
        int bestMove = _gameBoard.findBestMove();  // AIが最適な手を選択
        if (bestMove != -1) {
          await _gameBoard.handleTap(bestMove);  // AIの手を実行
        }
        setState(() {
          _isPlayerTurn = true;  // 再びプレイヤーのターン
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height; // 画面の高さを取得
    final screenWidth = MediaQuery.of(context).size.width; // 画面の幅を取得

    // 横幅が1000px以上の場合、goldenRatioを10.6に設定
    final double goldenRatio = screenHeight >= 1000 ? 10.6 : 5.6;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark; // ダークモードかどうか判定

    // ヘッダー、ゲームボード、リセットボタンの高さを調整
    final headerHeight = screenHeight / (goldenRatio + 1);

    // リセットボタンの位置を条件に応じて調整
    double resetButtonBottom = 80; // デフォルトは80
    if (screenHeight >= 1000 && screenWidth <= 810) {
      resetButtonBottom = 30;  // 画面が縦長の場合
    }
    if (screenHeight <= 750) {
      resetButtonBottom = 5;   // 画面が小さい場合
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              // ヘッダー部分
// ヘッダー部分
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _gameBoard.winner.isEmpty
                      ? (_gameBoard.isX ? Colors.redAccent : Colors.blueAccent) // プレイヤーのターンに応じた色
                      : (_gameBoard.isX ? Colors.blueAccent : Colors.redAccent), // 勝者に応じた色：Player 1なら赤、AIなら青
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                ),
                alignment: Alignment.bottomCenter,
                height: headerHeight, // ヘッダーの高さを調整
                child: Text(
                  _gameBoard.winner.isEmpty
                      ? (_gameBoard.isX ? 'Player 1\'s Turn' : 'AI\'s Turn') // 勝者がいない場合、プレイヤーまたはAIのターンを表示
                      : (_gameBoard.isX // 勝者が決定した場合の判定
                      ? 'AI Wins!' // Player 1が勝者ならAIが勝った場合のテキスト
                      : 'Player 1 Wins!'), // AIが勝者ならPlayer 1が勝った場合のテキスト
                  style: TextStyle(
                    color: isDarkMode ? Colors.black : Colors.white,
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
                          child: Icon(Icons.person,
                              color: isDarkMode ? Colors.white : Colors.white,
                              size: 72),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Player 1',
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(width: 40), // スペース
                    Text(
                      'VS',
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 40), // スペース
                    Column(
                      children: [
                        // AIのアイコン
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 40,
                          child: Icon(Icons.person,
                              color: isDarkMode ? Colors.white : Colors.white,
                              size: 72),
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
              Container(
                padding: EdgeInsets.only(
                  top: isPortraitAndNarrow ? 0 : 20,
                  bottom: 5,
                ),
                margin: const EdgeInsets.symmetric(vertical: 10),
                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                width: gameBoardSize,
                height: gameBoardSize,
                child: GameBoardWidget(
                  board: _gameBoard.board,
                  winningBlocks: _gameBoard.winningBlocks,
                  fadedIndex: _gameBoard.fadedIndex,
                  winner: _gameBoard.winner,
                  onTap: _handleTap,
                ),
              ),

              // リセットボタン
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isTablet ? 10 : 0),
                  // タブレットのみ下に10px追加
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _resetBoard, // リセットボタンが押された時にボードをリセット
                    child: Text(
                      'RESET',
                      style: TextStyle(
                          color: isDarkMode ? Colors.black : Colors.white,
                          fontSize: 18),
                    ),
                  ),
                ),
              ),

              // 広告バナー
              if (screenHeight > 750) const BannerAdWidget(),

              const Spacer(),
            ],
          ),

          // 戻るボタン
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: Icon(
                  Icons.arrow_back,
                  size: 30,
                  color: isDarkMode ? Colors.black : Colors.white
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}