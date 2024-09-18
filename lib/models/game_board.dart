class GameBoard {
  List<String> board = List.generate(9, (index) => ' '); // ボードの初期化
  bool isX = true;
  String winner = '';
  List<int> winningBlocks = [];
  List<int> xMoves = [];
  List<int> oMoves = [];
  int? fadedIndex;

  // ボードをリセットする
  void resetBoard() {
    board = List.generate(9, (index) => ' ');
    isX = true;
    winner = '';
    winningBlocks = [];
    xMoves = [];
    oMoves = [];
    fadedIndex = null;
  }

  // プレイヤーの動きを処理
  bool handleTap(int index) {
    if (board[index] != ' ' || winner != '') return false;

    // 現在のプレイヤーの動きを処理
    board[index] = isX ? '×' : '○';
    (isX ? xMoves : oMoves).add(index);

    // 4つ目を置いた場合、1つ目を消す
    if ((isX ? xMoves : oMoves).length > 3) {
      int oldIndex = (isX ? xMoves : oMoves).removeAt(0);
      board[oldIndex] = ' ';
    }

    winner = _checkWinner();

    // プレイヤー交代前に、次のターンに備えてフェード処理を実行
    _handleMove();

    // プレイヤー交代
    isX = !isX;

    return true;
  }

  // 3つ前のマークを薄い色にする
  void _handleMove() {
    // Xのターンが終了し、Oの最初のマークを薄くする
    if (!isX && xMoves.length >= 3) {
      fadedIndex = xMoves[0];
    }
    // Oのターンが終了し、Xの最初のマークを薄くする
    else if (isX && oMoves.length >= 3) {
      fadedIndex = oMoves[0];
    } else {
      fadedIndex = null;
    }
  }

  // 勝者の判定を行う
  String _checkWinner() {
    const List<List<int>> winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6],
      [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6],
    ];

    for (var pattern in winPatterns) {
      String first = board[pattern[0]];
      if (first != ' ' &&
          first == board[pattern[1]] &&
          first == board[pattern[2]]) {
        winningBlocks = pattern;
        return first;
      }
    }
    return board.contains(' ') ? '' : 'Draw';
  }
}
