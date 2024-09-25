import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';  // url_launcher をインポート
import 'package:google_mobile_ads/google_mobile_ads.dart';  // 動画広告をインポート

class AdRemovalScreen extends StatefulWidget {
  const AdRemovalScreen({super.key});

  @override
  _AdRemovalScreenState createState() => _AdRemovalScreenState();
}

class _AdRemovalScreenState extends State<AdRemovalScreen>
    with SingleTickerProviderStateMixin {
  int _progress = 1;  // スタート時点の進捗は1点目がすでに溜まっている状態
  bool _hasReviewed = false;  // レビューが完了したかどうか
  bool _videoWatched = false;  // 動画が再生されたかどうか
  bool _adsRemoved = false;  // 広告が削除されたかどうか
  late AnimationController _controller;  // 進捗バーのアニメーション制御
  late Animation<double> _animation;  // アニメーションの進捗割合
  RewardedAd? _rewardedAd;  // 動画広告
  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;
  bool _isTopBannerAdLoaded = false;
  bool _isBottomBannerAdLoaded = false;

  // 言語選択関連の変数
  String _selectedLanguage = 'en'; // 初期言語
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'label': 'English'},
    {'code': 'es', 'label': 'Español'},
    {'code': 'zh_CN', 'label': '简体中文'},
    {'code': 'zh_TW', 'label': '繁體中文'},
    {'code': 'ja', 'label': '日本語'},
    {'code': 'fr', 'label': 'Français'},
    {'code': 'de', 'label': 'Deutsch'},
    {'code': 'pt', 'label': 'Português'},
    {'code': 'ko', 'label': '한국어'}
  ];

  // 翻訳マップ
  final Map<String, Map<String, String>> _translations = {
    'en': {
      'progressDescription': 'Progress to Remove Ads',
      'reviewButton': 'Write a Review',
      'watchVideoButton': 'Watch Video to Remove Ads',
      'stepsCompleted': 'steps completed',
      'orText': 'or',
      'adsRemovedMessage': 'Ads have been removed!',
    },
    'ja': {
      'progressDescription': '広告を削除するための進捗',
      'reviewButton': 'レビューを書く',
      'watchVideoButton': '動画を見て広告を削除',
      'stepsCompleted': 'ステップが完了しました',
      'orText': 'または',
      'adsRemovedMessage': '広告が削除されました！',
    },
    'es': {
      'progressDescription': 'Progreso para eliminar anuncios',
      'reviewButton': 'Escribir una reseña',
      'watchVideoButton': 'Ver video para eliminar anuncios',
      'stepsCompleted': 'pasos completados',
      'orText': 'o',
      'adsRemovedMessage': '¡Los anuncios han sido eliminados!',
    },
    'zh_CN': {
      'progressDescription': '删除广告的进度',
      'reviewButton': '写评论',
      'watchVideoButton': '观看视频以删除广告',
      'stepsCompleted': '步已完成',
      'orText': '或',
      'adsRemovedMessage': '广告已删除！',
    },
    'zh_TW': {
      'progressDescription': '刪除廣告的進度',
      'reviewButton': '寫評論',
      'watchVideoButton': '觀看視頻以刪除廣告',
      'stepsCompleted': '步已完成',
      'orText': '或',
      'adsRemovedMessage': '廣告已刪除！',
    },
    'fr': {
      'progressDescription': 'Progrès pour supprimer les publicités',
      'reviewButton': 'Écrire une critique',
      'watchVideoButton': 'Regarder la vidéo pour supprimer les publicités',
      'stepsCompleted': 'étapes terminées',
      'orText': 'ou',
      'adsRemovedMessage': 'Les annonces ont été supprimées!',
    },
    'de': {
      'progressDescription': 'Fortschritt zum Entfernen von Anzeigen',
      'reviewButton': 'Eine Bewertung schreiben',
      'watchVideoButton': 'Video ansehen, um Anzeigen zu entfernen',
      'stepsCompleted': 'Schritte abgeschlossen',
      'orText': 'oder',
      'adsRemovedMessage': 'Die Anzeigen wurden entfernt!',
    },
    'pt': {
      'progressDescription': 'Progresso para remover anúncios',
      'reviewButton': 'Escrever uma avaliação',
      'watchVideoButton': 'Assista ao vídeo para remover anúncios',
      'stepsCompleted': 'etapas concluídas',
      'orText': 'ou',
      'adsRemovedMessage': 'Os anúncios foram removidos!',
    },
    'ko': {
      'progressDescription': '광고 제거 진행 상황',
      'reviewButton': '리뷰 작성',
      'watchVideoButton': '광고 제거를 위한 비디오 보기',
      'stepsCompleted': '단계 완료',
      'orText': '또는',
      'adsRemovedMessage': '광고가 제거되었습니다!',
    }
  };

  @override
  void initState() {
    super.initState();
    _loadProgress();  // SharedPreferencesから進捗状況を読み込む
    _loadLanguage();  // 言語設定を読み込む
    _controller = AnimationController(
      duration: const Duration(seconds: 1),  // 1秒間のアニメーション
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: _progress.toDouble() / 3).animate(_controller);  // アニメーションの設定
    _controller.forward();  // アニメーションを開始

    if (!_adsRemoved) {
      _loadRewardedAd();  // 動画広告を読み込む
      _loadBannerAds();  // バナー広告を読み込む
    }
  }

  // 言語設定をSharedPreferencesから読み込む
  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('selectedLanguage') ?? 'en';
    });
  }

  // 言語設定をSharedPreferencesに保存する
  Future<void> _saveLanguage(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLanguage', languageCode);
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  // 言語選択用のドロップダウンメニュー
  Widget _buildLanguageDropdown() {
    return DropdownButton<String>(
      value: _selectedLanguage,
      onChanged: (String? newLanguage) {
        if (newLanguage != null) {
          _saveLanguage(newLanguage);
        }
      },
      items: _languages.map<DropdownMenuItem<String>>((Map<String, String> language) {
        return DropdownMenuItem<String>(
          value: language['code'],
          child: Text(language['label']!),
        );
      }).toList(),
    );
  }

  // 選択された言語に基づいて翻訳を取得する関数
  String _getTranslation(String key) {
    return _translations[_selectedLanguage]?[key] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove Ads'),  // AppBarのタイトル
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildLanguageDropdown(),  // 言語選択ドロップダウンを右上に表示
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_adsRemoved && _isTopBannerAdLoaded)
            Container(
              width: _topBannerAd!.size.width.toDouble(),
              height: _topBannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _topBannerAd!),  // トップバナー広告ウィジェット
            ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,  // コンテンツを中央に配置
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),  // 横に余白を追加
                    child: Column(
                      children: [
                        Text(
                          _getTranslation('progressDescription'),  // 進捗状況の説明
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 20),
                        AnimatedBuilder(
                          animation: _animation,  // アニメーションを監視
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _progress == 3 ? 1 : _animation.value,  // 進捗バーの割合
                              minHeight: 20,  // 進捗バーの高さ
                              color: _progress == 3 ? Colors.orange : Colors.orangeAccent,  // 進捗バーの色
                              backgroundColor: Colors.grey[300],  // 背景色
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$_progress / 3 ${_getTranslation('stepsCompleted')}',  // 進捗状況を表示
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 進捗が1点目または2点目の場合、レビューか動画再生が可能
                  if ((_progress == 1 || _progress == 2) && !_hasReviewed)
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _writeReview,  // レビューを書く
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),  // 角を丸くする
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,  // ボタンのサイズに合わせる
                            children: [
                              const Icon(Icons.rate_review, size: 24),  // レビューアイコン
                              const SizedBox(width: 10),  // アイコンとテキストの間にスペースを追加
                              Text(
                                _getTranslation('reviewButton'),  // レビューボタンのテキスト
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),  // ボタンと「or」の間にスペースを追加

                        Text(  // or のテキスト
                          _getTranslation('orText'),
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),

                        const SizedBox(height: 20),  // 「or」と次のボタンの間にスペースを追加

                        ElevatedButton(
                          onPressed: _rewardedAd != null ? _showRewardedAd : null,  // 動画再生
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),  // 角を丸くする
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,  // ボタンのサイズに合わせる
                            children: [
                              const Icon(Icons.play_circle, size: 24),  // 動画再生アイコン
                              const SizedBox(width: 10),  // アイコンとテキストの間にスペースを追加
                              Text(
                                _getTranslation('watchVideoButton'),  // 動画再生ボタンのテキスト
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  // 進捗が2点目またはレビュー済みの場合は動画再生のみ
                  if (_progress == 2 || (_progress == 1 && _hasReviewed)) // 進捗が1でレビュー済みの場合のみ
                    ElevatedButton(
                      onPressed: _rewardedAd != null ? _showRewardedAd : null,  // 動画再生
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),  // 角を丸くする
                        ),
                      ),
                      child: Text(
                        _getTranslation('watchVideoButton'),  // ボタンのテキスト
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),

                  const SizedBox(height: 40),

                  if (_progress == 3)
                    Text(
                      _getTranslation('adsRemovedMessage'),  // 広告削除完了メッセージ
                      style: const TextStyle(fontSize: 18, color: Colors.orange),
                    ),
                ],
              ),
            ),
          ),
          if (!_adsRemoved && _isBottomBannerAdLoaded)
            Container(
              width: _bottomBannerAd!.size.width.toDouble(),
              height: _bottomBannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bottomBannerAd!),  // ボトムバナー広告ウィジェット
            ),
        ],
      ),
    );
  }

  // 動画広告の表示、進捗更新などの関数はここに追加

  // 動画広告の読み込み
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',  // 動画広告ユニットID
      request: const AdRequest(),  // 広告リクエスト
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;  // 読み込まれた動画広告を保存
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('動画広告の読み込みに失敗しました: $error');
        },
      ),
    );
  }

