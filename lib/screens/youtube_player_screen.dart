// 유튜브 영상을 앱 안에서 재생하는 화면입니다.
//
// ── 앱 안에서 재생한다는 것의 의미 ──
// 유튜브 영상은 우리가 파일로 갖고 있는 것이 아니라 유튜브 서버에서 흘러옵니다.
// 그래서 "재생"하려면 결국 **작은 브라우저를 앱 안에 하나 띄우고** 거기에
// 유튜브 재생기를 올리는 방식이 됩니다. 그 작은 브라우저가 웹뷰(WebView)입니다.
//
// 기존 웹앱이 iframe으로 하던 것과 원리가 같습니다. 다만 그때는 앱 자체가
// 브라우저 안에 있었고, 지금은 브라우저를 앱 안으로 데려온 것이 다릅니다.
//
// ── Windows에서 주의할 점 ──
// Windows에서는 이 웹뷰가 **WebView2 런타임**이라는 마이크로소프트 부품을 씁니다.
// Windows 11에는 기본으로 깔려 있지만, 없는 컴퓨터에서는 웹뷰가 안 뜹니다.
// 그래서 이 화면에는 **언제나 "브라우저에서 열기" 버튼이 함께 있습니다.**
// 웹뷰가 실패해도 사용자가 영상을 못 보는 상황은 없어야 합니다.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/youtube_url.dart';

/// 유튜브 영상을 앱 안에서 재생하는 화면입니다.
class YoutubePlayerScreen extends StatefulWidget {
  const YoutubePlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  /// 재생할 영상 번호입니다.
  final String videoId;

  /// 화면 위쪽에 보여줄 제목입니다. 비어 있으면 "유튜브 영상"으로 대신합니다.
  final String title;

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  /// 아직 영상이 다 뜨지 않았는지 여부입니다. 뜨는 동안 빙글빙글을 보여줍니다.
  bool _isLoading = true;

  /// 웹뷰를 띄우지 못했을 때의 이유입니다. 문제가 없으면 null입니다.
  String? _errorMessage;

  /// 이 환경에서 앱 안 재생이 되는지 여부입니다.
  ///
  /// ── 운영체제 이름으로 판단하지 않는 이유 ──
  /// "Windows면 된다"고 적어두면, 웹뷰 부품이 준비되지 않은 경우
  /// (리눅스, 또는 테스트처럼 플러그인이 안 켜진 환경)에 웹뷰를 만들려다
  /// **빨간 오류 화면**이 뜹니다. 사용자는 앱이 고장난 줄 압니다.
  ///
  /// 그래서 이름 대신 **부품이 실제로 준비됐는지**를 직접 물어봅니다.
  /// 준비가 안 됐으면 조용히 "브라우저에서 열기" 안내로 넘어갑니다.
  bool get _canPlayInApp {
    return InAppWebViewPlatform.instance != null;
  }

  /// 기본 브라우저에서 이 영상을 엽니다.
  ///
  /// 웹뷰가 안 될 때의 피난처이자, "댓글도 보고 싶다" 같은 경우의 통로입니다.
  Future<void> _openInBrowser() async {
    final Uri uri = Uri.parse(youtubeWatchUrl(widget.videoId));

    // launchUrl은 열지 못하면 false를 돌려줍니다.
    // externalApplication = 앱 안이 아니라 진짜 브라우저에서 열라는 뜻입니다.
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('브라우저를 열지 못했습니다.')),
      );
    }
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title.isEmpty ? '유튜브 영상' : widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            tooltip: '브라우저에서 열기',
          ),
        ],
      ),

      // 영상 재생 중에는 검은 바탕이 자연스럽습니다.
      backgroundColor: Colors.black,

      body: _buildBody(),
    );
  }

  /// 상황에 따라 재생기·오류 안내 중 하나를 만듭니다.
  Widget _buildBody() {
    if (!_canPlayInApp) {
      return _buildFallback('이 환경에서는 앱 안에서 재생할 수 없습니다.');
    }

    if (_errorMessage != null) {
      return _buildFallback(_errorMessage!);
    }

    // Stack으로 재생기 위에 "불러오는 중" 표시를 겹칩니다.
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _buildWebView()),

        if (_isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  /// 유튜브 재생기를 담은 웹뷰를 만듭니다.
  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(youtubeEmbedUrl(widget.videoId))),

      initialSettings: InAppWebViewSettings(
        // 이 값이 true면 "사용자가 직접 누르기 전에는 재생 금지"가 됩니다.
        // 영상을 보려고 연 화면이니 바로 재생되는 편이 자연스럽습니다.
        mediaPlaybackRequiresUserGesture: false,

        // 유튜브 재생기는 자바스크립트로 동작합니다. 끄면 아무것도 안 나옵니다.
        javaScriptEnabled: true,

        // 아이폰에서 전체화면으로 튕기지 않고 그 자리에서 재생하게 합니다.
        allowsInlineMediaPlayback: true,

        // 전체화면 버튼을 쓸 수 있게 합니다.
        iframeAllowFullscreen: true,
      ),

      onLoadStop: (InAppWebViewController controller, WebUri? url) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
        });
      },

      onReceivedError: (
        InAppWebViewController controller,
        WebResourceRequest request,
        WebResourceError error,
      ) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          // 오류 코드를 그대로 보여줘도 사용자는 무슨 뜻인지 모릅니다.
          // 실제로 가장 흔한 원인(인터넷)을 짚어줍니다.
          _errorMessage = '영상을 불러오지 못했습니다. 인터넷 연결을 확인해주세요.';
        });
      },
    );
  }

  /// 앱 안에서 재생할 수 없을 때 보여주는 안내입니다.
  ///
  /// 안내만 하고 끝내면 사용자는 영상을 못 봅니다. 브라우저로 가는 길을 함께 둡니다.
  Widget _buildFallback(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.smart_display_outlined,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('브라우저에서 열기'),
            ),
          ],
        ),
      ),
    );
  }
}
