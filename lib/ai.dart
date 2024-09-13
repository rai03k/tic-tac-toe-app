import 'package:flutter/material.dart';
import 'menu_screen.dart';  // メニュー画面のインポート

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic Tac Toe',
      home: MenuScreen(),  // メニュー画面を最初に表示
    );
  }
}

class TicTacToeAI extends StatefulWidget {
  const TicTacToeAI({super.key});

  @override
  _TicTacToeAIState createState() => _TicTacToeAIState();
}

class _TicTacToeAIState extends State<TicTacToeAI> {
  List<String> _board = List.generate(9, (index) => ' '); // ボードの初期化
  bool _isX = true;
  String _winner = '';
  List<int> _winningBlocks = [];
  List<int> _xMoves = []; // Xの移動履歴を追跡
  List<int> _oMoves = []; // Oの移動履歴を追跡
  int? _fadedIndex; // 薄い色に変更されるマークのインデックス

  void _resetBoard() {
    setState(() {
      _board = List.generate(9, (index) => ' '); // ボードをリセット時に再初期化
      _isX = true;
      _winner = '';
      _winningBlocks = [];
      _xMoves = [];
      _oMoves = [];
      _fadedIndex = null;
    });
  }

  void _handleTap(int index) {
    if (_board[index] != ' ' || _winner != '') return;

    setState(() {
      _board[index] = 'X';
      _xMoves.add(index);
      if (_xMoves.length > 3) {
        int oldIndex = _xMoves.removeAt(0);
        _board[oldIndex] = ' '; // 消されたマークの場所を空に戻す
      }

      _winner = _checkWinner();
      if (_winner == '') _aiMove();  // 勝者がいなければAIのターン
    });
  }

  void _aiMove() async {
    await Future.delayed(const Duration(milliseconds: 500));
    int bestMove = _findBestMove(_board);
    setState(() {
      _board[bestMove] = 'O';
      _oMoves.add(bestMove);
      if (_oMoves.length > 3) {
        int oldIndex = _oMoves.removeAt(0);
        _board[oldIndex] = ' '; // 消されたマークの場所を空に戻す
      }

      _winner = _checkWinner();
    });
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
        board[i] = 'O';
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
    if (result == 'X') return -10 + depth;
    if (result == 'O') return 10 - depth;
    if (result == 'Draw') return 0;

    if (isMaximizing) {
      int bestScore = -1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          board[i] = 'O';
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
          board[i] = 'X';
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
    Color topColor;
    String topText;

    if (_winner == 'X') {
      topColor = Colors.redAccent;
      topText = 'Player 1 Wins!';
    } else if (_winner == 'O') {
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
                height: 100,
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
                  color: Colors.grey[300],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _buildBoard(),
                      const SizedBox(height: 50),
                      ElevatedButton(
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
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 30,
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
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        Color blockColor = Colors.white;
        Color textColor;

        if (_winner.isNotEmpty && _winningBlocks.contains(index)) {
          // 勝者が決定した後に色を反転
          blockColor = _board[index] == 'X' ? Colors.redAccent : Colors.blueAccent;
          textColor = Colors.white;
        } else {
          // 勝者がいない場合、通常の色を適用
          textColor = _board[index] == 'X'
              ? Colors.redAccent
              : _board[index] == 'O'
              ? Colors.blueAccent
              : Colors.transparent;
        }

        return GestureDetector(
          onTap: () => _handleTap(index),
          child: Container(
            padding: const EdgeInsets.only(bottom: 10),
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                _board[index].trim(),
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
