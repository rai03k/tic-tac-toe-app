class GameBoard {
  List<String> _board = List.generate(9, (index) => ' '); // ボードの初期化
  bool _isX = true;
  String _winner = '';
  List<int> _winningBlocks = [];
  List<int> _xMoves = []; // Xの移動履歴を追跡
  List<int> _oMoves = []; // Oの移動履歴を追跡
  int? _fadedIndex; // 薄い色に変更されるマークのインデックス

  // ボードと状態を外部からアクセスできるようにゲッターを用意
  List<String> get board => _board;
  bool get isX => _isX;
  String get winner => _winner;
  List<int> get winningBlocks => _winningBlocks;
  int? get fadedIndex => _fadedIndex;

  // ボードをリセットするメソッド
  void resetBoard() {
    _board = List.generate(9, (index) => ' ');
    _isX = true;
    _winner = '';
    _winningBlocks = [];
    _xMoves = [];
    _oMoves = [];
    _fadedIndex = null;
  }

  // マスをタップしたときの処理
  bool handleTap(int index) {
    if (_board[index] != ' ' || _winner != '') return false;

    if (_isX) {
      _board[index] = 'X';
      _xMoves.add(index);
      if (_xMoves.length > 3) {
        int oldIndex = _xMoves.removeAt(0);
        _board[oldIndex] = ' ';
      }
    } else {
      _board[index] = 'O';
      _oMoves.add(index);
      if (_oMoves.length > 3) {
        int oldIndex = _oMoves.removeAt(0);
        _board[oldIndex] = ' ';
      }
    }

    _winner = _checkWinner();
    _isX = !_isX;
    _handleMove();
    return true;
  }

  // 3つ前のマークを薄い色にするロジック
  void _handleMove() {
    if (_isX && _xMoves.length == 3) {
      _fadedIndex = _xMoves[0];
    } else if (!_isX && _oMoves.length == 3) {
      _fadedIndex = _oMoves[0];
    } else {
      _fadedIndex = null;
    }
  }

  // 勝者の判定
  String _checkWinner() {
    const List<List<int>> winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];

    for (var pattern in winPatterns) {
      String first = _board[pattern[0]];
      if (first != ' ' && first == _board[pattern[1]] && first == _board[pattern[2]]) {
        _winningBlocks = pattern;
        return first;
      }
    }
    return _board.contains(' ') ? '' : 'Draw';
  }
}
