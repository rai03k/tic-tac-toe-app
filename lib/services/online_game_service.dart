// lib/services/online_game_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineGameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String gameId;

  OnlineGameService(this.gameId);

  // ゲームの状態をストリームで取得
  Stream<DocumentSnapshot> get gameStream {
    return _firestore.collection('matches').doc(gameId).snapshots();
  }

// ゲームの状態を更新
  Future<void> makeMove(int index, String playerMark) async {
    final gameDoc = _firestore.collection('matches').doc(gameId);
    final snapshot = await gameDoc.get();
    if (snapshot.exists) {
      List<String> board = List<String>.from(snapshot['board']);
      board[index] = playerMark;
      String nextTurn = playerMark == 'X' ? 'O' : 'X';

      // 勝者のチェックを行う
      String winner = _checkForWinner(board);

      // Firestoreに更新
      await gameDoc.update({
        'board': board,
        'turn': winner.isEmpty ? nextTurn : '', // 勝者がいる場合、ターンは空に設定
        'winner': winner,
      });
    }
  }


  // 新規ゲームの作成
  Future<void> createGame(List<String> initialBoard, String initialTurn) async {
    await _firestore.collection('matches').doc(gameId).set({
      'board': initialBoard,
      'turn': initialTurn,
      'winner': '',
    });
  }

  // 勝者のチェック
  String _checkForWinner(List<String> board) {
    // 縦・横・斜めのラインをチェックして勝者を判定
    const List<List<int>> winningLines = [
      [0, 1, 2], // 横のライン
      [3, 4, 5], // 横のライン
      [6, 7, 8], // 横のライン
      [0, 3, 6], // 縦のライン
      [1, 4, 7], // 縦のライン
      [2, 5, 8], // 縦のライン
      [0, 4, 8], // 斜めのライン
      [2, 4, 6], // 斜めのライン
    ];

    for (var line in winningLines) {
      if (board[line[0]] != ' ' &&
          board[line[0]] == board[line[1]] &&
          board[line[1]] == board[line[2]]) {
        return board[line[0]]; // 勝者のマーク (X または O) を返す
      }
    }

    // すべてのマスが埋まっていたら引き分けと判定
    if (!board.contains(' ')) {
      return 'draw'; // 引き分けの場合に 'draw' を返す
    }

    return ''; // 勝者がいない場合は空文字を返す
  }
}
