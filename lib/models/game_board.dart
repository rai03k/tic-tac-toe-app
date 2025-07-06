import 'package:audioplayers/audioplayers.dart';  // AudioPlayerをインポート
import 'dart:math';


class GameBoard {
  List<String> board = List.generate(9, (index) => ' '); // ボードの初期化
  bool isX = true; // 現在のプレイヤーがXかどうかを判定
  String winner = ''; // 勝者の名前を保持
  List<int> winningBlocks = []; // 勝利したラインのインデックスを保持
  List<int> xMoves = []; // Xプレイヤーの動きを追跡
  List<int> oMoves = []; // Oプレイヤーの動きを追跡
  int? fadedIndex; // 薄くするマークのインデックス
  late AudioPlayer _audioPlayer; // 音声プレイヤー
  int _tapCount = 0; // タップ回数を管理して音階を変更する
  bool isAiMode = false; // 1vsAIモードかどうか
  int maxDepth = 4; // ミニマックスアルゴリズムの深さを設定
  bool isResetting = false; // リセット中かどうかを判定
  bool hasPlacedMark = false; // プレイヤーがマークを置いたかどうかを追跡

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
    _audioPlayer = AudioPlayer(); // AudioPlayerの初期化
    _audioPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm, // マナーモードでも音を鳴らす
        audioFocus: AndroidAudioFocus.gain, // フォーカスを取得して音を再生
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback, // マナーモードでも音を鳴らす
        options: <AVAudioSessionOptions>{
          AVAudioSessionOptions.mixWithOthers, // 他の音とミックス
        },
      ),
    ));
  }

