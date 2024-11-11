// lib/services/online_game_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineGameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String gameId;
  static const int _moveTimeout = 30; // seconds

  OnlineGameService(this.gameId);

  // ゲームの状態をストリームで取得（エラーハンドリング追加）
  Stream<DocumentSnapshot> get gameStream {
    return _firestore
        .collection('matches')
        .doc(gameId)
        .snapshots()
        .handleError((error) {
      print('Error in game stream: $error');
      throw Exception('ゲームデータの取得に失敗しました');
    });
  }

  // 手を打つ処理（トランザクション処理とバリデーション追加）
  Future<void> makeMove(int index, String playerMark) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final gameDoc = _firestore.collection('matches').doc(gameId);
        final snapshot = await transaction.get(gameDoc);

        if (!snapshot.exists) {
          throw Exception('ゲームが存在しません');
        }

        final data = snapshot.data()!;

        // 現在のターンをチェック
        if (data['turn'] != playerMark) {
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
          'turn': winnerInfo.winner.isEmpty ? nextTurn : '',
          'winner': winnerInfo.winner,
          'lastMove': {
            'index': index,
            'player': playerMark,
            'timestamp': FieldValue.serverTimestamp(),
          },
          'lastUpdateTime': FieldValue.serverTimestamp(),
          // 手の履歴を保存
          'moves': FieldValue.arrayUnion([
            {
              'index': index,
              'player': playerMark,
              'timestamp': FieldValue.serverTimestamp(),
            }
          ]),
        };

        // ゲームが終了した場合
        if (winnerInfo.winner.isNotEmpty) {
          updates['status'] = 'completed';
          updates['endTime'] = FieldValue.serverTimestamp();
          updates['winningLine'] = winnerInfo.winningLine;
        }

        // トランザクション内でデータを更新
        transaction.update(gameDoc, updates);
      });

      // 手を打った後にバックアップを作成
      await backupGameState();
    } catch (e) {
      print('Error in makeMove: $e');
      rethrow;
    }
  }

  // ゲーム作成時の検証付き実装
  Future<void> createGame(List<String> initialBoard, String initialTurn) async {
    try {
      // データ検証
      if (initialBoard.length != 9 || !['X', 'O'].contains(initialTurn)) {
        throw Exception('不正なゲームデータです');
      }

      await _firestore.collection('matches').doc(gameId).set({
        'board': initialBoard,
        'turn': initialTurn,
        'winner': '',
        'status': 'active',
        'startTime': FieldValue.serverTimestamp(),
        'lastUpdateTime': FieldValue.serverTimestamp(),
        'moves': [],
        'players': {
          'X': null,
          'O': null,
        },
        'connectionStatus': {
          'X': 'connected',
          'O': 'waiting',
        },
      });
    } catch (e) {
      print('Error in createGame: $e');
      rethrow;
    }
  }

  // 接続状態の更新
  Future<void> updateConnectionStatus(bool isConnected, String playerMark) async {
    try {
      await _firestore.collection('matches').doc(gameId).update({
        'lastConnectionTime': FieldValue.serverTimestamp(),
        'connectionStatus.$playerMark': isConnected ? 'connected' : 'disconnected',
      });
    } catch (e) {
      print('Error updating connection status: $e');
      rethrow;
    }
  }

  // ゲーム状態のバックアップ
  Future<void> backupGameState() async {
    try {
      final gameDoc = await _firestore.collection('matches').doc(gameId).get();
      if (!gameDoc.exists) return;

      await _firestore.collection('game_backups').add({
        'gameId': gameId,
        'data': gameDoc.data(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error in backup: $e');
      rethrow;
    }
  }

  // タイムアウトチェック
  Future<void> checkTimeout() async {
    try {
      final snapshot = await _firestore.collection('matches').doc(gameId).get();

      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final lastMove = data['lastMove']?['timestamp'] as Timestamp?;

      if (lastMove == null) return;

      final now = Timestamp.now();
      if (now.seconds - lastMove.seconds > _moveTimeout) {
        await _firestore.collection('matches').doc(gameId).update({
          'status': 'timeout',
          'winner': data['turn'] == 'X' ? 'O' : 'X',
          'endTime': FieldValue.serverTimestamp(),
          'timeoutReason': 'move_timeout',
        });
      }
    } catch (e) {
      print('Error in checkTimeout: $e');
      rethrow;
    }
  }

  // 勝敗チェック（ロジックの改善）
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
      return WinnerInfo(winner: 'draw', winningLine: []);
    }

    return WinnerInfo(winner: '', winningLine: []);
  }

  // ゲームの再開処理
  Future<void> restoreFromBackup() async {
    try {
      final backups = await _firestore
          .collection('game_backups')
          .where('gameId', isEqualTo: gameId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (backups.docs.isEmpty) return;

      final latestBackup = backups.docs.first.data();
      await _firestore.collection('matches').doc(gameId).set(
        latestBackup['data'],
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error in restoreFromBackup: $e');
      rethrow;
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
