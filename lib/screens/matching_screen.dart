import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  _MatchingScreenState createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen>
    with SingleTickerProviderStateMixin {
  bool isMatched = false; // マッチングが成立したかどうかを示すフラグ
  bool isRandom = true; // ランダムマッチかどうかを示すフラグ
  String? matchCode; // マッチコード（指定された場合）
  bool _visible = true; // アニメーションの表示/非表示を制御するフラグ
  String? errorMessage; // エラーメッセージの内容を保持

  // マッチング、バックアップ、アニメーションの各タイマー
  Timer? _matchingTimer;
  Timer? _backupTimer;
  Timer? _animationTimer;

  // タイムアウト時間（秒）
  static const int _timeoutSeconds = 30;

  // Firestoreのインスタンス
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference? _matchDocumentRef; // 現在のマッチングに関連するドキュメントの参照
  StreamSubscription? _matchSubscription; // マッチング状況のストリーム購読用
  final String _playerId = const Uuid().v4(); // プレイヤーID（UUIDを使用して一意のIDを生成）
  final Random _random = Random(); // ランダムな選択用に使用するRandomインスタンス

  // AIプレイヤー名のリスト
  final List<String> aiPlayerNames = [
    'Player123',
    'GamerPro',
    'TicTacMaster',
    'GameKing'
  ];

  // 対戦相手の名前を保持
  String opponentName = '';

  @override
  void initState() {
    super.initState();
    _startAnimationTimer(); // アニメーション用のタイマーを開始
    _startBackupTimer(); // データの定期バックアップ用タイマーを開始
    _setupConnectivitySubscription(); // ネットワーク接続の監視を設定
  }

  void _startAnimationTimer() {
    _animationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _visible = !_visible);
    });
  }

  void _startBackupTimer() {
    _backupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_matchDocumentRef != null) _backupMatchData();
    });
  }

  // ネットワークの接続状態を監視するストリームの購読設定
  void _setupConnectivitySubscription() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (connectivityResult == ConnectivityResult.none) {
        setState(() => errorMessage = 'ネットワーク接続がありません');
        _switchToAIMatch(); // 接続がない場合、AIとの対戦に切り替える
      } else {
        setState(() => errorMessage = null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 画面に渡された引数を取得し、マッチング条件を設定
    final args = ModalRoute
        .of(context)!
        .settings
        .arguments as Map;
    isRandom = args['isRandom']; // ランダムマッチか指定マッチかを確認
    matchCode = args['code']; // 指定マッチの場合のコード

    // マッチの種類に応じて対応するメソッドを呼び出す
    isRandom ? _startRandomMatching() : _joinMatchWithCode(matchCode!);
  }

  // ランダムマッチングの開始
  Future<void> _startRandomMatching() async {
    try {
      // マッチングのタイムアウト処理、一定時間後にAI対戦へ切り替え
      _matchingTimer = Timer(const Duration(seconds: 5), () {
        if (!isMatched) _switchToAIMatch(); // マッチが見つからない場合はAI対戦へ
      });

      // 「待機中」のマッチをFirestoreから取得（最大1件）
      final availableMatchQuery = await _firestore
          .collection('matches')
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      // 空きマッチがある場合は参加、なければ新規作成
      if (availableMatchQuery.docs.isNotEmpty && !isMatched) {
        _matchDocumentRef = availableMatchQuery.docs.first.reference;
        await _joinMatch(_matchDocumentRef!); // 既存のマッチに参加
        _listenForMatchUpdates(); // マッチの更新をリッスン開始
      } else if (!isMatched) {
        _matchDocumentRef = await _createNewMatch(); // 新規マッチ作成
        _listenForMatchUpdates(); // マッチの更新をリッスン開始
      }
    } catch (e) {
      _handleMatchingError(e.toString());
    }
  }

  // AI対戦への切り替え
  void _switchToAIMatch() {
    // マッチが存在する場合、その状態をキャンセルに更新
    _matchDocumentRef?.update({
      'status': 'cancelled',
      'lastActivity': FieldValue.serverTimestamp(),
    }).catchError((e) => print('Cleanup error: $e'));
    // マッチングタイマーとストリームの購読をキャンセル
    _matchingTimer?.cancel();
    _matchSubscription?.cancel();

    // ランダムにAIプレイヤー名を選択
    final selectedOpponent =
    aiPlayerNames[_random.nextInt(aiPlayerNames.length)];

    // マッチング成立と対戦相手の名前を設定
    setState(() {
      isMatched = true;
      opponentName = selectedOpponent;
    });

    // AI対戦画面に遷移
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/online-game',
          arguments: {
            'gameId': 'ai-${DateTime
                .now()
                .millisecondsSinceEpoch}', // AI戦識別ID
            'isAiMode': true, // AIモードかを指定
            'opponentName': selectedOpponent // 対戦相手の名前を渡す
          },
        );
      }
    });
  }

  // 新規マッチの作成
  Future<DocumentReference> _createNewMatch() async {
    // Firestoreに新しいマッチを追加
    return await _firestore.collection('matches').add({
      'player1': _playerId, // 現在のプレイヤーを登録
      'status': 'waiting', // ステータスを「待機中」に設定
      'code': const Uuid().v4(), // マッチコードをUUIDで生成
      'createdAt': FieldValue.serverTimestamp(), // 作成日時
      'connectionStatus': {'player1': 'connected'}, // 接続状態を「接続中」に設定
    });
  }

  // 既存のマッチに参加する部分
  Future<void> _joinMatch(DocumentReference matchRef) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);

        // マッチが存在しない、または既にマッチング済みの場合エラーをスロー
        if (!snapshot.exists || snapshot['status'] != 'waiting') {
          throw Exception('マッチが存在しません');
        }

        // プレイヤー2として参加し、マッチのステータスを更新
        transaction.update(matchRef, {
          'player2': _playerId,
          'status': 'matched',
          'matchedAt': FieldValue.serverTimestamp(),
          'connectionStatus.player2': 'connected',
        });
      });

      // マッチング成功後、ステータス更新
      setState(() => isMatched = true);
    } catch (e) {
      _handleMatchingError(e.toString());
    }
  }


  Future<void> _joinMatchWithCode(String code) async {
    try {
      // マッチを監視し続けるためのクエリ設定
      _matchSubscription = _firestore
          .collection('matches')
          .where('code', isEqualTo: code)
          .where('status', isEqualTo: 'waiting')
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.docs.isNotEmpty && !isMatched) {
          // マッチが見つかった場合
          _matchDocumentRef = snapshot.docs.first.reference;
          try {
            await _joinMatch(_matchDocumentRef!);
            _listenForMatchUpdates();
          } catch (e) {
            _handleMatchingError(e.toString());
          }
        }
      });

      // タイムアウトタイマーの設定
      _matchingTimer = Timer(const Duration(seconds: _timeoutSeconds), () {
        if (!isMatched) {
          _handleMatchingError('対戦相手が見つかりませんでした');
        }
      });
    } catch (e) {
      _handleMatchingError(e.toString());
    }
  }

  void _listenForMatchUpdates() {
    _matchSubscription = _matchDocumentRef?.snapshots().listen(
          (snapshot) {
        if (!snapshot.exists)
          return _handleMatchingError('マッチが存在しません');

        if (snapshot['status'] == 'matched' && !isMatched) {
          setState(() {
            isMatched = true;
            opponentName = 'Opponent';
          });
          _matchingTimer?.cancel();
          Navigator.pushReplacementNamed(
            context,
            '/online-game',
            arguments: {'gameId': _matchDocumentRef!.id, 'isAiMode': false},
          );
        }
      },
      onError: (error) => _handleMatchingError(error.toString()),
    );
  }

  Future<void> _backupMatchData() async {
    try {
      final snapshot = await _matchDocumentRef!.get();
      if (snapshot.exists) {
        await _firestore.collection('match_backups').add({
          'matchId': _matchDocumentRef!.id,
          'data': snapshot.data(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Backup failed: $e');
    }
  }

  void _handleMatchingError(String error) {
    setState(() => errorMessage = error);
    _showErrorDialog(error);
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            title: const Text('エラー'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _matchingTimer?.cancel();
    _backupTimer?.cancel();
    _animationTimer?.cancel();
    _matchSubscription?.cancel();

    if (!isMatched && _matchDocumentRef != null) {
      _cancelMatch();
    }

    super.dispose();
  }

  void _cancelMatch() {
    _matchDocumentRef?.update({
      'status': 'cancelled',
      'lastActivity': FieldValue.serverTimestamp(),
    }).catchError((e) => print('Cleanup error: $e'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マッチング中...'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _matchingTimer?.cancel();
            _backupTimer?.cancel();
            _matchSubscription?.cancel();
            if (!isMatched) _cancelMatch();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            if (errorMessage == null) ...[
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(seconds: 1),
                child: isRandom
                    ? Text(
                  '対戦相手を探しています...',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // 中央揃えに設定
                  children: [
                    Text(
                      'コード: $matchCode',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      '対戦相手を待っています...',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              if (isMatched)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    '対戦相手が見つかりました！',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
