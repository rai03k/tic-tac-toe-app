import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart'; // UUID生成用パッケージ

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  _MatchingScreenState createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with SingleTickerProviderStateMixin {
  bool isMatched = false;
  late Timer _timer;
  bool isRandom = true;
  String? matchCode;
  bool _visible = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DocumentReference _matchDocumentRef;
  final List<String> aiPlayerNames = ['Player A', 'Player B', 'Player C', 'Player D'];
  String opponentName = '';
  final String _playerId = const Uuid().v4(); // プレイヤーIDを一意に生成

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _visible = !_visible;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    isRandom = args['isRandom'];
    matchCode = args['code'];

    if (isRandom) {
      _startRandomMatching();
      _startAIFallback();
    } else if (matchCode != null) {
      _joinMatchWithCode(matchCode!);
    }
  }

  Future<void> _startRandomMatching() async {
    final availableMatchQuery = await _firestore
        .collection('matches')
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (availableMatchQuery.docs.isNotEmpty) {
      _matchDocumentRef = availableMatchQuery.docs.first.reference;
      _joinMatch(_matchDocumentRef);
      _cancelAIFallback();
    } else {
      _matchDocumentRef = await _createNewMatch();
    }

    _listenForMatchUpdates();
  }

  Future<DocumentReference> _createNewMatch() async {
    final matchId = const Uuid().v4();
    final newMatchRef = await _firestore.collection('matches').add({
      'player1': _playerId,
      'player2': null,
      'status': 'waiting',
      'code': matchId,
      'board': List.filled(9, ' '),
      'turn': 'X',
      'winner': '',
    });
    return newMatchRef;
  }

  void _joinMatch(DocumentReference matchRef) async {
    await matchRef.update({
      'player2': _playerId,
      'status': 'matched',
    });
    setState(() {
      isMatched = true;
    });
  }

  Future<void> _joinMatchWithCode(String code) async {
    final matchQuery = await _firestore
        .collection('matches')
        .where('code', isEqualTo: code)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (matchQuery.docs.isNotEmpty) {
      _matchDocumentRef = matchQuery.docs.first.reference;
      _joinMatch(_matchDocumentRef);
      _listenForMatchUpdates();
    } else {
      print('指定されたコードのマッチが見つかりません');
    }
  }

  void _listenForMatchUpdates() {
    _matchDocumentRef.snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final opponent = data['player2'] as String?;

        // ステータスが'matched'で、かつ対戦相手が存在するかを確認
        if (status == 'matched' && !isMatched && opponent != null) {
          setState(() {
            isMatched = true;
            opponentName = 'Opponent'; // 必要に応じて実際のデータを取得
          });

          // マッチが成立した場合にのみAIタイマーをキャンセル
          _cancelAIFallback();

          // 遷移時にデータを渡す
          Navigator.pushReplacementNamed(context, '/online-game', arguments: {
            'gameId': _matchDocumentRef.id,
            'isAiMode': false,
            'opponentName': opponentName,
          });
        }
      } else {
        print("No data found in snapshot or snapshot does not exist");
      }
    }, onError: (error) {
      // Firestoreストリームのエラー処理
      print('Firestore stream error: $error');
      // ネットワークエラーの場合、一定の遅延を置いて再接続を試みる
      Future.delayed(const Duration(seconds: 5), () {
        if (!isMatched) {
          _listenForMatchUpdates(); // 再接続を試みる
        }
      });
    });
  }



  void _startAIFallback() {
    _timer = Timer(const Duration(seconds: 5), () {
      if (!isMatched) {
        final randomIndex = Random().nextInt(aiPlayerNames.length);
        opponentName = aiPlayerNames[randomIndex];
        Navigator.pushReplacementNamed(context, '/online-game', arguments: {
          'isAiMode': true,
          'opponentName': opponentName,
        });
      }
    });
  }

  void _cancelAIFallback() {
    if (_timer.isActive) {
      _timer.cancel();
    }
  }

  @override
  void dispose() {
    _cancelAIFallback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マッチング中...')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(seconds: 1),
              child: const Text(
                '対戦相手を探しています...',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
        ),
      ),
    );
  }
}
