import 'package:flutter/material.dart';
import '../models/game_board.dart'; // ゲームのロジック
import 'o_mark.dart'; // Oマークのカスタムウィジェット
import 'x_mark.dart'; // Xマークのカスタムウィジェット

class GameBoardWidget extends StatelessWidget {
  final GameBoard gameBoard;
  final void Function(int) onTap;

  const GameBoardWidget({required this.gameBoard, required this.onTap, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        Color blockColor = Colors.white;
        Widget? markWidget;

        if (gameBoard.board[index] == 'X') {
          markWidget = const XMark(); // Xマークウィジェットを使用
        } else if (gameBoard.board[index] == 'O') {
          markWidget = const OMark(); // Oマークウィジェットを使用
        }

        if (gameBoard.winningBlocks.contains(index)) {
          blockColor = Colors.greenAccent; // 勝利したブロックを強調
        }

        return GestureDetector(
          onTap: () => onTap(index),
          child: Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(child: markWidget), // マークウィジェットを中央に配置
          ),
        );
      },
    );
  }
}
