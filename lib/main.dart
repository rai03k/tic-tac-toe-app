import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

// アプリ全体の構成を定義するクラス
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Tic Tac Toe',
      home: TicTacToe(),
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
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  List<String> _board = List.generate(9, (index) => ' '); // ボードの初期化
  bool _isX = true;
  String _winner = '';
  List<int> _winningBlocks = [];
  List<int> _xMoves = []; // Xの移動履歴を追跡
  List<int> _oMoves = []; // Oの移動履歴を追跡
  int? _fadedIndex; // 薄い色に変更されるマークのインデックス

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-1187210314934709/7887834192', // ここに実際のAdMobの広告ユニットIDを入れる
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    )..load();
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
    if (_board[index] != ' ' || _winner != '') return;

    if (_isX && _xMoves.length == 3 && index == _xMoves[0]) return;
    if (!_isX && _oMoves.length == 3 && index == _oMoves[0]) return;

    setState(() {
      if (_isX) {
        _board[index] = 'X';
        _xMoves.add(index);
        if (_xMoves.length > 3) {
          int oldIndex = _xMoves.removeAt(0);
          _board[oldIndex] = ' ';
        }
      } else {
        _board[index] = 'O';
        _oMoves.add(index);
        if (_oMoves.length > 3) {
          int oldIndex = _oMoves.removeAt(0);
          _board[oldIndex] = ' ';
        }
      }

      _winner = _checkWinner();
      _isX = !_isX;

      _handleMove();
    });
  }

  void _handleMove() {
    if (_isX && _xMoves.length == 3) {
      _fadedIndex = _xMoves[0];
    } else if (!_isX && _oMoves.length == 3) {
      _fadedIndex = _oMoves[0];
    } else {
      _fadedIndex = null;
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
      topColor = Colors.redAccent;
      topText = 'Player 1 Wins!';
    } else if (_winner == 'O') {
      topColor = Colors.blueAccent;
      topText = 'Player 2 Wins!';
    } else {
      topColor = _isX ? Colors.redAccent : Colors.blueAccent;
      topText = _isX ? 'Player 1' : 'Player 2';
    }

    return Scaffold(
      body: Column(
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
                children: <Widget>[
                  const SizedBox(height: 0),
                  _buildBoard(),
                  const SizedBox(height: 20),
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
          if (_isAdLoaded)
            Container(
              alignment: Alignment.bottomCenter,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return GridView.builder(
      shrinkWrap: true,
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
            padding: const EdgeInsets.only(bottom: 10),
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                _board[index].trim(),
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
