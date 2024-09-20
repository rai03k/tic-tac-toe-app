import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  bool _adsRemoved = false;

  @override
  void initState() {
    super.initState();
    _checkAdRemovalStatus();
  }

  Future<void> _checkAdRemovalStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool('adsRemoved') ?? false;

    if (!_adsRemoved) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/9214589741',  // 実際の広告ユニットIDに置き換えてください
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Failed to load a banner ad: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adsRemoved) {
      return const SizedBox();  // 広告が削除されている場合は何も表示しない
    }

    if (_isBannerAdLoaded && _bannerAd != null) {
      return SizedBox(
        height: _bannerAd!.size.height.toDouble(),
        width: MediaQuery.of(context).size.width,
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      return const SizedBox();  // 広告が読み込まれていない場合は空のウィジェットを返す
    }
  }
}
