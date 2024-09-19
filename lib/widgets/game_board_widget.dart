import 'package:flutter/material.dart';
import 'o_mark.dart';  // OMarkウィジェットのインポート
import 'x_mark.dart';  // XMarkウィジェットのインポート

class GameBoardWidget extends StatelessWidget {
  final List<String> board;
  final List<int> winningBlocks;
  final int? fadedIndex;
  final String winner;
  final void Function(int) onTap;

  const GameBoardWidget({
    required this.board,
    required this.winningBlocks,
    required this.fadedIndex,
    required this.winner,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double boardSize = MediaQuery.of(context).size.width * 1.0;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: boardSize,
      width: boardSize,
      // ダークモードの場合は背景を暗く、ライトモードの場合は通常のグレー
      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          // ダークモードの場合はマス目を黒、ライトモードは白に設定
          Color blockColor = isDarkMode ? Colors.black : Colors.white;
          Color markColor;

          // 勝利時のマスの色とマークの色
          if (winner.isNotEmpty && winningBlocks.contains(index)) {
            blockColor = isDarkMode ? Colors.black : blockColor;
            markColor = Colors.white;  // 勝利時のマークは白
          }
          // フェードインデックスに基づいてマークを薄く表示
          else if (fadedIndex != null && index == fadedIndex) {
            markColor = board[index] == '×'
                ? Colors.redAccent.withOpacity(0.3)
                : Colors.blueAccent.withOpacity(0.3);
          }
          // 通常のマーク
          else {
            markColor = board[index] == '×'
                ? Colors.redAccent
                : board[index] == '○'
                ? Colors.blueAccent
                : Colors.transparent;
          }

          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              margin: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: blockColor,  // マス目の背景色
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: _buildMark(board[index], markColor),
              ),
            ),
          );
        },
      ),
    );
  }

  // マークの表示ロジック
  Widget _buildMark(String mark, Color markColor) {
    if (mark == '×') {
      // ×マークの場合
      return XMark(color: markColor);  // カスタム色を渡す
    } else if (mark == '○') {
      // ○マークの場合
      return OMark(color: markColor);  // カスタム色を渡す
    } else {
      // 空のマーク
      return const SizedBox.shrink();
    }
  }
}
