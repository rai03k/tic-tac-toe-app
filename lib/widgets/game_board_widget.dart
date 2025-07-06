import 'package:flutter/material.dart';
import 'o_mark.dart'; // OMarkウィジェットのインポート
import 'x_mark.dart'; // XMarkウィジェットのインポート

class GameBoardWidget extends StatefulWidget {
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
  _GameBoardWidgetState createState() => _GameBoardWidgetState();
}

class _GameBoardWidgetState extends State<GameBoardWidget> {
  int _tapCount = 0; // タップ回数を管理

// GameBoardWidgetクラスの_buildMarkメソッドを修正

  // マークの表示ロジックを修正
  Widget _buildMark(String mark, Color markColor) {
    print('Building mark: "$mark" with color $markColor');

    // 'X'/'O'と'×'/'○'の両方に対応
    if (mark == 'X' || mark == '×') {
      // ×マークの場合
      return XMark(color: markColor); // カスタム色を渡す
    } else if (mark == 'O' || mark == '○') {
      // ○マークの場合
      return OMark(color: markColor); // カスタム色を渡す
    } else {
      // 空のマーク
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    double boardSize = MediaQuery.of(context).size.width * 0.9;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // デバッグ情報を表示
    print(
        'Building GameBoardWidget - board: ${widget.board}, winner: ${widget.winner}, isMyTurn: ${widget.onTap != null}');

    return Column(
      children: [
        const SizedBox(height: 10), // VS 表示と一番上のマスの間に10pxの余白を追加
        Container(
          padding: EdgeInsets.all(
              MediaQuery.of(context).size.width * 0.05), // 外枠の余白を設定
          color: isDarkMode ? Colors.grey[800] : Colors.grey[300], // 外枠の色
          child: Container(
            height: boardSize,
            width: boardSize,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(), // スクロールを無効化
              padding: EdgeInsets.zero, // 余分な余白を除去
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3列に設定
                childAspectRatio: 1.0, // 各マス目を正方形に設定
              ),
              itemCount: 9, // 9マスのボード
              itemBuilder: (context, index) {
                // マス目の背景色とマークの色
                Color blockColor = isDarkMode ? Colors.black : Colors.white;
                Color markColor;

                // マーク内容を出力
                if (widget.board[index] != ' ') {
                  print('Mark at index $index: "${widget.board[index]}"');
                }

                // 勝利時のマスとマークの色を変更
                if (widget.winner.isNotEmpty &&
                    widget.winningBlocks.contains(index)) {
                  blockColor =
                      widget.board[index] == 'X' || widget.board[index] == '×'
                          ? Colors.redAccent
                          : Colors.blueAccent; // 勝利時のマスの色
                  markColor =
                      isDarkMode ? Colors.black : Colors.white; // 勝利時のマークの色
                }
                // フェードインデックスに基づいてマークを薄く表示
                else if (widget.fadedIndex != null &&
                    index == widget.fadedIndex) {
                  markColor =
                      widget.board[index] == 'X' || widget.board[index] == '×'
                          ? Colors.redAccent.withOpacity(0.3)
                          : Colors.blueAccent.withOpacity(0.3);
                }
                // 通常のマーク
                else {
                  markColor = widget.board[index] == 'X' ||
                          widget.board[index] == '×'
                      ? Colors.redAccent
                      : widget.board[index] == 'O' || widget.board[index] == '○'
                          ? Colors.blueAccent
                          : Colors.transparent;
                }

                return Container(
                  padding: const EdgeInsets.all(5), // 各マスの周りに5pxのパディングを追加
                  color:
                      isDarkMode ? Colors.grey[800] : Colors.grey[300], // グレーの線
                  child: GestureDetector(
                    onTap: () {
                      // 勝敗が決まっていない場合のみタップを有効にする
                      if (widget.winner.isEmpty) {
                        // 空のマスをタップした場合
                        if (widget.board[index] == ' ') {
                          widget.onTap(index);
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: blockColor, // マス目の背景色
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: _buildMark(widget.board[index], markColor),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
