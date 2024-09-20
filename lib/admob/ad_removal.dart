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
  late AnimationController _controller;
  late Animation<double> _animation;
  RewardedAd? _rewardedAd;  // 動画広告

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: _progress.toDouble() / 3).animate(_controller);
    _controller.forward();

    _loadRewardedAd();
  }

  // SharedPreferences から進捗状況を読み込む
  Future<void> _loadProgress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _progress = prefs.getInt('adRemovalProgress') ?? 1;  // 初期状態は1点目
      _hasReviewed = prefs.getBool('hasReviewed') ?? false;
      _videoWatched = prefs.getBool('videoWatched') ?? false;
      _adsRemoved = prefs.getBool('adsRemoved') ?? false;  // 広告が削除されたかどうかを確認
    });
  }

  // SharedPreferences に進捗を保存する
  Future<void> _saveProgress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('adRemovalProgress', _progress);
    await prefs.setBool('hasReviewed', _hasReviewed);
    await prefs.setBool('videoWatched', _videoWatched);
    if (_progress == 3) {
      _adsRemoved = true;
      await prefs.setBool('adsRemoved', true);  // 広告を削除
    }
  }

  // 動画広告を読み込む
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',  // 広告ユニットID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Failed to load a rewarded ad: $error');
        },
      ),
    );
  }

  // 動画広告を表示して、進捗を更新する
  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        setState(() {
          if (_progress < 3) _progress++;
          _videoWatched = true;  // 動画を視聴した
          _saveProgress();
          _controller.reset();
          _animation = Tween<double>(begin: 0, end: _progress.toDouble() / 3).animate(_controller);
          _controller.forward();
        });
        // 動画が再生された後、新しい広告をロードする
        _loadRewardedAd();
      });
    }
  }

  // レビューを書くと進捗を更新する
  Future<void> _writeReview() async {
    const reviewUrl = 'https://example.com/review';  // レビューのリンクをここに
    if (await canLaunch(reviewUrl)) {
      await launch(reviewUrl);  // リンクを起動
      setState(() {
        _hasReviewed = true;
        if (_progress < 3) _progress++;
        _saveProgress();
        _controller.reset();
        _animation = Tween<double>(begin: 0, end: _progress.toDouble() / 3).animate(_controller);
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove Ads'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,  // 全体を中央寄せに
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 進捗を表示するアニメーションバー
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),  // 横に少し余白を追加
              child: Column(
                children: [
                  const Text(
                    'Progress to Remove Ads',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _progress == 3 ? 1 : _animation.value,  // 3/3 なら常にバーを満たす
                        minHeight: 20,
                        color: _progress == 3 ? Colors.orange : Colors.orangeAccent,
                        backgroundColor: Colors.grey[300],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$_progress / 3 steps completed',
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 2点目：レビューか動画再生
            if (_progress == 1 && !_hasReviewed)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _writeReview,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Write a Review',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _rewardedAd != null ? _showRewardedAd : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Watch Video to Remove Ads',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),

            // 3点目：レビュー済みの人は動画再生のみ
            if (_progress == 2 || (_progress == 1 && _hasReviewed))
              ElevatedButton(
                onPressed: _rewardedAd != null ? _showRewardedAd : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Watch Video to Remove Ads',
                  style: TextStyle(fontSize: 18),
                ),
              ),

            const SizedBox(height: 40),

            // 進捗が完了した場合、広告が非表示になります
            if (_progress == 3)
              const Text(
                'Ads have been removed!',
                style: TextStyle(fontSize: 18, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}
