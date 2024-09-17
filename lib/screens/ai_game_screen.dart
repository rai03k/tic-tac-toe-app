import 'package:flutter/material.dart';
import 'menu_screen.dart';  // メニュー画面のインポート
import 'package:flutter/material.dart';
import '../models/game_board.dart'; // ゲームロジック
import '../widgets/game_board_widget.dart'; // 共通のボードウィジェット

class AIGameScreen extends StatefulWidget {
  const AIGameScreen({super.key});

  @override
  _AIGameScreenState createState() => _AIGameScreenState();
}

class _AIGameScreenState extends State<AIGameScreen> {
  List<String> _board = List.generate(9, (index) => ' '); // ボードの初期化
  bool _isX = true;
  String _winner = '';
  List<int> _winningBlocks = [];
  List<int> _xMoves = []; // Xの移動履歴を追跡
  List<int> _oMoves = []; // Oの移動履歴を追跡
  int? _fadedIndex; // 薄い色に変更されるマークのインデックス
  bool _isAITurn = false; // AIのターンを管理するフラグ

  void _resetBoard() {
    setState(() {
      _board = List.generate(9, (index) => ' '); // ボードをリセット時に再初期化
      _isX = true;
      _winner = '';
      _winningBlocks = [];
      _xMoves = [];
      _oMoves = [];
      _fadedIndex = null;
      _isAITurn = false; // リセット時にAIのターンを初期化
    });
  }

  void _handleTap(int index) {
    if (_board[index] != ' ' || _winner != '' || _isAITurn) return; // AIのターン中はタップ無効

    setState(() {
      _board[index] = '×';  // "X"を"×"に変更
      _xMoves.add(index);
      if (_xMoves.length > 3) {
        int oldIndex = _xMoves.removeAt(0);
        _board[oldIndex] = ' '; // 消されたマークの場所を空に戻す
      }

      _winner = _checkWinner();
      if (_winner == '') {
        _isAITurn = true;  // AIのターンを開始前にセット
        _aiMove();  // 勝者がいなければAIのターン
      }
    });
  }

  void _aiMove() async {
    await Future.delayed(const Duration(milliseconds: 500));
    int bestMove = _findBestMove(_board);
    setState(() {
      _board[bestMove] = '○';  // "O"を"○"に変更
      _oMoves.add(bestMove);
      if (_oMoves.length > 3) {
        int oldIndex = _oMoves.removeAt(0);
        _board[oldIndex] = ' '; // 消されたマークの場所を空に戻す
      }

      _winner = _checkWinner();
      _isX = !_isX;
      _isAITurn = false; // AIのターン終了時にセット解除

      _handleMove();
    });
  }

  void _handleMove() {
    // 4つ前のマークを薄い色にするロジック
    if (!_isX && _xMoves.length >= 3) {
      _fadedIndex = _xMoves[0];
    } else if (_isX && _oMoves.length >= 3) {
      _fadedIndex = _oMoves[0];
    } else {
      _fadedIndex = null; // 3つ未満の場合は薄く表示するマークがない
    }
  }

  String _checkWinner() {
    const List<List<int>> winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6],
      [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6],
    ];

    for (var pattern in winPatterns) {
      String first = _board[pattern[0]];
      if (first != ' ' &&
          first == _board[pattern[1]] &&
          first == _board[pattern[2]]) {
        setState(() {
          _winningBlocks = pattern;
        });
        return first;
      }
    }
    return _board.contains(' ') ? '' : 'Draw';
  }

  int _findBestMove(List<String> board) {
    int bestScore = -1000;
    int bestMove = -1;
    for (int i = 0; i < board.length; i++) {
      if (board[i] == ' ') {
        board[i] = '○';  // AIの手を"○"に変更
        int score = _minimax(board, 0, false);
        board[i] = ' ';
        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }
    return bestMove;
  }

  int _minimax(List<String> board, int depth, bool isMaximizing) {
    if (depth >= 4) {
      // 深さ4で探索を打ち切る
      return 0;
    }
    String result = _checkWinner();
    if (result == '×') return -10 + depth;
    if (result == '○') return 10 - depth;
    if (result == 'Draw') return 0;

    if (isMaximizing) {
      int bestScore = -1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          board[i] = '○';
          int score = _minimax(board, depth + 1, false);
          board[i] = ' ';
          bestScore = score > bestScore ? score : bestScore;
        }
      }
      return bestScore;
    } else {
      int bestScore = 1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          board[i] = '×';
          int score = _minimax(board, depth + 1, true);
          board[i] = ' ';
          bestScore = score < bestScore ? score : bestScore;
        }
      }
      return bestScore;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    bool isMobile = screenWidth < 600;
    Color topColor;
    String topText;

    if (_winner == '×') {
      topColor = Colors.redAccent;
      topText = 'Player 1 Wins!';
    } else if (_winner == '○') {
      topColor = Colors.blueAccent;
      topText = 'AI Wins!';
    } else {
      topColor = _isX ? Colors.redAccent : Colors.blueAccent;
      topText = _isX ? 'Player 1' : 'AI';
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: topColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                ),
                alignment: Alignment.bottomCenter,
                height: screenHeight * 0.15,
                child: Text(
                  topText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
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
              Expanded(
                flex: 2,
                child: Container(
                  width: screenWidth,
                  color: Colors.grey[300],
                  child: Transform.translate(
                    offset: isMobile ? const Offset(0, -30) : Offset.zero,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(child: _buildBoard()),
                        const SizedBox(height: 20),
                        Transform.translate(
                          offset: isMobile ? const Offset(0, -20) : Offset.zero,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _resetBoard,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, color: Colors.white),
                                SizedBox(width: 10),
                                Text('RESET', style: TextStyle(color: Colors.white, fontSize: 18)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: screenHeight * 0.03,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 55),
              onPressed: () {
                Navigator.pop(context);  // メニューに戻る
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    double deviceHeight = MediaQuery.of(context).size.height;
    double deviceWidth = MediaQuery.of(context).size.width;

    double boardSize = deviceWidth * 1.2;
    if (boardSize > deviceHeight * 0.6) {
      boardSize = deviceWidth * 0.8;
    }

    double baseFontSize = boardSize * 0.15;

    return Container(
      height: boardSize,
      width: boardSize,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          Color blockColor = Colors.white;
          Color textColor;

          if (_winner.isNotEmpty && _winningBlocks.contains(index)) {
            blockColor = _board[index] == '×' ? Colors.redAccent : Colors.blueAccent;
            textColor = Colors.white;
          } else if (_fadedIndex != null && index == _fadedIndex) {
            textColor = _board[index] == '×'
                ? Colors.redAccent.withOpacity(0.3)
                : Colors.blueAccent.withOpacity(0.3);
          } else {
            textColor = _board[index] == '×'
                ? Colors.redAccent
                : _board[index] == '○'
                ? Colors.blueAccent
                : Colors.transparent;
          }

          return GestureDetector(
            onTap: () => _handleTap(index),
            child: Container(
              margin: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double fontSize = baseFontSize;

                  return Center(
                    child: Text(
                      _board[index] != ' ' ? _board[index] : '',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
