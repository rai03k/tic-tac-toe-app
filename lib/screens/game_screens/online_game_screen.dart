// lib/screens/online_game_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/game_board.dart';
import '../../widgets/game_board_widget.dart';
import '../../admob/banner_ad_widget.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key});

  @override
  _OnlineGameScreenState createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  // 基本的なゲーム状態
  final GameBoard _gameBoard = GameBoard();
  bool _isMyTurn = false;
  bool _isPlayerInitialized = false;
  String _playerMark = '';
  bool _isAiMode = false;
  String opponentName = '相手';
  String myName = 'あなた';
  String? _initError;

  // プレイヤー情報
  String _playerId = '';
  String? _opponentId;
  bool _isFirstPlayer = false; // 先攻プレイヤーかどうか

  // Firestore関連
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DocumentReference _gameRef;
  StreamSubscription<DocumentSnapshot>? _gameSubscription;
  late String gameId;

  // 接続管理
  Timer? _connectionTimer;
  StreamSubscription? _connectivitySubscription;
  bool _initialized = false;
  String? _errorMessage;
  bool _isWaitingForOpponent = false; // 相手の手を待っているかどうか

  @override
  void initState() {
    super.initState();
    _startConnectionMonitoring();
    _monitorConnectivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initializeGame();
    }
  }

  void _monitorConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.none) {
        await _handleDisconnection();
      } else {
        await _checkConnection();
      }
    });
  }

  Future<void> _checkConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) {
        await _handleDisconnection();
      }
    } catch (e) {
      print('Connection check error: $e');
      _handleError('接続確認中にエラーが発生しました');
    }
  }

  void _startConnectionMonitoring() {
    _connectionTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkConnection();
    });
  }

  Future<void> _initializeGame() async {
    try {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args == null) {
        throw Exception('ゲーム情報が不正です');
      }

      _playerId = args['playerId'] ?? '';
      _opponentId = args['opponentId'];

      // 1人プレイ（AIモード）の判定
      _isAiMode = _opponentId == null;

      if (_isAiMode) {
        _setupAIGame();
      } else {
        // オンラインゲームのセットアップ
        await _setupOnlineGame();
      }
    } catch (e) {
      _handleError('ゲームの初期化に失敗しました: $e');
    }
  }

  void _setupAIGame() {
    setState(() {
      // AIモードでは必ず先攻としてセットアップ
      _isFirstPlayer = true;
      _playerMark = 'X';
      _isMyTurn = true;
      _isPlayerInitialized = true;
      _gameBoard.board = List.filled(9, ' ');
      opponentName = 'AI相手';
    });
  }

  Future<void> _setupOnlineGame() async {
    try {
      // オンラインゲームのIDを生成
      gameId =
          '${_playerId}_${_opponentId}_${DateTime.now().millisecondsSinceEpoch}';
      _gameRef = _firestore.collection('games').doc(gameId);

      // 先攻・後攻の決定（UUIDの比較で決定）
      _isFirstPlayer = _playerId.compareTo(_opponentId!) < 0;
      _playerMark = _isFirstPlayer ? 'X' : 'O';
      _isMyTurn = _isFirstPlayer; // 先攻なら自分のターン、後攻なら相手のターン

      // ゲーム状態の初期化
      await _gameRef.set({
        'player1': _isFirstPlayer ? _playerId : _opponentId,
        'player2': _isFirstPlayer ? _opponentId : _playerId,
        'currentTurn': 'X', // 常にXから開始
        'board': List.filled(9, ' '),
        'winner': '',
        'winningLine': [],
        'lastMove': -1,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // ゲーム状態の監視を開始
      _setupGameSubscription();

      setState(() {
        _isPlayerInitialized = true;
        _isWaitingForOpponent = !_isMyTurn;
      });
    } catch (e) {
      _handleError('オンラインゲームのセットアップに失敗しました: $e');
    }
  }

  void _setupGameSubscription() {
    _gameSubscription = _gameRef.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) return;

        setState(() {
          _gameBoard.board = List<String>.from(data['board']);
          final currentTurn = data['currentTurn'] as String;
          _isMyTurn = (currentTurn == _playerMark);
          _isWaitingForOpponent = !_isMyTurn && data['winner'].isEmpty;

          // 勝敗情報の更新
          _gameBoard.winner = data['winner'] ?? '';
          if (data['winningLine'] != null) {
            _gameBoard.winningBlocks = List<int>.from(data['winningLine']);
          }
        });
      },
      onError: (error) {
        print('Game subscription error: $error');
        _handleError('ゲーム状態の監視中にエラーが発生しました');
      },
    );
  }

  Future<void> _handleDisconnection() async {
    setState(() {
      _errorMessage = 'ネットワーク接続が切断されました';
    });

    // AIモードに切り替え
    if (!_isAiMode) {
      _switchToAIMode();
    }
  }

  void _switchToAIMode() {
    setState(() {
      _isAiMode = true;
      opponentName = 'AI相手';
    });

    // 通知を表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('接続が切断されたため、AIとの対戦に切り替えました'),
        duration: Duration(seconds: 3),
      ),
    );

    // 相手のターンだった場合、AIの手を実行
    if (!_isMyTurn) {
      _executeAIMove();
    }
  }

  void _executeAIMove() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _gameBoard.winner.isEmpty) {
        int bestMove = _gameBoard.findBestMove();
        if (bestMove != -1) {
          setState(() {
            _gameBoard.board[bestMove] = _playerMark == 'X' ? 'O' : 'X';
            _isMyTurn = true;
            _isWaitingForOpponent = false;
          });
          _checkWinner();
        }
      }
    });
  }

  // プレイヤーがマスをタップした時の処理
  Future<void> _handleTap(int index) async {
    // タップできない条件をチェック
    if (!_isMyTurn ||
        _gameBoard.board[index] != ' ' ||
        _gameBoard.winner.isNotEmpty) {
      return;
    }

    try {
      // マスを更新
      setState(() {
        _gameBoard.board[index] = _playerMark;
        _isMyTurn = false;
        if (!_isAiMode) {
          _isWaitingForOpponent = true;
        }
      });

      // 勝敗確認
      _checkWinner();

      if (_isAiMode) {
        // AIモードの場合
        _executeAIMove();
      } else {
        // オンラインモードの場合
        try {
          await _updateGameState(index);
        } catch (e) {
          print('Failed to update game state: $e');
          _switchToAIMode();
          if (_gameBoard.winner.isEmpty) {
            _executeAIMove();
          }
        }
      }
    } catch (e) {
      print('Error in handleTap: $e');
      setState(() {
        _gameBoard.board[index] = ' ';
        _isMyTurn = true;
        _isWaitingForOpponent = false;
      });
      _handleError('手の実行に失敗しました');
    }
  }

  // ゲーム状態をFirestoreに更新
  Future<void> _updateGameState(int moveIndex) async {
    final opponentMark = _playerMark == 'X' ? 'O' : 'X';

    await _gameRef.update({
      'board': _gameBoard.board,
      'currentTurn': opponentMark,
      'lastMove': moveIndex,
      'winner': _gameBoard.winner,
      'winningLine': _gameBoard.winningBlocks,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // 勝敗確認
  void _checkWinner() {
    // 横のライン
    for (int i = 0; i < 9; i += 3) {
      if (_gameBoard.board[i] != ' ' &&
          _gameBoard.board[i] == _gameBoard.board[i + 1] &&
          _gameBoard.board[i] == _gameBoard.board[i + 2]) {
        setState(() {
          _gameBoard.winner = _gameBoard.board[i];
          _gameBoard.winningBlocks = [i, i + 1, i + 2];
          _isWaitingForOpponent = false;
        });
        return;
      }
    }

    // 縦のライン
    for (int i = 0; i < 3; i++) {
      if (_gameBoard.board[i] != ' ' &&
          _gameBoard.board[i] == _gameBoard.board[i + 3] &&
          _gameBoard.board[i] == _gameBoard.board[i + 6]) {
        setState(() {
          _gameBoard.winner = _gameBoard.board[i];
          _gameBoard.winningBlocks = [i, i + 3, i + 6];
          _isWaitingForOpponent = false;
        });
        return;
      }
    }

    // 斜めのライン（左上から右下）
    if (_gameBoard.board[0] != ' ' &&
        _gameBoard.board[0] == _gameBoard.board[4] &&
        _gameBoard.board[0] == _gameBoard.board[8]) {
      setState(() {
        _gameBoard.winner = _gameBoard.board[0];
        _gameBoard.winningBlocks = [0, 4, 8];
        _isWaitingForOpponent = false;
      });
      return;
    }

    // 斜めのライン（右上から左下）
    if (_gameBoard.board[2] != ' ' &&
        _gameBoard.board[2] == _gameBoard.board[4] &&
        _gameBoard.board[2] == _gameBoard.board[6]) {
      setState(() {
        _gameBoard.winner = _gameBoard.board[2];
        _gameBoard.winningBlocks = [2, 4, 6];
        _isWaitingForOpponent = false;
      });
      return;
    }

    // 引き分けチェック
    if (!_gameBoard.board.contains(' ')) {
      setState(() {
        _gameBoard.winner = ' ';
        _isWaitingForOpponent = false;
      });
    }
  }

  void _handleError(String message) {
    setState(() {
      _errorMessage = message;
      _initError = message;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  void _resetBoard() {
    setState(() {
      _gameBoard.resetBoard();
      _isMyTurn = _isFirstPlayer;
      _isWaitingForOpponent = !_isMyTurn;
    });

    if (!_isAiMode) {
      // オンラインモードの場合、Firestoreを更新
      _gameRef.update({
        'board': List.filled(9, ' '),
        'currentTurn': 'X',
        'winner': '',
        'winningLine': [],
        'lastMove': -1,
        'lastUpdated': FieldValue.serverTimestamp(),
      }).catchError((e) {
        print('Failed to reset game: $e');
        _switchToAIMode();
      });
    } else if (!_isMyTurn) {
      // AIモードで相手のターンの場合、AIの手を実行
      _executeAIMove();
    }
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _connectionTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 初期化エラーがある場合はエラー画面を表示
    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'エラーが発生しました',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(_initError!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isPlayerInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final double goldenRatio = screenHeight >= 1000 ? 10.6 : 5.6;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final headerHeight = screenHeight / (goldenRatio + 1);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(headerHeight, isDarkMode),
              _buildPlayerRow(isDarkMode),
              Expanded(
                child: Stack(
                  children: [
                    GameBoardWidget(
                      board: _gameBoard.board,
                      winningBlocks: _gameBoard.winningBlocks,
                      fadedIndex: _gameBoard.fadedIndex,
                      winner: _gameBoard.winner,
                      onTap: _handleTap,
                    ),
                    // 相手の手を待っている間のローディング表示
                    if (_isWaitingForOpponent)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '相手の手を待っています...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildRematchButton(),
            ],
          ),
          const Positioned(
              bottom: 0, left: 0, right: 0, child: BannerAdWidget()),
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
            : (_gameBoard.winner == _playerMark
                ? Colors.green
                : _gameBoard.winner == ' '
                    ? Colors.orange
                    : Colors.red),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(80),
          bottomRight: Radius.circular(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          _gameBoard.winner.isEmpty
              ? (_isMyTurn ? 'あなたのターン' : '相手のターン')
              : (_gameBoard.winner == ' '
                  ? '引き分けです'
                  : _gameBoard.winner == _playerMark
                      ? 'あなたの勝ちです！'
                      : 'あなたの負けです'),
          style: TextStyle(
            color: isDarkMode ? Colors.black : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (_isFirstPlayer)
            _buildPlayerIcon(isDarkMode, myName, Colors.redAccent),
          if (!_isFirstPlayer)
            _buildPlayerIcon(isDarkMode, opponentName, Colors.redAccent),
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
          if (_isFirstPlayer)
            _buildPlayerIcon(isDarkMode, opponentName, Colors.blueAccent),
          if (!_isFirstPlayer)
            _buildPlayerIcon(isDarkMode, myName, Colors.blueAccent),
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
          child: const Icon(Icons.person, color: Colors.white, size: 72),
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
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: ElevatedButton(
        onPressed: _gameBoard.winner.isEmpty ? null : _resetBoard,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _gameBoard.winner.isEmpty ? Colors.grey : Colors.green,
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
      icon: Icon(Icons.arrow_back,
          size: 30, color: isDarkMode ? Colors.black : Colors.white),
      onPressed: () => Navigator.pop(context),
    );
  }
}
