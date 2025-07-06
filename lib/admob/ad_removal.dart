import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';  // url_launcher をインポート
import 'package:google_mobile_ads/google_mobile_ads.dart';  // 動画広告をインポート
import 'dart:io';  // Platformを使用するために追加
import 'package:in_app_review/in_app_review.dart';  // in_app_review をインポート
import '../data/language.dart';  // LanguageData クラスをインポート

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
  String _selectedLanguage = 'en'; // 初期言語

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

  // 翻訳を取得する関数
  String _getTranslation(String key) {
    return LanguageData.getTranslation(_selectedLanguage, key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove Ads'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
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
                      if (_progress == 1 && !_hasReviewed) // 進捗が1かつレビューが未完了の時のみ表示
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
            ],
          ),
          if (!_adsRemoved && _isTopBannerAdLoaded)
            Positioned(
              top: 0,  // 画面の上部に固定
              left: 0,
              right: 0,
              child: Container(
                width: _topBannerAd!.size.width.toDouble(),
                height: _topBannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _topBannerAd!),  // トップバナー広告ウィジェット
              ),
            ),
          if (!_adsRemoved && _isBottomBannerAdLoaded)
            Positioned(
              bottom: 0,  // 画面の下部に固定
              left: 0,
              right: 0,
              child: Container(
                width: _bottomBannerAd!.size.width.toDouble(),
                height: _bottomBannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bottomBannerAd!),  // ボトムバナー広告ウィジェット
              ),
            ),
        ],
      ),
    );
  }


  // 動画広告の読み込み
  void _loadRewardedAd() {
    String rewardedAdUnitId;

    // デバイスごとにリワード広告ユニットIDを設定
    if (Platform.isAndroid) {
      rewardedAdUnitId = 'ca-app-pub-1187210314934709/3878530320';  // Android用のリワード広告ユニットID
    } else if (Platform.isIOS) {
      rewardedAdUnitId = 'ca-app-pub-1187210314934709/3181994937';  // iOS用のリワード広告ユニットID
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,  // ユニットIDを設定
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;  // 読み込まれたリワード広告を保存
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('リワード広告の読み込みに失敗しました: $error');
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
        // 動画視聴後、画面をリロードして進捗を反映
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (BuildContext context) => const AdRemovalScreen()),
          );
        });
        // 動画視聴後、古い広告を破棄し、新しい広告をロードする
        _rewardedAd!.dispose();  // 古い広告を破棄
        _loadRewardedAd();  // 新しい広告をロード
      });
    }
  }


  Future<void> _writeReview() async {
    final InAppReview inAppReview = InAppReview.instance;

    // 全画面の操作不能なロードインジケーターを表示
    showDialog(
      context: context,
      barrierDismissible: false,  // 外側をタップしても閉じないようにする
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,  // バックボタンで閉じないようにする
          child: const Center(
            child: CircularProgressIndicator(),  // 中央にロードインジケーターを表示
          ),
        );
      },
    );

    try {
      if (await inAppReview.isAvailable()) {
        // アプリ内レビューリクエストを送信
        await inAppReview.requestReview();

        // リクエストが完了したらダイアログを閉じる
        Navigator.of(context).pop();

        // 成功時に進捗やレビューの状態を保存
        setState(() {
          _hasReviewed = true;  // レビュー完了フラグを立てる
          _progress = 2;        // 進捗を2に進める
          _saveProgress();      // 進捗を保存
        });
      } else {
        // アプリ内レビューが利用できない場合
        throw Exception('アプリ内レビューが利用できません');
      }
    } catch (e) {
      // エラー発生時もダイアログを閉じる
      Navigator.of(context).pop();
      print(e);
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
      _videoWatched = prefs.getBool('videoWatched') ?? false;
      _adsRemoved = prefs.getBool('adsRemoved') ?? false;  // 広告が削除されたかどうかを確認
    });
  }

  // バナー広告を読み込む関数
  void _loadBannerAds() {
    String topBannerAdUnitId;
    String bottomBannerAdUnitId;

    // デバイスごとに広告ユニットIDを設定
    if (Platform.isAndroid) {
      topBannerAdUnitId = 'ca-app-pub-1187210314934709/9243517580';  // Android用のトップバナー広告ユニットID
      bottomBannerAdUnitId = 'ca-app-pub-1187210314934709/9243517580';  // Android用のボトムバナー広告ユニットID
    } else if (Platform.isIOS) {
      topBannerAdUnitId = 'ca-app-pub-1187210314934709/7887834192';  // iOS用のトップバナー広告ユニットID
      bottomBannerAdUnitId = 'ca-app-pub-1187210314934709/7887834192';  // iOS用のボトムバナー広告ユニットID
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    _topBannerAd = BannerAd(
      adUnitId: topBannerAdUnitId,  // トップのバナー広告ユニットID
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
      adUnitId: bottomBannerAdUnitId,  // ボトムのバナー広告ユニットID
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
