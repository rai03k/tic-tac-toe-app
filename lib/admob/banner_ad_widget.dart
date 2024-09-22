import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;  // バナー広告インスタンス
  bool _isBannerAdLoaded = false;  // 広告が読み込まれたかどうかのフラグ
  bool _adsRemoved = false;  // 広告が削除されたかどうかのフラグ

  @override
  void initState() {
    super.initState();
    _checkAdRemovalStatus();  // 広告削除のステータスをチェック
  }

  // SharedPreferencesから広告削除のステータスを読み込む関数
  Future<void> _checkAdRemovalStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();  // SharedPreferencesのインスタンスを取得
    _adsRemoved = prefs.getBool('adsRemoved') ?? false;  // 広告が削除されているかどうかを取得

    // 広告が削除されていない場合、バナー広告を読み込む
    if (!_adsRemoved) {
      _loadBannerAd();
    }
  }

  // バナー広告を読み込む関数
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/9214589741',  // 実際の広告ユニットIDに置き換えてください
      size: AdSize.banner,  // バナー広告のサイズ
      request: const AdRequest(),  // 広告リクエスト
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;  // 広告が読み込まれた場合の処理
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();  // 広告の破棄
          print('Failed to load a banner ad: $error');  // エラー時のログ
        },
      ),
    )..load();  // 広告の読み込みを実行
  }

  @override
  void dispose() {
    _bannerAd?.dispose();  // バナー広告を破棄
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 広告が削除されている場合、何も表示しない
    if (_adsRemoved) {
      return const SizedBox();  // 空のウィジェットを返す
    }

    // 広告が読み込まれた場合、広告を表示
    if (_isBannerAdLoaded && _bannerAd != null) {
      return SizedBox(
        height: _bannerAd!.size.height.toDouble(),  // バナー広告の高さ
        width: MediaQuery.of(context).size.width,  // 画面幅に広告を合わせる
        child: AdWidget(ad: _bannerAd!),  // AdWidgetを表示
      );
    } else {
      return const SizedBox();  // 広告が読み込まれていない場合は空のウィジェットを返す
    }
  }
}
