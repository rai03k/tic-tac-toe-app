// 必要なパッケージをインポート
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  Timer? _animationTimer;

  // マッチングタイムアウトの秒数（ランダムマッチング用）
  static const int _timeoutSeconds = 30; // 30秒にタイムアウトを設定

  // Firestore インスタンス
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // マッチングに使用するドキュメントリファレンス
  DocumentReference? _matchDocumentRef;
  // マッチング相手のUUID
  String? _opponentId;
  // Firestore のストリーム購読を管理するための変数
  StreamSubscription? _matchSubscription;
  // プレイヤーID（UUID を生成）
  final String _playerId = const Uuid().v4();

  // デバッグ用ログ関数
  void _debugLog(String message) {
    print('🔍 [MatchingScreen] $message');
  }

  @override
  void initState() {
    super.initState();
    _startAnimationTimer(); // アニメーションのタイマー開始
    _checkConnectivity(); // インターネット接続の確認
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

  // インターネット接続を確認
  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _debugLog('No internet connection');
      if (!_hasShownError) {
        setState(() => errorMessage = 'ネットワーク接続がありません');
        _showErrorDialog('ネットワーク接続がありません');
        _hasShownError = true;
      }
      return false;
    }
    return true;
  }

  // ネットワーク状態の監視をセットアップ
  void _setupConnectivitySubscription() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      _debugLog('Network connectivity status: $connectivityResult');
      if (!mounted) return; // 重要: mountedチェックを追加

      if (connectivityResult == ConnectivityResult.none) {
        // ネットワーク接続がない場合のエラーハンドリング
        if (!_hasShownError) {
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
        _startCodeMatching(matchCode!); // コード指定マッチングを開始
      }
    } else {
      _debugLog('Invalid arguments passed to MatchingScreen');
      _handleMatchingError('無効な引数が渡されました'); // 引数が無効の場合のエラーハンドリング
    }
  }

  // 自分のIDで既存のエントリーを削除するメソッド
  Future<void> _cleanupOwnEntries() async {
    try {
      // 自分のIDで既存のエントリーを検索
      final snapshot = await _firestore.collection('matching').get();

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final playerId = data['playerId'] as String?;

          // 自分のIDのエントリーを見つけたら削除
          if (playerId == _playerId) {
            await doc.reference.delete();
            _debugLog('Removed existing entry for current player: ${doc.id}');
          }
        } catch (e) {
          _debugLog('Error checking document: $e');
        }
      }
    } catch (e) {
      _debugLog('Error cleaning up own entries: $e');
    }
  }

  // ランダムマッチングを開始
  Future<void> _startRandomMatching() async {
    try {
      if (!await _checkConnectivity()) return;

      _debugLog('Starting random matching...');

      // 古いマッチングデータをクリーンアップ
      await _cleanupOldMatchingData();

      // 自分のIDに関連する古いエントリーをクリーンアップ
      await _cleanupOwnEntries();

      // Firestoreに自分のUUIDを登録(コードなし=null)
      _matchDocumentRef = await _firestore.collection('matching').add({
        'playerId': _playerId,
        'code': null, // コードなし(ランダムマッチング)
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting'
      });

      _debugLog(
          'Registered for random matching with ID: ${_matchDocumentRef!.id}');

      // マッチング状態を監視する
      _listenForMatches();

      // 30秒のタイムアウトタイマーを設定
      _matchingTimer = Timer(Duration(seconds: _timeoutSeconds), () {
        if (!isMatched) {
          _debugLog('Random matching timed out after $_timeoutSeconds seconds');
          _timeoutMatchingProcess();
        }
      });
    } catch (e) {
      _debugLog('Error in random matching: $e');
      _handleMatchingError(e.toString());
    }
  }

  Future<void> _cleanupOldMatchingData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      // シンプルにすべてのマッチングデータを取得
      final snapshot = await firestore.collection('matching').get();

      // 1日以上前のデータを削除
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;

        // タイムスタンプが存在し、1日以上前の場合は削除
        if (createdAt != null && createdAt.toDate().isBefore(oneDayAgo)) {
          await doc.reference.delete();
          count++;
        }
      }

      print('Cleaned up $count old matching entries');
    } catch (e) {
      print('Error cleaning up old matching data: $e');
    }
  }

  // コード指定マッチングを開始
  Future<void> _startCodeMatching(String code) async {
    try {
      if (!await _checkConnectivity()) return;

      _debugLog('Starting code matching with code: $code');

      // 自分のIDに関連する古いエントリーをクリーンアップ
      await _cleanupOwnEntries();

      // Firestoreに自分のUUIDとコードを登録
      _matchDocumentRef = await _firestore.collection('matching').add({
        'playerId': _playerId,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting'
      });

      _debugLog(
          'Registered for code matching with ID: ${_matchDocumentRef!.id}');

      // マッチング状態を監視する
      _listenForMatches();
    } catch (e) {
      _debugLog('Error in code matching: $e');
      _handleMatchingError(e.toString());
    }
  }

