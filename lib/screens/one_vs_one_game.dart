import 'package:flutter/material.dart';
import '../models/game_board.dart';
import '../widgets/game_board_widget.dart';

class OneVsOneGame extends StatefulWidget {
  const OneVsOneGame({super.key});

  @override
  _OneVsOneGameState createState() => _OneVsOneGameState();
}

class _OneVsOneGameState extends State<OneVsOneGame> {
  final GameBoard _gameBoard = GameBoard(); // ゲームボードを管理するインスタンス

  void _handleTap(int index) {
    setState(() {
      _gameBoard.handleTap(index);
    });
  }

  void _resetBoard() {
    setState(() {
      _gameBoard.resetBoard();
    });
  }

  @override
  Widget build(BuildContext context) {
    Color topColor = _gameBoard.isX ? Colors.redAccent : Colors.blueAccent;
    String topText = _gameBoard.winner.isEmpty
        ? (_gameBoard.isX ? 'Player 1' : 'Player 2')
        : (_gameBoard.winner == 'Draw' ? 'Draw' : '${_gameBoard.winner} Wins!');

    return Scaffold(
      body: Column(
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
          Expanded(
            child: GameBoardWidget(
              gameBoard: _gameBoard,
              onTap: _handleTap,
            ),
          ),
          ElevatedButton(
            onPressed: _resetBoard,
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }
}
