// 진짜 앱을 띄워놓고 하는 테스트입니다.
//
// ── 왜 따로 있는가 ──
// `test/` 폴더의 일반 테스트에서는 **웹뷰가 아예 안 켜집니다.** 그래서
// "재생 화면을 열었다 닫으면 어떻게 되는가" 같은 것을 확인할 수 없습니다.
// 실제로 그 상황에서 앱이 통째로 꺼지는 문제가 있었는데, 일반 테스트로는
// 아무리 돌려도 잡히지 않았습니다.
//
// 이 폴더의 테스트는 진짜 앱을 실행해서 진짜 웹뷰를 만듭니다.
//
//   flutter test integration_test -d windows
//
// 느리고, 창이 실제로 떴다 사라지므로 자주 돌리지는 않습니다.
// **웹뷰가 얽힌 문제를 쫓을 때만** 씁니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:reference_archive_app/screens/youtube_player_screen.dart';
import 'package:reference_archive_app/services/local_player_server.dart';
import 'package:reference_archive_app/services/youtube_url.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 실제로 존재하는 영상 번호입니다. 재생까지 되는지는 안 보고,
  // 화면을 열었다 닫는 동안 앱이 살아있는지만 봅니다.
  const String videoId = 'dQw4w9WgXcQ';

  testWidgets('재생 화면을 열었다 닫아도 앱이 살아있다', (WidgetTester tester) async {
    // ── 이 테스트가 잡으려는 것 ──
    // 재생 화면에서 뒤로 나오면 앱이 통째로 꺼지는 문제가 있었습니다.
    // Dart 오류가 아니라 네이티브 쪽에서 죽는 것이라, 앱이 살아만 있어도
    // 통과입니다. 죽으면 테스트 진행 자체가 끊깁니다.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('목록 화면인 척'))),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('목록 화면인 척'));

    // 재생 화면을 엽니다.
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            const YoutubePlayerScreen(videoId: videoId, title: '테스트 영상'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('브라우저에서 열기'), findsOneWidget);

    // 영상이 실제로 뜰 시간을 조금 줍니다.
    // 곧바로 닫으면 웹뷰가 미처 다 만들어지기 전이라, 사용자가 겪은 상황과
    // 달라집니다.
    await tester.pump(const Duration(seconds: 3));

    // 뒤로 나옵니다. 사용자가 위쪽 화살표를 누르는 것과 같습니다.
    Navigator.of(tester.element(find.byType(YoutubePlayerScreen))).pop();
    await tester.pumpAndSettle();

    // 여기까지 왔으면 앱이 안 죽은 것입니다.
    expect(find.text('목록 화면인 척'), findsOneWidget);
  });

  testWidgets('재생 화면을 여러 번 열었다 닫아도 앱이 살아있다', (WidgetTester tester) async {
    // 한 번은 괜찮은데 두세 번째에 죽는 경우가 있습니다.
    // (웹뷰를 정리하는 쪽 문제는 대개 이렇게 나타납니다)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('목록 화면인 척'))),
      ),
    );
    await tester.pumpAndSettle();

    for (int attempt = 1; attempt <= 3; attempt++) {
      final BuildContext context = tester.element(find.text('목록 화면인 척'));

      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              const YoutubePlayerScreen(videoId: videoId, title: '테스트 영상'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      Navigator.of(tester.element(find.byType(YoutubePlayerScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.text('목록 화면인 척'), findsOneWidget, reason: '$attempt번째');
    }
  });

  testWidgets('미리보기가 켜진 채로 재생 화면을 열었다 닫아도 앱이 살아있다', (
    WidgetTester tester,
  ) async {
    // ── 실제로 사용자가 겪은 상황 ──
    // 카드에 마우스를 올리면 미리보기 웹뷰가 하나 켜집니다. 그 상태에서 ▶를
    // 누르면 재생 화면이 열리므로 **웹뷰가 두 개**가 됩니다. 뒤로 나올 때
    // 한쪽만 정리되는데, 그때 앱이 통째로 꺼졌습니다.
    //
    // 위의 두 테스트는 웹뷰가 하나뿐이라 이 상황을 못 잡습니다.
    final LocalPlayerServer previewServer = LocalPlayerServer();
    addTearDown(previewServer.stop);

    final String? previewUrl = await previewServer.start(
      youtubePlayerHtml(videoId, muted: true),
    );
    expect(previewUrl, isNotNull);

    // 목록 화면에서 미리보기가 돌고 있는 상태를 흉내냅니다.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const Text('목록 화면인 척'),
              SizedBox(
                width: 200,
                height: 120,
                child: IgnorePointer(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(previewUrl!)),
                    initialSettings: InAppWebViewSettings(
                      mediaPlaybackRequiresUserGesture: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // 미리보기가 켜진 채로 재생 화면을 엽니다. 이제 웹뷰가 둘입니다.
    Navigator.of(tester.element(find.text('목록 화면인 척'))).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            const YoutubePlayerScreen(videoId: videoId, title: '테스트 영상'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // 뒤로 나옵니다.
    Navigator.of(tester.element(find.byType(YoutubePlayerScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.text('목록 화면인 척'), findsOneWidget);
  });

  testWidgets('웹뷰가 사라지는 순간 새 웹뷰가 생겨도 앱이 살아있다', (WidgetTester tester) async {
    // ── 가장 의심스러운 순간 ──
    // 재생 화면에서 뒤로 나오면 그 웹뷰가 정리됩니다. 그런데 마우스는 여전히
    // 카드 위에 있으므로 **곧바로 미리보기 웹뷰가 새로 만들어집니다.**
    // 하나가 사라지는 도중에 다른 하나가 생기는 셈입니다.
    //
    // 앞의 테스트들은 웹뷰가 가만히 있었기 때문에 이 순간을 못 만들었습니다.
    final LocalPlayerServer previewServer = LocalPlayerServer();
    addTearDown(previewServer.stop);

    final String? previewUrl = await previewServer.start(
      youtubePlayerHtml(videoId, muted: true),
    );

    await tester.pumpWidget(
      MaterialApp(home: _PreviewHarness(previewUrl: previewUrl!)),
    );
    await tester.pumpAndSettle();

    final _PreviewHarnessState harness = tester.state<_PreviewHarnessState>(
      find.byType(_PreviewHarness),
    );

    // 미리보기를 켭니다.
    harness.showPreview(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    // 재생 화면을 열면서 미리보기를 끕니다. (마우스가 카드를 벗어나는 상황)
    harness.showPreview(false);
    Navigator.of(tester.element(find.byType(_PreviewHarness))).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            const YoutubePlayerScreen(videoId: videoId, title: '테스트 영상'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    // 뒤로 나오면서 **곧바로** 미리보기를 다시 켭니다.
    Navigator.of(tester.element(find.byType(YoutubePlayerScreen))).pop();
    harness.showPreview(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(_PreviewHarness), findsOneWidget);
  });

  // 데이터베이스를 쓰지 않는 테스트지만, 앱 코드가 drift를 들여오므로
  // 준비만 해둡니다. (안 쓰면 경고가 납니다)
  test('데이터베이스는 이 테스트에서 쓰지 않습니다', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.close();
  });
}

/// 미리보기 웹뷰를 마음대로 켰다 껐다 할 수 있는 테스트용 화면입니다.
///
/// 실제 목록 화면에서 마우스를 올렸다 뗐다 하는 것과 같은 일을 합니다.
class _PreviewHarness extends StatefulWidget {
  const _PreviewHarness({required this.previewUrl});

  final String previewUrl;

  @override
  State<_PreviewHarness> createState() => _PreviewHarnessState();
}

class _PreviewHarnessState extends State<_PreviewHarness> {
  bool _showPreview = false;

  /// 미리보기를 켜거나 끕니다.
  void showPreview(bool show) {
    setState(() {
      _showPreview = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const Text('목록 화면인 척'),
          SizedBox(
            width: 200,
            height: 120,
            child: _showPreview
                ? IgnorePointer(
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(widget.previewUrl),
                      ),
                      initialSettings: InAppWebViewSettings(
                        mediaPlaybackRequiresUserGesture: false,
                      ),
                    ),
                  )
                : const ColoredBox(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