// ボードをリセットする
  Future<void> resetBoard() async {
    isResetting = true; // リセット中フラグを立てる
    board = List.generate(9, (index) => ' '); // ボードをリセット
    winner = ''; // 勝者のリセット
    winningBlocks = []; // 勝利ラインのリセット
    xMoves = []; // Xプレイヤーの動きをリセット
    oMoves = []; // Oプレイヤーの動きをリセット
    fadedIndex = null; // 薄いマークのリセット
    _tapCount = 0; // タップカウントもリセット
    isX = true; // 必ずXプレイヤーから開始
    await Future.delayed(Duration(milliseconds: 500)); // 500msの遅延
    isResetting = false; // リセット完了
  }

  // プレイヤーの動きを処理
  Future<bool> handleTap(int index) async {
    if (isResetting || hasPlacedMark) return false; // リセット中なら処理を行わない
    if (winner.isNotEmpty) {
      // 勝敗が決定している場合はタップを無視
      return false;
    }

    if (board[index] != ' ') {
      // 無効なタップ音を再生
      await _playInvalidTapSound();
      return false;
    }

    // マークを1つだけ置けるようにするため、マークが置かれたらフラグを設定
    hasPlacedMark = true;

    // 最初のターンは必ずX、2番目は必ずO
    if (xMoves.isEmpty && oMoves.isEmpty) {
      isX = true;  // 最初はX
    } else if (xMoves.length == 1 && oMoves.isEmpty) {
      isX = false; // 2番目は必ずO
    }

    // 現在のプレイヤーの動きをボードに反映
    board[index] = isX ? '×' : '○';
    (isX ? xMoves : oMoves).add(index); // XかOの動きを記録

    // 音階を順番に再生
    await _playTapSound();

    // 4つ目のマークを置いた場合、1つ目のマークを削除
    if ((isX ? xMoves : oMoves).length > 3) {
      int oldIndex = (isX ? xMoves : oMoves).removeAt(0); // 最古のマークを削除
      board[oldIndex] = ' '; // ボード上のマークを削除
    }

    winner = _checkWinner(); // 勝者を確認

    // 勝者が決定した場合、勝利音を再生
    if (winner.isNotEmpty) {
      await _playWinSound();
    }

    // プレイヤー交代前に、フェード処理を実行
    _handleMove();

    // プレイヤーを交代
    isX = !isX;

    // 次のプレイヤーがマークを置けるようにフラグをリセット
    hasPlacedMark = false;

    // 1vsAIモードの場合、AIのターンが来る
    if (isAiMode && !isX && !isResetting) {
      await Future.delayed(Duration(milliseconds: 500)); // 少し遅らせてAIの動きを模倣
      int aiMove = findBestMove();
      if (!isResetting) { // リセット中でなければAIの手を処理
        await handleTap(aiMove); // AIの手を処理
      }
    }

    return true; // タップが成功したことを返す
  }

  // AIの手を決定するミニマックスアルゴリズムの実装
  int findBestMove() {
    int bestMove = -1; // 最適な手を保持
    int bestScore = -1000; // 最大のスコアを保持

    // 空の位置を探索
    for (int i = 0; i < board.length; i++) {
      if (board[i] == ' ') {
        board[i] = '○';  // AIは'○'としてプレイ
        int score = minimax(board, 0, false); // スコア計算
        board[i] = ' ';  // ボードを元に戻す

        if (score > bestScore) {
          bestScore = score; // 最大スコアを更新
          bestMove = i; // 最適な手を更新
        }
      }
    }
    return bestMove; // 最適な手を返す
  }

  // ミニマックスアルゴリズム
  int minimax(List<String> board, int depth, bool isMaximizing) {
    String result = _checkWinner(); // 勝者のチェック
    if (result.isNotEmpty) {
      if (result == '○') return 10 - depth;  // AIの勝利
      if (result == '×') return depth - 10;  // プレイヤーの勝利
      return 0;  // 引き分け
    }

    // 深さ制限に達した場合、評価を行わない
    if (depth >= maxDepth) {
      return 0;
    }

    // AIの最適な手を探索
    if (isMaximizing) {
      int bestScore = -1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          board[i] = '○';  // AIの手
          int score = minimax(board, depth + 1, false); // 再帰呼び出し
          board[i] = ' '; // ボードを元に戻す
          bestScore = max(score, bestScore); // 最大スコアを更新
        }
      }
      return bestScore;
    }
    // プレイヤーの最適な手を探索
    else {
      int bestScore = 1000;
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          board[i] = '×';  // プレイヤーの手
          int score = minimax(board, depth + 1, true); // 再帰呼び出し
          board[i] = ' '; // ボードを元に戻す
          bestScore = min(score, bestScore); // 最小スコアを更新
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

    // 各勝利パターンをチェック
    for (var pattern in winPatterns) {
      String first = board[pattern[0]];
      if (first != ' ' &&
          first == board[pattern[1]] &&
          first == board[pattern[2]]) {
        winningBlocks = pattern;
        return first;
      }
    }
    return board.contains(' ') ? '' : 'Draw'; // 引き分け判定
  }

  // 有効なタップ時の音を再生
  Future<void> _playTapSound() async {
    try {
      // タップごとに音階を変えて再生
      String soundFile = _soundFiles[_tapCount % _soundFiles.length]; // 音階を選択
      await _audioPlayer.play(AssetSource(soundFile)); // 音声を再生
      _tapCount++; // タップ回数を増やす
    } catch (e) {
      print('Error playing tap sound: $e'); // エラーメッセージ
    }
  }

  // 無効なタップ時の音を再生
  Future<void> _playInvalidTapSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/not.mp3')); // 無効タップ音を再生
    } catch (e) {
      print('Error playing invalid tap sound: $e'); // エラーメッセージ
    }
  }

  // 勝利時の音を再生
  Future<void> _playWinSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/complete.mp3')); // 勝利音を再生
    } catch (e) {
      print('Error playing win sound: $e'); // エラーメッセージ
    }
  }

  // 3つ前のマークを薄い色にする
  void _handleMove() {
    // Xのターンが終了し、Oの最初のマークを薄くする
    if (!isX && xMoves.length >= 3) {
      fadedIndex = xMoves[0]; // 最古のXマークを薄くする
    }
    // Oのターンが終了し、Xの最初のマークを薄くする
    else if (isX && oMoves.length >= 3) {
      fadedIndex = oMoves[0]; // 最古のOマークを薄くする
    } else {
      fadedIndex = null; // フェードなし
    }
  }
}