// _listenForMatches メソッドの修正（matching_screen.dart）
  void _listenForMatches() {
    _debugLog('Setting up match listener...');

    _matchSubscription =
        _firestore.collection('matching').snapshots().listen((snapshot) {
      if (!mounted) return; // mountedチェックを追加
      if (isMatched) return; // すでにマッチングしていたら処理しない

      // 有効なマッチを探す
      QueryDocumentSnapshot? matchDoc = null;

      for (var doc in snapshot.docs) {
        try {
          // 自分が作成したドキュメントは明示的にスキップ
          if (doc.id == _matchDocumentRef?.id) {
            _debugLog('Skipping own document: ${doc.id}');
            continue;
          }

          final data = doc.data() as Map<String, dynamic>;
          final otherPlayerId = data['playerId'] as String?;

          // 自分のIDを持つ他のドキュメントもスキップ (重要)
          if (otherPlayerId == null || otherPlayerId == _playerId) {
            _debugLog('Skipping invalid playerID: $otherPlayerId');
            continue;
          }

          final status = data['status'] as String?;
          if (status != 'waiting') {
            continue;
          }

          // ランダムマッチングの場合
          if (isRandom) {
            final code = data['code'];
            if (code != null) {
              continue; // codeがnullでない場合はスキップ
            }
            matchDoc = doc;
            break;
          }
          // コード指定マッチングの場合
          else if (!isRandom && matchCode != null) {
            final code = data['code'];
            if (code != matchCode) {
              continue; // コードが一致しない場合はスキップ
            }
            matchDoc = doc;
            break;
          }
        } catch (e) {
          _debugLog('Error processing doc: $e');
        }
      }

      // マッチが見つかった場合
      if (matchDoc != null) {
        try {
          final data = matchDoc.data() as Map<String, dynamic>;
          final otherPlayerId = data['playerId'] as String?;

          if (otherPlayerId != null && otherPlayerId != _playerId) {
            _opponentId = otherPlayerId;
            _debugLog('Match found! Opponent ID: $_opponentId');

            // マッチング相手のドキュメントを更新して他の人とマッチングしないようにする
            matchDoc.reference.update(
                {'status': 'matched', 'matchedWith': _playerId}).then((_) {
              if (!mounted) return; // mountedチェックを追加
              // 自分のドキュメントも更新
              _matchDocumentRef?.update(
                  {'status': 'matched', 'matchedWith': _opponentId}).then((_) {
                if (!mounted) return; // mountedチェックを追加
                // マッチング成立
                _matchFound();
              });
            }).catchError((e) {
              _debugLog('Error updating match status: $e');
            });
          }
        } catch (e) {
          _debugLog('Error processing match: $e');
        }
      }
    }, onError: (error) {
      _debugLog('Error in match listener: $error');
      if (mounted) {
        // mountedチェックを追加
        _handleMatchingError(error.toString());
      }
    });
  }

  // マッチングが有効かどうかを確認するヘルパー関数
  bool _isValidMatch() {
    return isMatched && _opponentId != null && _opponentId != _playerId;
  }

  // _matchFound メソッドの修正
  void _matchFound() {
    if (!mounted) return; // mountedチェックを追加
    if (isMatched) return; // 既にマッチング済みの場合は処理しない
    if (_opponentId == null) return; // 相手がいない場合は処理しない
    if (_opponentId == _playerId) return; // 自分自身とのマッチングを防止

    _debugLog('Valid match found with opponent ID: $_opponentId');

    setState(() {
      isMatched = true;
    });

    _matchingTimer?.cancel(); // タイムアウトタイマーをキャンセル

    // ゲーム画面への遷移
    _navigateToGameScreen();
  }

  // タイムアウト時の処理（ランダムマッチングのみ）
  void _timeoutMatchingProcess() {
    if (isMatched) return; // 既にマッチング済みの場合は処理しない

    _debugLog('Timeout occurred, returning to menu');
    _forceRemoveMatchEntry();

    _matchSubscription?.cancel();

    // Firestoreからエントリーを削除
    _matchDocumentRef
        ?.delete()
        .catchError((e) => _debugLog('Error removing entry: $e'));

    _matchSubscription?.cancel();

    // タイムアウトのアラートを表示してからメニューに戻る
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('マッチングタイムアウト'),
          content: const Text('対戦相手が見つかりませんでした。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
                Navigator.of(context).pop(); // マッチング画面を閉じてメニューに戻る
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Firestoreからマッチングエントリーを削除
  void _removeMatchEntries() {
    // 自分のエントリーを削除
    if (_matchDocumentRef != null) {
      _matchDocumentRef!.delete().then((_) {
        _debugLog('Successfully removed own match entry');
      }).catchError((e) {
        _debugLog('Error removing own entry: $e');
      });
    }

    // マッチング相手のエントリーを検索して削除
    if (_opponentId != null) {
      _firestore.collection('matching').get().then((snapshot) {
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final playerId = data['playerId'] as String?;

            if (playerId == _opponentId) {
              doc.reference.delete().then((_) {
                _debugLog(
                    'Successfully removed opponent match entry: ${doc.id}');
              });
            }
          } catch (e) {
            _debugLog('Error checking opponent document: $e');
          }
        }
      }).catchError((e) => _debugLog('Error finding opponent entries: $e'));
    }
  }

  // ゲーム画面に遷移する
  void _navigateToGameScreen() {
    if (mounted) {
      if (_opponentId == null) {
        // 相手が見つからない場合は遷移しない（AIモードも無し）
        return;
      } else {
        // 通常の対戦（相手が見つかった場合のみ遷移）
        Navigator.pushReplacementNamed(
          context,
          '/online-game',
          arguments: {
            'playerId': _playerId,
            'opponentId': _opponentId,
            'isRandom': isRandom,
          },
        );
      }
    }
  }

  // マッチングエラーを処理
  void _handleMatchingError(String error) {
    _debugLog('Handling matching error: $error');

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
    if (!mounted) return;

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

  @override
  void dispose() {
    _debugLog('Disposing MatchingScreen, cancelling timers and subscriptions');
    // 全てのタイマーとストリーム購読をキャンセル
    _matchingTimer?.cancel();
    _animationTimer?.cancel();
    _matchSubscription?.cancel();

    // マッチング削除を確実に実行（修正）
    _forceRemoveMatchEntry();

    super.dispose();
  }

  // マッチングエントリーを強制的に削除する処理（追加）
  void _forceRemoveMatchEntry() {
    if (_matchDocumentRef != null) {
      _matchDocumentRef!
          .delete()
          .then((_) => _debugLog('Successfully removed matching entry'))
          .catchError((e) => _debugLog('Error removing entry: $e'));
    }
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
            _matchSubscription?.cancel();

            // Firestoreからエントリーを削除
            if (!isMatched && _matchDocumentRef != null) {
              _matchDocumentRef
                  ?.delete()
                  .catchError((e) => _debugLog('Error removing entry: $e'));
            }

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
                    ? const Text(
                        '対戦相手を探しています...',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
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
              if (isRandom && !isMatched)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    '${_timeoutSeconds}秒後にタイムアウトします',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
