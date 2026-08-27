// 판을 확대·축소하고 이동해서 보여주는 창(BoardViewport)을 확인하는 테스트입니다.
//
// ── 여기서 특히 확인하는 것 ──
// 판에 끝이 없어진 뒤로 **⛶(카드 전부 보기)가 유일한 안전장치**입니다.
// 확대하다 길을 잃거나 카드를 멀리 옮겨두어도, 이것만 누르면 전부 다시
// 보여야 합니다. 이게 깨지면 사용자는 사진을 잃어버립니다.
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
  const Size testViewport = Size(960, 600);

  /// 카드를 그릴 자리의 크기입니다.
  const Size testCanvas = Size(1920, 1200);

  /// 카드들이 놓인 범위입니다.
  ///
  /// 이 크기에서 ⛶ 배율이 **딱 0.5배**가 되도록 골랐습니다.
  /// (화면 960에서 여백을 빼면 880, 범위가 1760이므로 절반)
  /// 계산이 떨어지는 숫자라 기댓값을 적기 쉽습니다.
  const Rect testContent = Rect.fromLTWH(0, 0, 1760, 1040);

  /// 위 값들에서 카드 전부가 보이는 배율입니다.
  const double fitScale = 0.5;

  /// 창을 띄우고 다 그려질 때까지 기다립니다.
  Future<void> openViewport(
    WidgetTester tester, {
    int viewResetCount = 0,
    Rect content = testContent,
  }) async {
    tester.view.physicalSize = testViewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardViewport(
            canvasSize: testCanvas,
            contentBounds: content,
            viewResetCount: viewResetCount,
            child: const SizedBox.expand(key: contentKey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 판이 지금 화면의 어디에 얼마만 한 크기로 그려져 있는지 돌려줍니다.
  ///
  /// `getSize`가 아니라 두 모서리의 **화면 좌표**로 구합니다. getSize는 확대·축소
  /// 전의 크기를 돌려주기 때문에 배율을 알 수 없습니다.
  Rect shownRect(WidgetTester tester) {
    return Rect.fromPoints(
      tester.getTopLeft(find.byKey(contentKey)),
      tester.getBottomRight(find.byKey(contentKey)),
    );
  }

  /// 판이 지금 몇 배로 그려져 있는지 돌려줍니다.
  double shownScale(WidgetTester tester) {
    return shownRect(tester).width / testCanvas.width;
  }

  testWidgets('처음에는 카드 전부가 화면에 들어온다', (WidgetTester tester) async {
    await openViewport(tester);

    expect(shownScale(tester), closeTo(fitScale, 0.01));
  });

  testWidgets('지금 배율이 퍼센트로 보인다', (WidgetTester tester) async {
    // 몇 배인지 안 보이면 원래 크기로 돌아왔는지도 알 수 없습니다.
    await openViewport(tester);

    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('확대 버튼을 누르면 판이 커진다', (WidgetTester tester) async {
    await openViewport(tester);
    final double before = shownScale(tester);

    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();

    expect(shownScale(tester), greaterThan(before));
  });

  testWidgets('정해둔 최소 배율보다 더 축소되지 않는다', (WidgetTester tester) async {
    // 판에 끝이 없어서 "판 전체가 보이는 배율"이라는 기준이 없습니다.
    // 대신 숫자로 정해둔 최소치에서 멈춥니다.
    await openViewport(tester);

    for (int i = 0; i < 30; i++) {
      await tester.tap(find.byTooltip('축소'));
      await tester.pumpAndSettle();
    }

    expect(shownScale(tester), greaterThanOrEqualTo(minBoardScale - 0.001));
  });

  testWidgets('"카드 전부 보기"를 누르면 되돌아온다', (WidgetTester tester) async {
    // ── 이게 이 파일의 핵심입니다 ──
    // 확대하다 길을 잃었을 때 돌아올 곳이 없으면 앱을 껐다 켜는 수밖에 없습니다.
    await openViewport(tester);

    for (int i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('확대'));
      await tester.pumpAndSettle();
    }
    expect(shownScale(tester), greaterThan(fitScale));

    await tester.tap(find.byTooltip('판 전체 보기'));
    await tester.pumpAndSettle();

    expect(shownScale(tester), closeTo(fitScale, 0.01));
  });

  testWidgets('빈 곳을 끌면 판이 움직인다', (WidgetTester tester) async {
    // ── 전에는 이게 안 됐습니다 ──
    // 판이 화면보다 작으면 **강제로 가운데**에 두느라 끌기가 무시됐습니다.
    // 이제는 가운데로 잡아끌지 않으므로 그냥 움직입니다.
    await openViewport(tester);

    final Offset before = shownRect(tester).topLeft;

    await tester.dragFrom(const Offset(30, 30), const Offset(90, 60));
    await tester.pumpAndSettle();

    final Offset after = shownRect(tester).topLeft;

    expect(after.dx - before.dx, closeTo(90, 1));
    expect(after.dy - before.dy, closeTo(60, 1));
  });

  testWidgets('카드 범위를 화면 밖으로 완전히 밀어낼 수 없다', (WidgetTester tester) async {
    // 다 밀어내면 빈 화면만 남아서 "내 사진 어디 갔지"가 됩니다.
    await openViewport(tester);

    for (int i = 0; i < 10; i++) {
      await tester.dragFrom(const Offset(500, 300), const Offset(-400, -300));
      await tester.pumpAndSettle();
    }

    final Rect shown = shownRect(tester);

    // 카드 범위(판 좌표 0~1760)의 오른쪽 끝이 화면 안에 조금은 남아야 합니다.
    final double contentRightOnScreen =
        shown.left + testContent.right * shownScale(tester);

    expect(contentRightOnScreen, greaterThan(0));
  });

  testWidgets('되돌리기 신호가 오면 전체 보기로 돌아온다', (WidgetTester tester) async {
    // 레퍼런스를 새로 담았을 때 쓰는 길입니다. 멀리 확대해서 보고 있었다면
    // 새 카드가 화면 밖에 생겨서 "안 담겼나?" 싶어집니다.
    await openViewport(tester);

    for (int i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('확대'));
      await tester.pumpAndSettle();
    }
    expect(shownScale(tester), greaterThan(fitScale));

    // 숫자를 올려서 다시 그립니다.
    await openViewport(tester, viewResetCount: 1);

    expect(shownScale(tester), closeTo(fitScale, 0.01));
  });

  testWidgets('카드가 없으면 1배로 보여준다', (WidgetTester tester) async {
    // 맞출 것이 없습니다. 억지로 배율을 정하지 않습니다.
    await openViewport(tester, content: Rect.zero);

    expect(shownScale(tester), closeTo(1.0, 0.01));
  });
}
