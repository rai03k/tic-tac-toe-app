import 'package:audioplayers/audioplayers.dart';  // AudioPlayerをインポート
import 'dart:math';

class GameBoard {
  List<String> board = List.generate(9, (index) => ' '); // ボードの初期化
  bool isX = true;
  String winner = '';
  List<int> winningBlocks = [];
  List<int> xMoves = [];
  List<int> oMoves = [];
  int? fadedIndex;
  late AudioPlayer _audioPlayer;
  int _tapCount = 0; // タップ回数を管理して音階を変更する
  int maxDepth = 4; // ミニマックスアルゴリズムの深さを設定

  // 音階のリスト
  final List<String> _soundFiles = [
    'audio/do.mp3',
    'audio/re.mp3',
    'audio/mi.mp3',
    'audio/fa.mp3',
    'audio/so.mp3',
    'audio/la.mp3',
    'audio/si.mp3',
  ];

  GameBoard() {
    _audioPlayer = AudioPlayer();
  }

  // ボードをリセットする
  void resetBoard() {
    board = List.generate(9, (index) => ' ');
    isX = true;
    winner = '';
    winningBlocks = [];
    xMoves = [];
    oMoves = [];
    fadedIndex = null;
    _tapCount = 0; // タップカウントもリセット
  }

  // プレイヤーの動きを処理
  Future<bool> handleTap(int index) async {
    if (winner.isNotEmpty) {
      // 勝敗が決定している場合はタップを無視
      return false;
    }

    if (board[index] != ' ') {
      // 無効なタップ音を再生
      await _playInvalidTapSound();
      return false;
    }

    // 現在のプレイヤーの動きを処理
    board[index] = isX ? '×' : '○';
    (isX ? xMoves : oMoves).add(index);

    // 音階を順番に再生
    await _playTapSound();

    // 4つ目を置いた場合、1つ目を消す
    if ((isX ? xMoves : oMoves).length > 3) {
      int oldIndex = (isX ? xMoves : oMoves).removeAt(0);
      board[oldIndex] = ' ';
    }

    winner = _checkWinner();

    // 勝者が決まった場合、勝利音を再生
    if (winner.isNotEmpty) {
      await _playWinSound();
    }

    // プレイヤー交代前に、次のターンに備えてフェード処理を実行
    _handleMove();

    // プレイヤー交代
    isX = !isX;

    return true;
  }

  // AIの手を決定するミニマックスアルゴリズムの実装
  int findBestMove() {
    int bestMove = -1;
    int bestScore = -1000;

    for (int i = 0; i < board.length; i++) {
      if (board[i] == ' ') {
        board[i] = '○';  // AIは'○'としてプレイ
        int score = minimax(board, 0, false);
        board[i] = ' ';  // ボードを元に戻す

        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }
    return bestMove;
  }

  // ミニマックスアルゴリズム
  int minimax(List<String> board, int depth, bool isMaximizing) {
    String result = _checkWinner();
    if (result.isNotEmpty) {
      if (result == '○') return 10 - depth;  // AIの勝利
      if (result == '×') return depth - 10;  // プレイヤーの勝利
      return 0;  // 引き分け
    }

    // 深さ制限に達した場合、評価を行わない
    if (depth >= maxDepth) {
      return 0;
    }

    if (isMaximizing) {
      int bestScore = -1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          board[i] = '○';  // AIの手
          int score = minimax(board, depth + 1, false);
          board[i] = ' ';
          bestScore = max(score, bestScore);
        }
      }
      return bestScore;
    } else {
      int bestScore = 1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          board[i] = '×';  // プレイヤーの手
          int score = minimax(board, depth + 1, true);
          board[i] = ' ';
          bestScore = min(score, bestScore);
        }
      }
      return bestScore;
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

  // 有効なタップ時の音を再生
  Future<void> _playTapSound() async {
    try {
      // タップごとに音階を変えて再生
      String soundFile = _soundFiles[_tapCount % _soundFiles.length];
      await _audioPlayer.play(AssetSource(soundFile));
      _tapCount++; // 次の音階へ移行
    } catch (e) {
      print('Error playing tap sound: $e');
    }
  }

  // 無効なタップ時の音を再生
  Future<void> _playInvalidTapSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/not.mp3'));
    } catch (e) {
      print('Error playing invalid tap sound: $e');
    }
  }

  // 勝利時の音を再生
  Future<void> _playWinSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/complete.mp3'));
    } catch (e) {
      print('Error playing win sound: $e');
    }
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
}
