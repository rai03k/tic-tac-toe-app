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

  @override
  void initState() {
    super.initState();
    _loadProgress();  // SharedPreferencesから進捗状況を読み込む
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

  // バナー広告を読み込む関数
  void _loadBannerAds() {
    _topBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/9214589741', // トップのバナー広告ユニットID
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isTopBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('トップバナー広告の読み込みに失敗しました: $error');
          ad.dispose();
        },
      ),
    )..load();

    _bottomBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/9214589741', // ボトムのバナー広告ユニットID
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBottomBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('ボトムバナー広告の読み込みに失敗しました: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();  // アニメーションコントローラーを破棄
    _rewardedAd?.dispose();  // 動画広告を破棄
    _topBannerAd?.dispose();  // トップバナー広告を破棄
    _bottomBannerAd?.dispose();  // ボトムバナー広告を破棄
    super.dispose();
  }

  // SharedPreferences から進捗状況を読み込む関数
  Future<void> _loadProgress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();  // SharedPreferencesのインスタンスを取得
    setState(() {
      _progress = prefs.getInt('adRemovalProgress') ?? 1;  // 初期状態は1点目
      _hasReviewed = prefs.getBool('hasReviewed') ?? false;
      _videoWatched = prefs.getBool('videoWatched') ?? false;
      _adsRemoved = prefs.getBool('adsRemoved') ?? false;  // 広告が削除されたかどうかを確認
    });
  }

  // SharedPreferences に進捗を保存する関数
  Future<void> _saveProgress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();  // SharedPreferencesのインスタンスを取得
    await prefs.setInt('adRemovalProgress', _progress);  // 現在の進捗を保存
    await prefs.setBool('hasReviewed', _hasReviewed);  // レビュー完了状態を保存
    await prefs.setBool('videoWatched', _videoWatched);  // 動画視聴状態を保存
    if (_progress == 3) {
      _adsRemoved = true;
      await prefs.setBool('adsRemoved', true);  // 広告を削除したことを保存
    }
  }

  // 動画広告を読み込む関数
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
          print('動画広告の読み込みに失敗しました: $error');  // エラー時の処理
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
        _loadRewardedAd();  // 新しい広告を読み込む
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
        _controller.reset();  // アニメーションをリセット
        _animation = Tween<double>(begin: 0, end: _progress.toDouble() / 3).animate(_controller);
        _controller.forward();  // アニメーションを再開
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove Ads'),  // AppBarのタイトル
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
                  // 進捗バーを表示するアニメーション
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),  // 横に余白を追加
                    child: Column(
                      children: [
                        const Text(
                          'Progress to Remove Ads',  // 進捗状況の説明
                          style: TextStyle(fontSize: 24),
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
                          '$_progress / 3 steps completed',  // 進捗状況を表示
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 進捗が1点目の場合、レビューか動画再生が可能
                  if (_progress == 1 && !_hasReviewed)
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
                          child: const Text(
                            'Write a Review',  // ボタンのテキスト
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _rewardedAd != null ? _showRewardedAd : null,  // 動画再生
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),  // 角を丸くする
                            ),
                          ),
                          child: const Text(
                            'Watch Video to Remove Ads',  // ボタンのテキスト
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),

                  // 進捗が2点目か、レビュー済みの場合は動画再生のみ
                  if (_progress == 2 || (_progress == 1 && _hasReviewed))
                    ElevatedButton(
                      onPressed: _rewardedAd != null ? _showRewardedAd : null,  // 動画再生
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),  // 角を丸くする
                        ),
                      ),
                      child: const Text(
                        'Watch Video to Remove Ads',  // ボタンのテキスト
                        style: TextStyle(fontSize: 18),
                      ),
                    ),

                  const SizedBox(height: 40),

                  // 進捗が完了した場合、広告が非表示になるメッセージを表示
                  if (_progress == 3)
                    const Text(
                      'Ads have been removed!',  // 広告が削除されたことを表示
                      style: TextStyle(fontSize: 18, color: Colors.orange),
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
}
