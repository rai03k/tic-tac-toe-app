// lib/screens/online_game_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/game_board.dart';
import '../widgets/game_board_widget.dart';
import '../admob/banner_ad_widget.dart';
import '../services/online_game_service.dart';

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
  late String _playerMark;
  bool _isAiMode = false;
  String opponentName = '相手';
  String myName = 'あなた';
  String? _initError; // 初期化エラーを保持する新しいフィールド
  bool _isOpponentAI = false; // 相手がAIに切り替わったかどうか

  // オンラインゲーム関連
  late OnlineGameService _onlineGameService;
  StreamSubscription<DocumentSnapshot>? _gameSubscription;
  late String gameId;

  // 接続管理
  Timer? _connectionTimer;
  Timer? _backupTimer;
  Timer? _inactivityTimer;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  String? _errorMessage;
  static const int _maxReconnectAttempts = 3;
  static const int _inactivityTimeout = 30;
  StreamSubscription? _connectivitySubscription;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // _initializeGame()を削除
    _startConnectionMonitoring();
    _startInactivityTimer();
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
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .map((event) => event as ConnectivityResult) // 型を明示的に変換
        .listen((result) async {
      if (result == ConnectivityResult.none) {
        await _handleDisconnection();
      } else if (_isReconnecting) {
        await _handleReconnection();
      }
    });
  }

// _checkConnection メソッドを追加
  Future<void> _checkConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) {
        await _handleDisconnection();
      } else if (_isReconnecting) {
        await _handleReconnection();
      }
    } catch (e) {
      print('Connection check error: $e');
      _handleError('接続確認中にエラーが発生しました');
    }
  }

// _startConnectionMonitoring メソッドを修正
  void _startConnectionMonitoring() {
    _connectionTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkConnection();
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer =
        Timer(Duration(seconds: _inactivityTimeout), _handleInactivity);
  }

  Future<void> _initializeGame() async {
    try {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args == null) {
        throw Exception('ゲーム情報が不正です');
      }

      _isAiMode = args['isAiMode'] ?? false;
      opponentName = args['opponentName'] ?? '相手';
      gameId = _isAiMode ? 'ai-game' : args['gameId']!;

      if (_isAiMode) {
        final random = Random();
        final isPlayerFirst = random.nextBool(); // ランダムにtrueまたはfalseを生成

        setState(() {
          _playerMark = isPlayerFirst ? 'X' : 'O'; // trueならX（先行）、falseならO（後攻）
          _isMyTurn = isPlayerFirst; // 先行なら自分のターン、後攻ならAIのターン
          _isPlayerInitialized = true;
          _gameBoard.board = List.filled(9, ' ');
        });
// 後攻の場合、AIの手を実行
        if (!isPlayerFirst) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleAITurn();
          });
        }
      } else {
        await _checkNetworkStatus();
        if (!_isPlayerInitialized) {
          await _initializePlayer();
        }
        _startBackupTimer();
      }
    } catch (e) {
      _handleError('ゲームの初期化に失敗しました: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      if (_isAiMode) {
        setState(() {
          _playerMark = 'X';
          _isMyTurn = true;
          _isPlayerInitialized = true;
          _gameBoard.board = List.filled(9, ' ');
        });
        return;
      }

      final gameDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(gameId)
          .get();

      if (!gameDoc.exists) {
        throw Exception('ゲームが見つかりません');
      }

      final data = gameDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('ゲームデータが不正です');
      }

      setState(() {
        _playerMark = data['playerX'] == null ? 'X' : 'O';
        _isMyTurn = _playerMark == data['turn'];
        _isPlayerInitialized = true;
        _gameBoard.board =
        List<String>.from(data['board'] ?? List.filled(9, ' '));
      });
    } catch (e) {
      _handleError('プレイヤーの初期化に失敗しました: $e');
    }
  }

  Future<void> _checkNetworkStatus() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (!_isAiMode) {
          await _handleDisconnection();
        }
      } else {
        if (!_isAiMode) {
          // AIモードでない場合のみオンラインサービスを初期化
          _onlineGameService = OnlineGameService(gameId);
          await _setupGameSubscription();
        }
      }
    } catch (e) {
      _handleError('ネットワーク確認に失敗しました: $e');
    }
  }

  Future<void> _setupGameSubscription() async {
    _gameSubscription?.cancel();
    _gameSubscription = _onlineGameService.gameStream.listen(
      _handleGameUpdate,
      onError: _handleConnectionError,
    );
  }

  void _handleGameUpdate(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return;

    // 相手の切断を検知
    if (data['connectionStatus'] != null) {
      final opponentMark = _playerMark == 'X' ? 'O' : 'X';
      if (data['connectionStatus'][opponentMark] == 'disconnected') {
        _handleOpponentDisconnection();
        return;
      }
    }

    setState(() {
      _gameBoard.board = List<String>.from(data['board']);
      _isMyTurn = data['turn'] == _playerMark;
      _gameBoard.winner = data['winner'] ?? '';

      if (data['winningLine'] != null) {
        _gameBoard.winningBlocks = List<int>.from(data['winningLine']);
      }
    });

    _startInactivityTimer();
  }

  void _handleConnectionError(dynamic error) {
    print('Connection error: $error');
    if (!_isReconnecting && !_isOpponentAI) {
      _switchToAIOpponent();
    }
  }

  Future<void> _handleDisconnection() async {
    if (_isAiMode) return;

    setState(() {
      _isReconnecting = true;
      _errorMessage = 'サーバーとの接続が切断されました';
    });

    if (mounted) {
      _showReconnectingDialog();
    }

    try {
      await _onlineGameService.updateConnectionStatus(false, _playerMark);
    } catch (e) {
      print('Error updating connection status: $e');
    }
  }

  Future<void> _handleReconnection() async {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _showConnectionFailedDialog();
      return;
    }

    _reconnectAttempts++;
    try {
      await _checkNetworkStatus();
      setState(() {
        _isReconnecting = false;
        _errorMessage = null;
      });
      Navigator.of(context).pop(); // リコネクト中ダイアログを閉じる
      _reconnectAttempts = 0;
    } catch (e) {
      print('Reconnection attempt failed: $e');
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        _showConnectionFailedDialog();
      }
    }
  }

  void _handleInactivity() {
    if (!mounted || _isAiMode) return;
    _onlineGameService.checkTimeout();
  }

  void _handleOpponentDisconnection() {
    if (!mounted) return;

    // AIモードに切り替え
    _switchToAIOpponent();

    // 相手のターンだった場合、AIの手を実行
    if (!_isMyTurn) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          int bestMove = _gameBoard.findBestMove();
          if (bestMove != -1) {
            setState(() {
              _gameBoard.board[bestMove] = _playerMark == 'X' ? 'O' : 'X';
              _isMyTurn = true;
            });
            _checkWinner();
          }
        }
      });
    }
  }

