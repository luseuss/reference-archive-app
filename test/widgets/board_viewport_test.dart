// 판을 확대·축소하고 이동해서 보여주는 창(BoardViewport)을 확인하는 테스트입니다.
//
// ── 여기서 특히 확인하는 것 ──
// 확대·축소는 **길을 잃기 쉬운 기능**입니다. 확대했더니 판이 어디론가 사라지거나,
// 축소해도 되돌아오지 않으면 사용자는 앱을 껐다 켜는 수밖에 없습니다.
// 그래서 "판이 언제나 화면 안에 남는지"와 "되돌아올 수 있는지"를 봅니다.
//
// 판 안에 무엇이 그려지는지는 여기서 안 봅니다. 그건 board_screen_test.dart가 봅니다.
// 이 창은 카드가 뭔지 모르게 만들어져 있어서, 빈 상자를 넣고도 확인할 수 있습니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/theme/app_metrics.dart';
import 'package:reference_archive_app/widgets/board_viewport.dart';

void main() {
  /// 판 안에 넣을 빈 상자를 찾을 이름표입니다.
  ///
  /// 실제 카드 대신 이걸 넣고, **화면에 그려진 크기와 자리**를 재서
  /// 지금 몇 배로 어디에 그려졌는지 되짚습니다.
  const ValueKey<String> contentKey = ValueKey<String>('board-content');

  /// 테스트용 화면 크기입니다.
  ///
  /// 판이 1920×1200이므로 이 크기에서는 딱 0.5배가 됩니다.
  /// 계산이 떨어지는 숫자라 기댓값을 적기 쉽습니다.
  const Size testViewport = Size(960, 600);

  /// 이 크기에서 판 전체가 보이는 배율입니다.
  const double fitScale = 0.5;

  /// 창을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openViewport(WidgetTester tester) async {
    tester.view.physicalSize = testViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BoardViewport(child: SizedBox.expand(key: contentKey)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 판이 지금 화면의 어디에 얼마만 한 크기로 그려져 있는지 돌려줍니다.
  ///
  /// `getSize`가 아니라 두 모서리의 **화면 좌표**로 구합니다. getSize는 확대·축소
  /// 전의 크기(언제나 1920×1200)를 돌려주기 때문에 배율을 알 수 없습니다.
  Rect shownRect(WidgetTester tester) {
    return Rect.fromPoints(
      tester.getTopLeft(find.byKey(contentKey)),
      tester.getBottomRight(find.byKey(contentKey)),
    );
  }

  /// 판이 지금 몇 배로 그려져 있는지 돌려줍니다.
  double shownScale(WidgetTester tester) {
    return shownRect(tester).width / boardWidth;
  }

  testWidgets('처음에는 판 전체가 화면에 들어온다', (WidgetTester tester) async {
    await openViewport(tester);

    expect(shownScale(tester), closeTo(fitScale, 0.001));

    final Rect shown = shownRect(tester);
    expect(shown.width, lessThanOrEqualTo(testViewport.width + 0.5));
    expect(shown.height, lessThanOrEqualTo(testViewport.height + 0.5));
  });

  testWidgets('지금 배율이 퍼센트로 보인다', (WidgetTester tester) async {
    // 숫자가 없으면 "얼마나 확대했더라?"를 알 방법이 없고,
    // 원래 크기로 돌아왔는지도 알 수 없습니다.
    await openViewport(tester);

    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('확대 버튼을 누르면 판이 커진다', (WidgetTester tester) async {
    await openViewport(tester);

    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();

    expect(shownScale(tester), closeTo(fitScale * boardZoomStep, 0.001));
  });

  testWidgets('판 전체가 보이는 배율보다 더 축소되지 않는다', (WidgetTester tester) async {
    // 더 줄여봐야 판 주위의 빈 공간만 넓어질 뿐 보이는 것은 안 늘어납니다.
    await openViewport(tester);

    await tester.tap(find.byTooltip('축소'));
    await tester.pumpAndSettle();

    expect(shownScale(tester), closeTo(fitScale, 0.001));
  });

  testWidgets('"판 전체 보기"를 누르면 되돌아온다', (WidgetTester tester) async {
    // ── 이게 이 파일의 핵심입니다 ──
    // 확대하다 길을 잃었을 때 돌아올 곳이 없으면 앱을 껐다 켜는 수밖에 없습니다.
    await openViewport(tester);

    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();

    expect(shownScale(tester), greaterThan(fitScale));

    await tester.tap(find.byTooltip('판 전체 보기'));
    await tester.pumpAndSettle();

    expect(shownScale(tester), closeTo(fitScale, 0.001));
  });

  testWidgets('판이 화면보다 작으면 가운데에 놓인다', (WidgetTester tester) async {
    // 구석에 치우쳐 있으면 어색하고, 어디가 판의 끝인지도 헷갈립니다.
    tester.view.physicalSize = const Size(1920 * 2, 1200 * 2);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BoardViewport(child: SizedBox.expand(key: contentKey)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect shown = shownRect(tester);

    // 화면이 판보다 크므로 억지로 늘리지 않고 원래 크기(1배)로 둡니다.
    expect(shown.width, closeTo(boardWidth, 0.5));

    // 왼쪽 여백과 오른쪽 여백이 같아야 가운데입니다.
    final double leftGap = shown.left;
    final double rightGap = 1920 * 2 - shown.right;
    expect(leftGap, closeTo(rightGap, 0.5));
  });

  testWidgets('확대한 뒤 빈 곳을 끌면 판이 움직인다', (WidgetTester tester) async {
    await openViewport(tester);

    // 판이 화면보다 커야 옮길 자리가 생깁니다.
    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();

    final Rect before = shownRect(tester);

    await tester.dragFrom(
      const Offset(480, 300),
      const Offset(-60, -40),
    );
    await tester.pumpAndSettle();

    final Rect after = shownRect(tester);

    expect(after.left - before.left, closeTo(-60, 1));
    expect(after.top - before.top, closeTo(-40, 1));
  });

  testWidgets('판을 화면 밖으로 완전히 밀어낼 수 없다', (WidgetTester tester) async {
    // 안 막으면 빈 화면만 보게 되고, 판을 되찾을 방법이 "판 전체 보기"뿐입니다.
    await openViewport(tester);

    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(480, 300), const Offset(-5000, -5000));
    await tester.pumpAndSettle();

    final Rect shown = shownRect(tester);

    // 판의 오른쪽 아래 끝이 화면 끝보다 안쪽으로 들어오면 안 됩니다.
    expect(shown.right, greaterThanOrEqualTo(testViewport.width - 0.5));
    expect(shown.bottom, greaterThanOrEqualTo(testViewport.height - 0.5));
  });
}
