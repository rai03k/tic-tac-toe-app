// 必要なパッケージをインポート
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
  // マッチングが成立しているかのフラグ
  bool isMatched = false;
  // ランダムマッチングかどうかのフラグ
  bool isRandom = true;
  // マッチコード（指定マッチング用）
  String? matchCode;
  // アニメーション表示用のフラグ
  bool _visible = true;
  // エラーメッセージ（ネットワーク切断など）
  String? errorMessage;
  // エラーダイアログを一度だけ表示するためのフラグ
  bool _hasShownError = false;

  // タイマー管理
  Timer? _matchingTimer;
  Timer? _backupTimer;
  Timer? _animationTimer;

  // マッチングタイムアウトの秒数
  static const int _timeoutSeconds = 60; // タイムアウトを60秒に延長

  // Firestore インスタンス
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // マッチングに使用するドキュメントリファレンス
  DocumentReference? _matchDocumentRef;
  // Firestore のストリーム購読を管理するための変数
  StreamSubscription? _matchSubscription;
  // プレイヤーID（UUID を生成）
  final String _playerId = const Uuid().v4();
  // ランダム処理用のインスタンス
  final Random _random = Random();

  // AIプレイヤー名のリスト
  final List<String> aiPlayerNames = [
    'AIテスト',
  ];

  // 対戦相手の名前
  String opponentName = '';
  // プレイヤーが先攻か後攻かを示すマーク
  String _playerMark = '';
  // 自分が先攻かどうかを示すフラグ
  bool _isPlayerFirst = false;

  // デバッグ用ログ関数
  void _debugLog(String message) {
    print('🔍 [MatchingScreen] $message');
  }

  @override
  void initState() {
    super.initState();
    _startAnimationTimer(); // アニメーションのタイマー開始
    _startBackupTimer();    // データバックアップ用のタイマー開始
    _setupConnectivitySubscription(); // ネットワーク状態の監視を開始
  }

  // アニメーションのためのタイマーを設定
  void _startAnimationTimer() {
    _animationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _visible = !_visible); // 1秒ごとに表示・非表示を切り替え
      }
    });
  }

  // バックアップ用のタイマーを設定
  void _startBackupTimer() {
    _backupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_matchDocumentRef != null) {
        _debugLog('Running backup for match: ${_matchDocumentRef!.id}');
        _backupMatchData(); // マッチデータのバックアップを行う
      }
    });
  }

  // ネットワーク状態の監視をセットアップ
  void _setupConnectivitySubscription() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      _debugLog('Network connectivity status: $connectivityResult');
      if (connectivityResult == ConnectivityResult.none) {
        // ネットワーク接続がない場合のエラーハンドリング
        if (isRandom && !_hasShownError) {
          setState(() => errorMessage = 'ネットワーク接続がありません');
          _showErrorDialog('ネットワーク接続がありません');
          _hasShownError = true;
        }
      } else {
        setState(() => errorMessage = null); // ネットワーク復旧時にエラーをクリア
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 画面遷移時に渡された引数を取得
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      isRandom = args['isRandom'] as bool? ?? true;
      matchCode = args['code'] as String?;

      if (isRandom) {
        _startRandomMatching(); // ランダムマッチングを開始
      } else if (matchCode != null) {
        _joinMatchWithCode(matchCode!); // コード指定マッチングに参加
      }
    } else {
      _debugLog('Invalid arguments passed to MatchingScreen');
      _handleMatchingError('無効な引数が渡されました'); // 引数が無効の場合のエラーハンドリング
    }
  }

  // ランダムマッチングを開始
  Future<void> _startRandomMatching() async {
    try {
      _debugLog('Starting random matching...');
      // Firestore でマッチング検索のクエリを構築
      Query matchQuery = _firestore
          .collection('matches')
          .where('status', isEqualTo: 'waiting')
          .where('player2', isNull: true);

      // 利用可能なマッチのクエリを取得
      final availableMatchQuery = await matchQuery.limit(1).get();

      _debugLog('Found ${availableMatchQuery.docs.length} available matches for random matching');

      if (availableMatchQuery.docs.isNotEmpty && !isMatched) {
        // 利用可能なマッチが存在する場合、それに参加
        final matchData = availableMatchQuery.docs.first.data() as Map<String, dynamic>;
        if (matchData['player1'] != _playerId) { // 自分自身のマッチではないことを確認
          _matchDocumentRef = availableMatchQuery.docs.first.reference;
          _debugLog('Joining available match with ID: ${_matchDocumentRef!.id}');
          await _joinMatch(_matchDocumentRef!);
        } else {
          _debugLog('Skipping own match with ID: ${availableMatchQuery.docs.first.id}');
        }
      } else if (!isMatched) {
        // 利用可能なマッチがない場合、新しいマッチを作成
        _debugLog('No available match found, creating a new match');
        _matchDocumentRef = await _createNewMatch();

        setState(() {
          _playerMark = 'X'; // 先攻に設定
          _isPlayerFirst = true; // 先攻に設定
        });

        _debugLog('Created new match - PlayerMark: $_playerMark, IsFirst: $_isPlayerFirst');
      }

      _listenForMatchUpdates();
    } catch (e) {
      _debugLog('Error in random matching: $e');
      _handleMatchingError(e.toString());
    }
  }

  // 指定されたコードでのマッチに参加
  Future<void> _joinMatchWithCode(String code) async {
    try {
      while (!isMatched) {
        _debugLog('Attempting to join match with code: $code');
        // Firestore でマッチング待機状態のドキュメントを検索
        final matchQuery = await _firestore
            .collection('matches')
            .where('code', isEqualTo: code)
            .where('status', isEqualTo: 'waiting')
            .limit(1)
            .get();

        _debugLog('Found ${matchQuery.docs.length} matches with code: $code');

        if (matchQuery.docs.isNotEmpty) {
          _matchDocumentRef = matchQuery.docs.first.reference;
          _debugLog('Joining match with ID: ${_matchDocumentRef!.id}');
          await _joinMatch(_matchDocumentRef!); // マッチに参加
          break;
        }

        await Future.delayed(const Duration(seconds: 2)); // 2秒待機して再試行
      }
    } catch (e) {
      _debugLog('Error joining match with code: $e');
    }
  }

  // マッチに参加する
  Future<void> _joinMatch(DocumentReference matchRef) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        final data = snapshot.data() as Map<String, dynamic>?;

        if (snapshot.exists && data != null && data['status'] == 'waiting' && data['player2'] == null) {
          _debugLog('Joining as player2, setting up roles...');

          transaction.update(matchRef, {
            'player2': _playerId,
            'status': 'matched',
            'matchedAt': FieldValue.serverTimestamp(),
            'playerX': data['player1'],  // 既存のplayer1を先行(X)に設定
            'playerO': _playerId,        // 参加者を後攻(O)に設定
            'turn': 'X',
            'board': List.filled(9, ' '),
          });

          _debugLog('Player2 role assigned - Mark: O, First: false');
        } else {
          throw Exception('Match is no longer available or already filled');
        }
      });

      // トランザクション成功後にStateを更新
      setState(() {
        isMatched = true;
        opponentName = '相手';
        _playerMark = 'O';      // 参加者は必ず後攻
        _isPlayerFirst = false; // 参加者は必ず後攻
      });

      _debugLog('Join successful - PlayerMark: $_playerMark, IsFirst: $_isPlayerFirst');
    } catch (e) {
      _debugLog('Error in _joinMatch: $e');
      _handleMatchingError(e.toString());
      return;
    }
  }

  // 新しいマッチを作成
  Future<DocumentReference> _createNewMatch() async {
    try {
      _debugLog('Creating new match as player1...');

      final newMatch = await _firestore.collection('matches').add({
        'player1': _playerId,
        'player2': null,
        'playerX': _playerId,  // 作成者を先行(X)に設定
        'playerO': null,
        'status': 'waiting',
        'code': isRandom ? null : matchCode,
        'createdAt': FieldValue.serverTimestamp(),
        'turn': 'X',
        'board': List.filled(9, ' '),
      });

      setState(() {
        _playerMark = 'X';      // 作成者は必ず先行
        _isPlayerFirst = true;  // 作成者は必ず先行
        opponentName = '相手';
      });

      _debugLog('New match created - PlayerMark: $_playerMark, IsFirst: $_isPlayerFirst');

      return newMatch;
    } catch (e) {
      _debugLog('Error in _createNewMatch: $e');
      rethrow;
    }
  }

  // マッチングの更新をリッスンして反映
  void _listenForMatchUpdates() {
    _debugLog('Starting match updates listener...');
    _matchSubscription = _matchDocumentRef?.snapshots().listen(
          (snapshot) {
        if (!snapshot.exists) {
          _debugLog('Match document no longer exists');
          _handleMatchingError('マッチが存在しません');
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) return;

        _debugLog('Match update received - Status: ${data['status']}');
        _debugLog('Current playerX: ${data['playerX']}, playerO: ${data['playerO']}');
        _debugLog('My playerId: $_playerId');

        if (data['status'] == 'matched' && !isMatched) {
          // 自分のプレイヤーIDと役割を比較
          String myRole;
          bool amIFirst;

          if (data['playerX'] == _playerId) {
            myRole = 'X';
            amIFirst = true;
            _debugLog('I am playerX (first player)');
          } else if (data['playerO'] == _playerId) {
            myRole = 'O';
            amIFirst = false;
            _debugLog('I am playerO (second player)');
          } else {
            _debugLog('Error: Could not determine player role');
            return;
          }

          setState(() {
            isMatched = true;
            opponentName = '相手';
            _playerMark = myRole;
            _isPlayerFirst = amIFirst;
          });

          _debugLog('Match state updated - Mark: $_playerMark, IsFirst: $_isPlayerFirst');
          _matchingTimer?.cancel();

          if (mounted) {
            _navigateToGameScreen(); // マッチが成立したらゲーム画面に遷移
          }
        }
      },
      onError: (error) {
        _debugLog('Error in match updates listener: $error');
        _handleMatchingError(error.toString());
      },
    );
  }

  // ゲーム画面に遷移する
  void _navigateToGameScreen() {
    if (mounted && _matchDocumentRef != null && isMatched) {
      Navigator.pushReplacementNamed(
        context,
        '/online-game',
        arguments: {
          'gameId': _matchDocumentRef!.id,
          'isAiMode': false,
          'opponentName': opponentName,
          'playerMark': _playerMark,
          'isPlayerFirst': _isPlayerFirst,
        },
      );
    }
  }

  // タイムアウトや利用可能なマッチがない場合、AI対戦に切り替え
  void _switchToAIMatch() {
    _debugLog('Switching to AI match due to timeout or no available match');
    _matchDocumentRef?.update({
      'status': 'cancelled',
      'lastActivity': FieldValue.serverTimestamp(),
    }).catchError((e) => _debugLog('Cleanup error: $e'));

    _matchingTimer?.cancel();
    _matchSubscription?.cancel();

    setState(() {
      isMatched = true;
      opponentName = '相手'; // AIの場合も「相手」に統一
      _playerMark = 'X';   // AIモードでは必ずプレイヤーが先行
      _isPlayerFirst = true;
    });

    _debugLog('Match status updated to isMatched: $isMatched with opponent: $opponentName');

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/online-game',
          arguments: {
            'gameId': 'ai-${DateTime.now().millisecondsSinceEpoch}',
            'isAiMode': true,
            'opponentName': '相手', // 「相手」に統一
            'playerMark': _playerMark,
            'isPlayerFirst': _isPlayerFirst,
          },
        );
      }
    });
  }

  // マッチデータのバックアップを Firestore に保存
  Future<void> _backupMatchData() async {
    try {
      final snapshot = await _matchDocumentRef!.get();
      if (snapshot.exists) {
        _debugLog('Backing up match data for match ID: ${_matchDocumentRef!.id}');
        await _firestore.collection('match_backups').add({
          'matchId': _matchDocumentRef!.id,
          'data': snapshot.data(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _debugLog('Backup failed: $e');
    }
  }

  // マッチングエラーを処理
  void _handleMatchingError(String error) {
    _debugLog('Handling matching error: $error');

    if (!isRandom) {
      setState(() => errorMessage = null);
      return;
    }

    if (!_hasShownError) {
      setState(() {
        errorMessage = error;
        _hasShownError = true;
      });
      _showErrorDialog(error); // エラーダイアログを表示
    }
  }

  // エラーダイアログを表示
  void _showErrorDialog(String message) {
    if (!mounted || !isRandom) return;

    _debugLog('Showing error dialog: $message');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              _debugLog('User acknowledged error dialog, popping screens');
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // 前の画面に戻る
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // マッチをキャンセル
  void _cancelMatch() {
    if (_matchDocumentRef != null) {
      _debugLog('Cancelling match with ID: ${_matchDocumentRef!.id}');
      _matchDocumentRef?.update({
        'status': 'cancelled',
        'lastActivity': FieldValue.serverTimestamp(),
      }).catchError((e) => _debugLog('Cleanup error: $e'));
    }
  }

  @override
  void dispose() {
    _debugLog('Disposing MatchingScreen, cancelling timers and subscriptions');
    // 全てのタイマーとストリーム購読をキャンセル
    _matchingTimer?.cancel();
    _backupTimer?.cancel();
    _animationTimer?.cancel();
    _matchSubscription?.cancel();

    if (!isMatched && _matchDocumentRef != null) {
      _cancelMatch(); // マッチングが成立していない場合はマッチをキャンセル
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マッチング中...'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _debugLog('User pressed back button');
            // 戻るボタンが押されたときの処理
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
            if (errorMessage != null && isRandom)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            if (errorMessage == null || !isRandom) ...[
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(seconds: 1),
                child: isRandom
                    ? const Text(
                  '対戦相手を探しています...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
              const CircularProgressIndicator(), // マッチング中のインジケーター
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