// 動画広告を表示して、進捗を更新する関数
  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        setState(() {
          if (_progress < 3) _progress++;  // 進捗を1点進める
          _videoWatched = true;  // 動画視聴完了
          _saveProgress();  // 進捗を保存
          _controller.reset();  // アニメーションをリセット
          _animation = Tween<double>(begin: 0, end: _progress.toDouble() / 3).animate(_controller);
          _controller.forward();  // アニメーションを再開
        });
        // 動画視聴後、古い広告を破棄し、新しい広告をロードする
        _rewardedAd!.dispose();  // 古い広告を破棄
        _loadRewardedAd();  // 新しい広告をロード
      });
    }
  }


// レビューを書いて進捗を更新する関数
  Future<void> _writeReview() async {
    const reviewUrl = 'https://example.com/review';  // レビューのリンク
    if (await canLaunch(reviewUrl)) {
      await launch(reviewUrl);  // リンクを起動
      setState(() {
        _hasReviewed = true;  // レビュー完了
        if (_progress < 3) _progress++;  // 進捗を1点進める
        _saveProgress();  // 進捗を保存
      });

      // レビュー完了後、画面をリロードしてボタン表示を更新
      await Future.delayed(Duration(seconds: 1));  // 少し待機してからリロード
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (BuildContext context) => const AdRemovalScreen()),
      );
    }
  }



  // SharedPreferencesに進捗状況を保存する
// SharedPreferences に進捗を保存する関数
  Future<void> _saveProgress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();  // SharedPreferencesのインスタンスを取得
    await prefs.setInt('adRemovalProgress', _progress);  // 現在の進捗を保存
    await prefs.setBool('hasReviewed', _hasReviewed);  // レビュー完了状態を保存
    await prefs.setBool('videoWatched', _videoWatched);  // 動画視聴状態を保存
    if (_progress == 3) {
      _adsRemoved = true;
      await prefs.setBool('adsRemoved', true);  // 広告が削除されたことを保存
    }
  }


  // SharedPreferencesから進捗状況を読み込む
  Future<void> _loadProgress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _progress = prefs.getInt('adRemovalProgress') ?? 1;
      _hasReviewed = prefs.getBool('hasReviewed') ?? false;
    });
  }

  // バナー広告を読み込む関数
  void _loadBannerAds() {
    _topBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',  // トップのバナー広告ユニットID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isTopBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('トップバナー広告の読み込みに失敗しました: $error');
        },
      ),
    )..load();

    _bottomBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',  // ボトムのバナー広告ユニットID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBottomBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('ボトムバナー広告の読み込みに失敗しました: $error');
        },
      ),
    )..load();
  }
}
