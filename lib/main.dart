import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'menu_screen.dart';  // menu_screen.dartをインポート
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';  // kReleaseMode用

void main() => runApp(
  DevicePreview(
    enabled: !kReleaseMode, // リリースモードでは無効化する
    builder: (context) => MyApp(), // アプリの起動
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,  // これがDevicePreviewに必要
      locale: DevicePreview.locale(context), // DevicePreviewのロケールを適用
      builder: DevicePreview.appBuilder, // DevicePreviewのビルダーを適用
      title: 'Tic Tac Toe',
      home: MenuScreen(),  // 最初にメニュー画面を表示
    );
  }
}


// Tic Tac ToeのゲームロジックとUIを管理するクラス
class TicTacToe extends StatefulWidget {
  const TicTacToe({super.key});

  @override
  _TicTacToeState createState() => _TicTacToeState();
}

class _TicTacToeState extends State<TicTacToe> {
  List<String> _board = List.generate(9, (index) => ' '); // ボードの初期化
  bool _isX = true;
  String _winner = '';
  List<int> _winningBlocks = [];
  List<int> _xMoves = []; // Xの移動履歴を追跡
  List<int> _oMoves = []; // Oの移動履歴を追跡
  int? _fadedIndex; // 薄い色に変更されるマークのインデックス

  late AudioCache _audioCache;
  late AudioPlayer _audioPlayer;
  double _playbackRate = 1.0;

  @override
  void initState() {
    super.initState();
    _audioCache = AudioCache(prefix: 'assets/audio/');
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudioTap() async {
    try {
      await _audioPlayer.play(AssetSource('audio/tap.mp3'));
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void _playAudioWin() async {
    try {
      await _audioPlayer.play(AssetSource('audio/complete.mp3'));
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void _resetBoard() {
    setState(() {
      _board = List.generate(9, (index) => ' '); // ボードをリセット時に再初期化
      _isX = true;
      _winner = '';
      _winningBlocks = [];
      _xMoves = [];
      _oMoves = [];
      _fadedIndex = null;
    });
  }

  void _handleTap(int index) {
    _playAudioTap();
    // 既にマークがある場所、または勝者が決まった後の場所には置けないようにする
    if (_board[index] != ' ' || _winner != '') return;

    // 現在の3つのマークの中で最も古いマークが消える場所には置けないようにする
    if (_isX && _xMoves.length == 3 && index == _xMoves[0]) return;
    if (!_isX && _oMoves.length == 3 && index == _oMoves[0]) return;

    // UIを更新
    setState(() {
      if (_isX) {
        _board[index] = 'X';
        _xMoves.add(index);
        if (_xMoves.length > 3) {
          int oldIndex = _xMoves.removeAt(0);
          _board[oldIndex] = ' '; // 消されたマークの場所を空に戻す
        }
      } else {
        _board[index] = 'O';
        _oMoves.add(index);
        if (_oMoves.length > 3) {
          int oldIndex = _oMoves.removeAt(0);
          _board[oldIndex] = ' '; // 消されたマークの場所を空に戻す
        }
      }

      _winner = _checkWinner();
      _isX = !_isX;

      // 4つ目のマークが置かれる前に、最初のマークを薄く表示する
      _handleMove();
    });
  }

  void _handleMove() {
    // 3つ前のマークを薄い色にするロジック
    if (_isX && _xMoves.length == 3) {
      _fadedIndex = _xMoves[0];
    } else if (!_isX && _oMoves.length == 3) {
      _fadedIndex = _oMoves[0];
    } else {
      _fadedIndex = null; // 3つ未満の場合は薄く表示するマークがない
    }
  }

  String _checkWinner() {
    const List<List<int>> winPatterns = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (var pattern in winPatterns) {
      String first = _board[pattern[0]];
      if (first != ' ' &&
          first == _board[pattern[1]] &&
          first == _board[pattern[2]]) {
        setState(() {
          _winningBlocks = pattern;
        });
        return first;
      }
    }

    return _board.contains(' ') ? '' : 'Draw';
  }

  @override
  Widget build(BuildContext context) {
    Color topColor;
    String topText;

    if (_winner == 'X') {
      _playAudioWin();
      topColor = Colors.redAccent;
      topText = 'Player 1 Wins!';
    } else if (_winner == 'O') {
      _playAudioWin();
      topColor = Colors.blueAccent;
      topText = 'Player 2 Wins!';
    } else {
      topColor = _isX ? Colors.redAccent : Colors.blueAccent;
      topText = _isX ? 'Player 1' : 'Player 2';
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: topColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                ),
                alignment: Alignment.bottomCenter,
                height: 100,
                child: Text(
                  topText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          radius: 40,
                          child: Icon(Icons.person, color: Colors.white, size: 72),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Player 1',
                          style: TextStyle(color: Colors.black, fontSize: 20),
                        ),
                      ],
                    ),
                    SizedBox(width: 40),
                    Text(
                      'VS',
                      style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 40),
                    Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 40,
                          child: Icon(Icons.person, color: Colors.white, size: 72),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Player 2',
                          style: TextStyle(color: Colors.black, fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.grey[300],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _buildBoard(),
                      const SizedBox(height: 50),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _resetBoard,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, color: Colors.white),
                            SizedBox(width: 10),
                            Text('RESET', style: TextStyle(color: Colors.white, fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 30,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 55),
              onPressed: () {
                Navigator.pop(context);  // メニューに戻る
              },
            ),
          ),
          Positioned(
            top: 30,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.menu, size: 55), // 三（ハンバーガーメニュー）のアイコン
              onPressed: () {
                Navigator.pop(context);  // メニューに戻る
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBoard() {
    return Container(
      height: MediaQuery.of(context).size.width * 1.2, // 高さをデバイスの幅より少し広げる
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(), // スクロールを無効化
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          Color blockColor = Colors.white;
          Color textColor;

          if (_winningBlocks.contains(index)) {
            blockColor = _board[index] == 'X' ? Colors.redAccent : Colors.blueAccent;
            textColor = Colors.white;
          } else if (_fadedIndex != null && index == _fadedIndex) {
            // 3つ前のマークを薄い色で表示
            textColor = _board[index] == 'X'
                ? Colors.redAccent.withOpacity(0.3)
                : Colors.blueAccent.withOpacity(0.3);
          } else {
            textColor = _board[index] == 'X'
                ? Colors.redAccent
                : _board[index] == 'O'
                ? Colors.blueAccent
                : Colors.transparent;
          }

          return GestureDetector(
            onTap: () => _handleTap(index),
            child: Container(
              padding: const EdgeInsets.only(bottom: 10), // 下部にスペースを追加
              margin: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: Text(
                  _board[index].trim(), // 空白をトリミングして正しい表示を確認
                  style: TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: textColor, // 色を明示的に設定
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