// AIに切り替えるメソッドを追加
  void _switchToAIOpponent() {
    if (mounted) {
      setState(() {
        _isOpponentAI = true;
        opponentName = 'AI対戦相手';
      });

      // 切り替え通知を表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('対戦相手との接続が切れたため、AIと対戦を続行します'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showReconnectingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('再接続中'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('接続の復旧を試みています...'),
          ],
        ),
      ),
    );
  }

  void _showConnectionFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('接続エラー'),
        content: const Text('接続の復旧に失敗しました。\nゲームを終了します。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // エラーハンドリングメソッドを修正
  void _handleError(String message) {
    setState(() {
      _errorMessage = message;
      _initError = message; // 初期化エラーを保存
    });

    // initState中でない場合のみSnackBarを表示
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      });
    }
  }

  // online_game_screen.dart の _handleTap メソッドを修正
  Future<void> _handleTap(int index) async {
    if (!_isMyTurn ||
        _gameBoard.board[index] != ' ' ||
        _gameBoard.winner.isNotEmpty) {
      return;
    }

    try {
      if (_isAiMode || _isOpponentAI) {
        // AIモードまたは相手がAIの場合
        setState(() {
          _gameBoard.board[index] = _playerMark;
          _isMyTurn = false;
        });
        _checkWinner();

        // AIの手を実行
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _gameBoard.winner.isEmpty) {
            int bestMove = _gameBoard.findBestMove();  // 修正：引数を削除
            if (bestMove != -1) {
              setState(() {
                _gameBoard.board[bestMove] = _playerMark == 'X' ? 'O' : 'X';
                _isMyTurn = true;
              });
              _checkWinner();
            }
          }
        });
      } else {
        // オンラインモードの場合
        setState(() {
          _gameBoard.board[index] = _playerMark;
          _isMyTurn = false;
        });
        try {
          await _onlineGameService.makeMove(index, _playerMark);
        } catch (e) {
          print('Online move failed, switching to AI mode: $e');
          _switchToAIOpponent();
          // エラー後のAIの手を実行
          if (mounted && _gameBoard.winner.isEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () {
              int bestMove = _gameBoard.findBestMove();  // 修正：引数を削除
              if (bestMove != -1) {
                setState(() {
                  _gameBoard.board[bestMove] = _playerMark == 'X' ? 'O' : 'X';
                  _isMyTurn = true;
                });
                _checkWinner();
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error in handleTap: $e');
      if (mounted) {
        setState(() {
          _gameBoard.board[index] = ' ';
          _isMyTurn = true;
        });
        _handleError('手の実行に失敗しました: $e');
      }
    }
  }

// 勝敗確認メソッドを追加
  void _checkWinner() {
    // 横のライン
    for (int i = 0; i < 9; i += 3) {
      if (_gameBoard.board[i] != ' ' &&
          _gameBoard.board[i] == _gameBoard.board[i + 1] &&
          _gameBoard.board[i] == _gameBoard.board[i + 2]) {
        setState(() {
          _gameBoard.winner = _gameBoard.board[i];
          _gameBoard.winningBlocks = [i, i + 1, i + 2];
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
      });
      return;
    }

    // 引き分けチェック
    if (!_gameBoard.board.contains(' ')) {
      setState(() {
        _gameBoard.winner = ' ';
      });
    }
  }

  Future<void> _handleAITurn() async {
    await Future.delayed(const Duration(milliseconds: 500));
    int bestMove = _gameBoard.findBestMove();
    if (bestMove != -1) {
      bool moveMade = await _gameBoard.handleTap(bestMove);
      if (moveMade) {
        setState(() {
          _isMyTurn = true;
        });
      }
    }
  }

  void _startBackupTimer() {
    if (_isAiMode) return;

    _backupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _onlineGameService.backupGameState();
    });
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _connectionTimer?.cancel();
    _backupTimer?.cancel();
    _inactivityTimer?.cancel();
    _connectivitySubscription?.cancel();

    // オンラインモードの場合、切断状態を更新
    if (!_isAiMode) {
      _onlineGameService.updateConnectionStatus(false, _playerMark).catchError((e) {
        print('Error updating connection status on dispose: $e');
      });
    }

    super.dispose();
  }

  // 以下のUIビルド関連のメソッドは変更なし
  @override
  Widget build(BuildContext context) {
    // 初期化エラーがある場合はエラー画面を表示
    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'エラーが発生しました',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(_initError!),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }

    // 既存のbuild処理...
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final double goldenRatio = screenHeight >= 1000 ? 10.6 : 5.6;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final headerHeight = screenHeight / (goldenRatio + 1);
    double resetButtonBottom = screenHeight >= 1000 && screenWidth <= 810
        ? 30
        : screenHeight <= 750
        ? 5
        : 80;

    if (!_isPlayerInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isReconnecting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_errorMessage ?? '再接続中...'),
            ],
          ),
        ),
      );
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
                    board: _gameBoard.board,
                    winningBlocks: _gameBoard.winningBlocks,
                    fadedIndex: _gameBoard.fadedIndex,
                    winner: _gameBoard.winner,
                    onTap: _handleTap,
                  ),
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
            : (_gameBoard.winner == _playerMark ? Colors.green : Colors.red),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(80),
          bottomRight: Radius.circular(80),
        ),
      ),
      child: Text(
        _gameBoard.winner.isEmpty
            ? (_isMyTurn ? 'あなたのターン' : '相手のターン')
            : (_gameBoard.winner == ' '
            ? '引き分けです'
            : _gameBoard.winner == _playerMark
            ? 'あなたの勝ちです！'
            : 'あなたの負けです'),  // 修正
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
          if (isPlayerFirst)
            _buildPlayerIcon(isDarkMode, myName, Colors.redAccent),
          if (!isPlayerFirst)
            _buildPlayerIcon(isDarkMode, opponentName, Colors.blueAccent),
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
          if (isPlayerFirst)
            _buildPlayerIcon(isDarkMode, opponentName, Colors.blueAccent),
          if (!isPlayerFirst)
            _buildPlayerIcon(isDarkMode, myName, Colors.redAccent),
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

  void _resetBoard() {
    setState(() {
      _gameBoard.resetBoard();
      _isMyTurn = _playerMark == 'X';
    });
  }
}
