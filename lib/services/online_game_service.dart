// lib/services/online_game_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineGameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String gameId;
  static const int _moveTimeout = 30; // seconds

  OnlineGameService(this.gameId);

  // ゲームの状態をストリームで取得
  Stream<DocumentSnapshot> get gameStream {
    return _firestore
        .collection('games') // matches から games に変更
        .doc(gameId)
        .snapshots()
        .handleError((error) {
      print('Error in game stream: $error');
      throw Exception('ゲームデータの取得に失敗しました');
    });
  }

  // 手を打つ処理
  Future<void> makeMove(int index, String playerMark) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final gameDoc = _firestore.collection('games').doc(gameId); // コレクション名変更
        final snapshot = await transaction.get(gameDoc);

        if (!snapshot.exists) {
          throw Exception('ゲームが存在しません');
        }

        final data = snapshot.data()!;

        // 現在のターンをチェック
        if (data['currentTurn'] != playerMark) {
          // turn から currentTurn に変更
          throw Exception('不正なターンです');
        }

        // ボードの状態を取得
        List<String> board = List<String>.from(data['board']);

        // マスが既に埋まっているかチェック
        if (board[index] != ' ') {
          throw Exception('このマスは既に選択されています');
        }

        // 手を打つ
        board[index] = playerMark;
        String nextTurn = playerMark == 'X' ? 'O' : 'X';

        // 勝敗チェック
        final winnerInfo = _checkForWinner(board);

        // 更新データの準備
        final updates = {
          'board': board,
          'currentTurn':
              winnerInfo.winner.isEmpty ? nextTurn : '', // currentTurn に変更
          'winner': winnerInfo.winner,
          'lastMove': index,
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        // ゲームが終了した場合
        if (winnerInfo.winner.isNotEmpty) {
          updates['winningLine'] = winnerInfo.winningLine;
        }

        // トランザクション内でデータを更新
        transaction.update(gameDoc, updates);
      });
    } catch (e) {
      print('Error in makeMove: $e');
      rethrow;
    }
  }

  // ゲーム作成
  Future<void> createGame({
    required String player1Id,
    required String player2Id,
    required bool isAiMode,
  }) async {
    try {
      await _firestore.collection('games').doc(gameId).set({
        'player1': player1Id, // 先攻プレイヤーID
        'player2': player2Id, // 後攻プレイヤーID
        'board': List.filled(9, ' '),
        'currentTurn': 'X', // X が先攻
        'winner': '',
        'winningLine': [],
        'lastMove': -1,
        'isAiMode': isAiMode,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error in createGame: $e');
      rethrow;
    }
  }

  // 接続状態の更新
  Future<void> updateConnectionStatus(String playerId, bool isConnected) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'connections': {
          playerId: {
            'connected': isConnected,
            'lastActivity': FieldValue.serverTimestamp(),
          }
        },
      });
    } catch (e) {
      print('Error updating connection status: $e');
      rethrow;
    }
  }

  // ゲーム状態のバックアップ
  Future<void> backupGameState() async {
    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      if (!gameDoc.exists) return;

      await _firestore.collection('game_backups').add({
        'gameId': gameId,
        'data': gameDoc.data(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error in backup: $e');
      // エラーを無視してログのみ
    }
  }

  // ゲームのリセット（再対戦用）
  Future<void> resetGame() async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'board': List.filled(9, ' '),
        'currentTurn': 'X',
        'winner': '',
        'winningLine': [],
        'lastMove': -1,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error resetting game: $e');
      rethrow;
    }
  }

  // タイムアウトチェック
  Future<void> checkTimeout() async {
    try {
      final snapshot = await _firestore.collection('games').doc(gameId).get();

      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final lastUpdated = data['lastUpdated'] as Timestamp?;

      if (lastUpdated == null) return;

      final now = Timestamp.now();
      if (now.seconds - lastUpdated.seconds > _moveTimeout) {
        // 現在のターンのプレイヤーがタイムアウト（負け）
        String winner = data['currentTurn'] == 'X' ? 'O' : 'X';

        await _firestore.collection('games').doc(gameId).update({
          'winner': winner,
          'lastUpdated': FieldValue.serverTimestamp(),
          'timeoutReason': 'move_timeout',
        });
      }
    } catch (e) {
      print('Error in checkTimeout: $e');
      // エラーを無視してログのみ
    }
  }

  // 勝敗チェック
  WinnerInfo _checkForWinner(List<String> board) {
    const winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // 横
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // 縦
      [0, 4, 8], [2, 4, 6], // 斜め
    ];

    for (var pattern in winPatterns) {
      if (board[pattern[0]] != ' ' &&
          board[pattern[0]] == board[pattern[1]] &&
          board[pattern[1]] == board[pattern[2]]) {
        return WinnerInfo(
          winner: board[pattern[0]],
          winningLine: pattern,
        );
      }
    }

    // 引き分けチェック
    if (!board.contains(' ')) {
      return WinnerInfo(winner: ' ', winningLine: []); // 引き分けは空白文字に変更
    }

    return WinnerInfo(winner: '', winningLine: []);
  }

  // オポーネントの接続状態確認
  Future<bool> isOpponentConnected(String opponentId) async {
    try {
      final snapshot = await _firestore.collection('games').doc(gameId).get();
      if (!snapshot.exists) return false;

      final data = snapshot.data()!;
      final connections = data['connections'] as Map<String, dynamic>?;

      if (connections == null || !connections.containsKey(opponentId)) {
        return false;
      }

      return connections[opponentId]['connected'] == true;
    } catch (e) {
      print('Error checking opponent connection: $e');
      return false;
    }
  }
}

// 勝者情報を保持するクラス
class WinnerInfo {
  final String winner;
  final List<int> winningLine;

  WinnerInfo({
    required this.winner,
    required this.winningLine,
  });
}
