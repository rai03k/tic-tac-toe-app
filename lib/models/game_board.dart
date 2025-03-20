import 'package:audioplayers/audioplayers.dart';
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
  double _volume = 0.5; // 音量を50%に設定
  AIDifficulty _aiDifficulty = AIDifficulty.hard; // AIの難易度デフォルト値

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
    _audioPlayer.setVolume(_volume); // 音量を50%に設定
    _audioPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music, // sonificationからmusicに変更
        usageType: AndroidUsageType.media, // alarmからmediaに変更
        audioFocus: AndroidAudioFocus.gainTransientMayDuck, // 他のアプリの音量を一時的に下げる
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback, // ambientからplaybackに戻す
        options: <AVAudioSessionOptions>{
          AVAudioSessionOptions.mixWithOthers, // 他の音とミックス
          AVAudioSessionOptions.duckOthers, // 他のアプリの音量を下げる
        },
      ),
    ));
  }

  // 音量を設定するメソッド
  void setVolume(double volume) {
    if (volume >= 0.0 && volume <= 1.0) {
      _volume = volume;
      _audioPlayer.setVolume(_volume);
    }
  }

  // 現在の音量を取得するメソッド
  double getVolume() {
    return _volume;
  }

  // AIの難易度を設定するメソッド
  void setAIDifficulty(AIDifficulty difficulty) {
    _aiDifficulty = difficulty;

    // 難易度に応じてミニマックスの深さを調整
    switch (difficulty) {
      case AIDifficulty.easy:
        maxDepth = 2;
        break;
      case AIDifficulty.medium:
        maxDepth = 3;
        break;
      case AIDifficulty.hard:
        maxDepth = 5; // より深く先読みする
        break;
    }
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
      isX = true; // 最初はX
    } else if (xMoves.length == 1 && oMoves.isEmpty) {
      isX = false; // 2番目は必ずO
    }

    // 現在のプレイヤーの動きをボードに反映
    board[index] = isX ? '×' : '○';
    (isX ? xMoves : oMoves).add(index); // XかOの動きを記録

    // 音階を順番に再生
    await _playTapSound();

    // 4つ目のマークを置いた場合、1つ目のマークを削除
    if (isX && xMoves.length > 3) {
      int oldIndex = xMoves.removeAt(0); // 最古のマークを削除
      board[oldIndex] = ' '; // ボード上のマークを削除
      print("Xの最古のマーク（位置: $oldIndex）を削除しました");
    } else if (!isX && oMoves.length > 3) {
      int oldIndex = oMoves.removeAt(0); // 最古のマークを削除
      board[oldIndex] = ' '; // ボード上のマークを削除
      print("Oの最古のマーク（位置: $oldIndex）を削除しました");
    }

    // デバッグ用に盤面の状態を出力
    _debugBoardState();

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
    if (isAiMode && !isX && !isResetting && winner.isEmpty) {
      await Future.delayed(Duration(milliseconds: 500)); // 少し遅らせてAIの動きを模倣
      int aiMove = findBestMoveWithDifficulty(); // 難易度に応じた手を選択
      if (!isResetting) {
        // リセット中でなければAIの手を処理
        await handleTap(aiMove); // AIの手を処理
      }
    }

    return true; // タップが成功したことを返す
  }

  // ボードの状態をデバッグ出力
  void _debugBoardState() {
    int xCount = 0;
    int oCount = 0;
    for (String cell in board) {
      if (cell == '×') xCount++;
      if (cell == '○') oCount++;
    }
    print("ボード上のXの数: $xCount, Oの数: $oCount");
    print("X moves: $xMoves, O moves: $oMoves");

    String boardState = "";
    for (int i = 0; i < 9; i++) {
      boardState += board[i];
      if (i % 3 == 2)
        boardState += "\n";
      else
        boardState += " | ";
    }
    print("現在のボード状態:\n$boardState");
  }

  // 難易度を考慮したAIの手の選択
  int findBestMoveWithDifficulty() {
    // 簡単モードでは30%の確率でランダムな手を選ぶ
    if (_aiDifficulty == AIDifficulty.easy && Random().nextDouble() < 0.3) {
      List<int> emptyPositions = [];
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          emptyPositions.add(i);
        }
      }
      if (emptyPositions.isNotEmpty) {
        return emptyPositions[Random().nextInt(emptyPositions.length)];
      }
    }

    // 中級モードでは10%の確率で最適ではない手を選ぶ
    if (_aiDifficulty == AIDifficulty.medium && Random().nextDouble() < 0.1) {
      // 上位2番目までの手を選択できるようにする
      List<int> goodMoves = _findTopMoves(2);
      if (goodMoves.length > 1) {
        return goodMoves[1]; // 2番目に良い手
      }
    }

    // 通常は最適な手を選ぶ
    return findBestMove();
  }

  // 上位N個の良い手を見つける
  List<int> _findTopMoves(int n) {
    Map<int, int> moveScores = {};
    List<int> originalOMoves = List.from(oMoves);
    List<String> originalBoard = List.from(board);

    // 各手の評価スコアを計算
    for (int i = 0; i < board.length; i++) {
      if (board[i] == ' ') {
        board[i] = '○';
        oMoves.add(i);

        if (oMoves.length > 3) {
          int removedIndex = oMoves.removeAt(0);
          board[removedIndex] = ' ';
        }

        int score =
            minimax(board, 0, false, List.from(xMoves), List.from(oMoves));
        moveScores[i] = score;

        // 状態を復元
        board = List.from(originalBoard);
        oMoves = List.from(originalOMoves);
      }
    }

    // スコア順にソート
    List<MapEntry<int, int>> sortedMoves = moveScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // 降順ソート

    // 上位N個を返す
    return sortedMoves
        .take(min(n, sortedMoves.length))
        .map((e) => e.key)
        .toList();
  }

  // AIの手を決定する改良されたメソッド
  int findBestMove() {
    int bestMove = -1;
    int bestScore = -1000;

    // 元の状態を完全に保存
    List<String> originalBoard = List.from(board);
    List<int> originalOMoves = List.from(oMoves);

    // 空の位置を探索してシミュレーション
    for (int i = 0; i < board.length; i++) {
      if (board[i] == ' ') {
        // AIの手をシミュレーション
        board[i] = '○';
        oMoves.add(i);

        // 4つ目のマークを置いた場合の処理
        if (oMoves.length > 3) {
          int removedIndex = oMoves.removeAt(0);
          board[removedIndex] = ' ';
        }

        // 次の状態を評価
        int score =
            minimax(board, 0, false, List.from(xMoves), List.from(oMoves));

        // 元の状態に完全に戻す（重要！）
        board = List.from(originalBoard);
        oMoves = List.from(originalOMoves);

        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }

    // もし最善手が見つからなければ、ランダムに空いている場所を選ぶ
    if (bestMove == -1) {
      List<int> emptyPositions = [];
      for (int i = 0; i < board.length; i++) {
        if (board[i] == ' ') {
          emptyPositions.add(i);
        }
      }
      if (emptyPositions.isNotEmpty) {
        bestMove = emptyPositions[Random().nextInt(emptyPositions.length)];
      }
    }

    return bestMove;
  }

  // 改良されたミニマックスアルゴリズム（アルファベータ剪定付き）
  int minimax(List<String> simulationBoard, int depth, bool isMaximizing,
      List<int> simulatedXMoves, List<int> simulatedOMoves,
      [int alpha = -1000, int beta = 1000]) {
    // 勝者のチェック
    String result = _evaluateBoard(simulationBoard);
    if (result.isNotEmpty) {
      if (result == '○') return 100 - depth; // AIの勝利（深さが浅いほど価値が高い）
      if (result == '×') return depth - 100; // プレイヤーの勝利（深さが深いほどましな負け）
      return 0; // 引き分け
    }

    // 深さ制限に達した場合
    if (depth >= maxDepth) {
      return _evaluatePosition(
          simulationBoard, simulatedXMoves, simulatedOMoves);
    }

    if (isMaximizing) {
      // AIのターン（最大化）
      int bestScore = -1000;

      for (int i = 0; i < simulationBoard.length; i++) {
        if (simulationBoard[i] == ' ') {
          // 現在の状態を保存
          List<String> boardCopy = List.from(simulationBoard);
          List<int> oMovesCopy = List.from(simulatedOMoves);

          // AIの手を打つ
          simulationBoard[i] = '○';
          simulatedOMoves.add(i);

          // 4つ目のマークを置く場合、最古のマークを消す
          if (simulatedOMoves.length > 3) {
            int removedIndex = simulatedOMoves.removeAt(0);
            simulationBoard[removedIndex] = ' ';
          }

          // 次の状態を評価
          int score = minimax(simulationBoard, depth + 1, false,
              simulatedXMoves, simulatedOMoves, alpha, beta);

          // 状態を復元
          simulationBoard = boardCopy;
          simulatedOMoves = oMovesCopy;

          bestScore = max(score, bestScore);
          alpha = max(alpha, bestScore);

          // アルファベータ剪定
          if (beta <= alpha) break;
        }
      }
      return bestScore;
    } else {
      // プレイヤーのターン（最小化）
      int bestScore = 1000;

      for (int i = 0; i < simulationBoard.length; i++) {
        if (simulationBoard[i] == ' ') {
          // 現在の状態を保存
          List<String> boardCopy = List.from(simulationBoard);
          List<int> xMovesCopy = List.from(simulatedXMoves);

          // プレイヤーの手を打つ
          simulationBoard[i] = '×';
          simulatedXMoves.add(i);

          // 4つ目のマークを置く場合、最古のマークを消す
          if (simulatedXMoves.length > 3) {
            int removedIndex = simulatedXMoves.removeAt(0);
            simulationBoard[removedIndex] = ' ';
          }

          // 次の状態を評価
          int score = minimax(simulationBoard, depth + 1, true, simulatedXMoves,
              simulatedOMoves, alpha, beta);

          // 状態を復元
          simulationBoard = boardCopy;
          simulatedXMoves = xMovesCopy;

          bestScore = min(score, bestScore);
          beta = min(beta, bestScore);

          // アルファベータ剪定
          if (beta <= alpha) break;
        }
      }
      return bestScore;
    }
  }

  // 勝者の判定を行う
  String _checkWinner() {
    const List<List<int>> winPatterns = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
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

  // シミュレーション用の勝敗判定（winningBlocksを更新しない）
  String _evaluateBoard(List<String> simulatedBoard) {
    const List<List<int>> winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // 横の列
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // 縦の列
      [0, 4, 8], [2, 4, 6] // 斜めの列
    ];

    // 勝利パターンのチェック
    for (var pattern in winPatterns) {
      String first = simulatedBoard[pattern[0]];
      if (first != ' ' &&
          first == simulatedBoard[pattern[1]] &&
          first == simulatedBoard[pattern[2]]) {
        return first;
      }
    }

    return simulatedBoard.contains(' ') ? '' : 'Draw';
  }

  // 盤面の良さを数値評価する（ヒューリスティック評価関数）
  int _evaluatePosition(List<String> simulatedBoard, List<int> simulatedXMoves,
      List<int> simulatedOMoves) {
    int score = 0;
    const List<List<int>> winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // 横の列
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // 縦の列
      [0, 4, 8], [2, 4, 6] // 斜めの列
    ];

    // 各勝利パターンについて評価
    for (var pattern in winPatterns) {
      int countO = 0; // ○の数
      int countX = 0; // ×の数
      int emptyPos = -1; // 空きマスの位置

      for (int pos in pattern) {
        if (simulatedBoard[pos] == '○') {
          countO++;
        } else if (simulatedBoard[pos] == '×') {
          countX++;
        } else {
          emptyPos = pos;
        }
      }

      // スコア計算
      if (countO == 2 && countX == 0) {
        score += 10; // AIが2つ並んでいて、もう1つで勝ちの場合

        // この位置に置くとAIが勝つかどうかをチェック
        if (emptyPos != -1) {
          // 次に消えるのがこのパターンの一部か確認
          if (simulatedOMoves.length >= 3) {
            int nextToRemove = simulatedOMoves[0];
            // 消えるマークがこのパターンの一部でなければさらに高評価
            if (!pattern.contains(nextToRemove)) {
              score += 15;
            }
          }
        }
      }

      if (countX == 2 && countO == 0) {
        score -= 8; // プレイヤーが2つ並んでいて、もう1つで勝ちの場合（阻止すべき）

        // この位置に置くとプレイヤーが勝つのを阻止できるかチェック
        if (emptyPos != -1) {
          // 次に消えるプレイヤーのマークがこのパターンの一部か確認
          if (simulatedXMoves.length >= 3) {
            int nextToRemove = simulatedXMoves[0];
            // 消えるマークがこのパターンの一部ならば、阻止の優先度は低い
            if (pattern.contains(nextToRemove)) {
              score += 5; // 消えるのでそれほど脅威ではない
            } else {
              score -= 15; // 消えないのでより脅威
            }
          }
        }
      }
    }

    // 中央のマスを取ることで戦略的優位性を得る
    if (simulatedBoard[4] == '○') {
      score += 4;
    } else if (simulatedBoard[4] == '×') {
      score -= 4;
    }

    // 角のマスも価値がある
    for (int corner in [0, 2, 6, 8]) {
      if (simulatedBoard[corner] == '○') {
        score += 3;
      } else if (simulatedBoard[corner] == '×') {
        score -= 3;
      }
    }

    // 消えるマークに関する特殊戦略
    if (simulatedXMoves.length >= 3) {
      int nextToRemoveX = simulatedXMoves[0];
      // プレイヤーの消えるマークが有利な位置にある場合
      if ([0, 2, 4, 6, 8].contains(nextToRemoveX)) {
        score += 2; // その位置が空くのは有利
      }
    }

    if (simulatedOMoves.length >= 3) {
      int nextToRemoveO = simulatedOMoves[0];
      // AIの消えるマークが不利な位置にある場合
      if ([0, 2, 4, 6, 8].contains(nextToRemoveO)) {
        score -= 2; // その位置が空くのは不利
      }
    }

    return score;
  }

  // 有効なタップ時の音を再生
  Future<void> _playTapSound() async {
    try {
      // タップごとに音階を変えて再生
      String soundFile = _soundFiles[_tapCount % _soundFiles.length]; // 音階を選択
      await _audioPlayer.stop(); // 前の音声を停止
      await _audioPlayer.play(AssetSource(soundFile)); // 音声を再生
      _tapCount++; // タップ回数を増やす
    } catch (e) {
      print('Error playing tap sound: $e'); // エラーメッセージ
    }
  }

  // 無効なタップ時の音を再生
  Future<void> _playInvalidTapSound() async {
    try {
      await _audioPlayer.stop(); // 前の音声を停止
      await _audioPlayer.play(AssetSource('audio/not.mp3')); // 無効タップ音を再生
    } catch (e) {
      print('Error playing invalid tap sound: $e'); // エラーメッセージ
    }
  }

  // 勝利時の音を再生
  Future<void> _playWinSound() async {
    try {
      await _audioPlayer.stop(); // 前の音声を停止
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

  // リソースの解放
  void dispose() {
    _audioPlayer.dispose(); // AudioPlayerを解放
  }
}

// AIの難易度を表す列挙型
enum AIDifficulty { easy, medium, hard }
