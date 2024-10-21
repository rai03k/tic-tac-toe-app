import 'dart:async'; // StreamSubscriptionのために必要
import 'dart:math'; // ランダム決定に使用
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore
import 'package:connectivity_plus/connectivity_plus.dart'; // オフライン検知
import '../models/game_board.dart'; // ゲームロジックをインポート
import '../widgets/game_board_widget.dart'; // ゲームボード描画用のウィジェット
import '../admob/banner_ad_widget.dart'; // バナー広告ウィジェットをインポート
import '../services/online_game_service.dart'; // サービスクラスのインポート

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key});

  @override
  _OnlineGameScreenState createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final GameBoard _gameBoard = GameBoard();
  bool _isMyTurn = false;
  bool _isPlayerInitialized = false;
  late String _playerMark;
  bool _isAiMode = false;
  String opponentName = '相手'; // 初期値を「相手」に設定
  String myName = 'あなた'; // 初期値を「あなた」に設定

  // Firestore用のサービスインスタンスを追加
  late OnlineGameService _onlineGameService;
  StreamSubscription<DocumentSnapshot>? _gameSubscription;
  late String gameId; // 一意のゲームID

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    // _gameSubscriptionが初期化されている場合のみキャンセル
    _gameSubscription?.cancel();
    super.dispose();
  }



  Future<void> _initializeGame() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null || args['gameId'] == null || args['gameId'].isEmpty) {
      print("Error: gameId is empty or null");
      return;
    }

    gameId = args['gameId'];
    _isAiMode = args['isAiMode'] ?? false;
    opponentName = args['opponentName'] ?? '相手';

    // ネットワーク状態をチェックしてからプレイヤーを初期化
    await _checkNetworkStatus();
    if (!_isPlayerInitialized) {
      await _initializePlayer();
    }
  }

  Future<void> _checkNetworkStatus() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // ネットワーク接続がない場合、AIモードに切り替え
      _isAiMode = true;
      await _initializePlayer(); // オフラインでもプレイヤーを初期化
    } else {
      // オンラインの場合、Firestoreのゲームサービスを初期化
      _isAiMode = false;
      _onlineGameService = OnlineGameService(gameId);

      await _initializePlayer();

      // Firestoreのゲームデータを監視
      _gameSubscription = _onlineGameService.gameStream.listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;

          if (data == null) {
            print("Error: No data found in Firestore snapshot");
            return;
          }

          // データの取得後、UIスレッドでsetStateを呼び出す
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _gameBoard.board = List<String>.from(data['board']);
              _isMyTurn = data['turn'] == _playerMark;

              // 勝者がいる場合
              _gameBoard.winner = data['winner'] ?? '';
            });
          });
        }
      });
    }
  }

  Future<void> _initializePlayer() async {
    final gameDoc = await FirebaseFirestore.instance.collection('matches').doc(gameId).get();

    if (gameDoc.exists) {
      final data = gameDoc.data() as Map<String, dynamic>?;

      if (data == null) {
        print("Error: No data found in gameDoc");
        return;
      }

      _playerMark = data['playerX'] == null ? 'X' : 'O';
      _isMyTurn = _playerMark == data['turn'];
    } else {
      _playerMark = 'X';
      _isMyTurn = true;
      await _onlineGameService.createGame(List.filled(9, ' '), 'X');
    }

    // プレイヤーの初期化が完了したことをセット
    setState(() {
      _isPlayerInitialized = true;
    });

    if (_isAiMode && !_isMyTurn) {
      await _handleAITurn();
    }
  }


  Future<void> _handleTap(int index) async {
    if (!_isMyTurn || _gameBoard.board[index] != ' ' || _gameBoard.winner.isNotEmpty) return;

    // プレイヤーのターン処理
    bool playerMove = await _gameBoard.handleTap(index);

    if (playerMove) {
      setState(() {
        _isMyTurn = false; // プレイヤーのターンが終了
      });

      // オフラインモードでAIのターン処理を行う
      if (_isAiMode) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          int bestMove = _gameBoard.findBestMove();
          if (bestMove != -1) {
            bool aiMoveMade = await _gameBoard.handleTap(bestMove);
            if (aiMoveMade) {
              setState(() {
                _isMyTurn = true; // 再びプレイヤーのターン
              });
            }
          }
        });
      } else {
        // オンラインモードのときは、Firestoreに手を記録
        await _onlineGameService.makeMove(index, _playerMark);
      }
    }
  }

  Future<void> _handleAITurn() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // AIの最適な手を見つける
    int bestMove = _gameBoard.findBestMove();
    if (bestMove != -1) {
      // AIの手を更新し、ゲームボードをリフレッシュ
      bool moveMade = await _gameBoard.handleTap(bestMove);
      if (moveMade) {
        setState(() {
          _isMyTurn = true; // 次のターンをプレイヤーに切り替え
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height; // 画面の高さを取得
    final screenWidth = MediaQuery.of(context).size.width; // 画面の幅を取得

    // 横幅が1000px以上の場合、goldenRatioを10.6に設定
    final double goldenRatio = screenHeight >= 1000 ? 10.6 : 5.6;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark; // ダークモードかどうか判定

    // ヘッダー、ゲームボード、リセットボタンの高さを調整
    final headerHeight = screenHeight / (goldenRatio + 1);

    // 再対戦ボタンの位置を条件に応じて調整
    double resetButtonBottom = 80; // デフォルトは80
    if (screenHeight >= 1000 && screenWidth <= 810) {
      resetButtonBottom = 30;  // 画面が縦長の場合
    }
    if (screenHeight <= 750) {
      resetButtonBottom = 5;   // 画面が小さい場合
    }

    if (!_isPlayerInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(headerHeight, isDarkMode),
              _buildPlayerRow(isDarkMode),
              Expanded(
                child: Container(
                  child: GameBoardWidget(
                    board: _gameBoard.board,  // ゲームボードをウィジェットに渡す
                    winningBlocks: _gameBoard.winningBlocks, // 勝利したブロックを渡す
                    fadedIndex: _gameBoard.fadedIndex, // フェードさせるマークのインデックスを渡す
                    winner: _gameBoard.winner,  // 勝者を渡す
                    onTap: _handleTap,  // タップ処理の関数を渡す
                  ),
                ),
              ),
              _buildRematchButton(),
            ],
          ),
          const Positioned(bottom: 0, left: 0, right: 0, child: BannerAdWidget()),
          Positioned(
            top: 40,
            left: 10,
            child: _buildBackButton(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double height, bool isDarkMode) {
    return Container(
      height: height,
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        color: _gameBoard.winner.isEmpty
            ? (_playerMark == 'X' ? Colors.redAccent : Colors.blueAccent)
            : (_gameBoard.winner == _playerMark ? Colors.green : Colors.red),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(80),
          bottomRight: Radius.circular(80),
        ),
      ),
      child: Text(
        _gameBoard.winner.isEmpty
            ? (_isMyTurn ? 'あなたのターン' : '相手のターン')
            : (_gameBoard.winner == _playerMark ? '勝ちました！' : '負けました'),
        style: TextStyle(
          color: isDarkMode ? Colors.black : Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlayerRow(bool isDarkMode) {
    final bool isPlayerFirst = _playerMark == 'X';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (isPlayerFirst) _buildPlayerIcon(isDarkMode, myName, Colors.redAccent),
          if (!isPlayerFirst) _buildPlayerIcon(isDarkMode, opponentName, Colors.blueAccent),
          const SizedBox(width: 40),
          Text(
            'VS',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 40),
          if (isPlayerFirst) _buildPlayerIcon(isDarkMode, opponentName, Colors.blueAccent),
          if (!isPlayerFirst) _buildPlayerIcon(isDarkMode, myName, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildPlayerIcon(bool isDarkMode, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 40,
          child: Icon(Icons.person, color: Colors.white, size: 72),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildRematchButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 5), // 上下の余白を調整
      child: ElevatedButton(
        onPressed: _gameBoard.winner.isEmpty ? null : _resetBoard,
        style: ElevatedButton.styleFrom(
          backgroundColor: _gameBoard.winner.isEmpty ? Colors.grey : Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          '再対戦',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildBackButton(bool isDarkMode) {
    return IconButton(
      icon: Icon(Icons.arrow_back, size: 30, color: isDarkMode ? Colors.black : Colors.white),
      onPressed: () => Navigator.pop(context),
    );
  }

  void _resetBoard() {
    setState(() {
      _gameBoard.resetBoard();
      _isMyTurn = _playerMark == 'X';
    });
  }
}
