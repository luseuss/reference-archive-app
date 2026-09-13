// 우클릭(또는 길게 누르기) 메뉴 공용 부품(context_menu.dart)을 확인하는
// 테스트입니다.
//
// 화면마다 따로 확인하지 않고 이 부품 하나만 잘 동작하는지 확인합니다 —
// reference_card.dart·app_sidebar.dart·board_card_view.dart·
// board_viewport.dart가 전부 이 부품을 그대로 가져다 쓰기 때문입니다.
//
// ── 왜 진짜 마우스 우클릭을 흉내내지 않는가 ──
// `tester.startGesture(..., buttons: kSecondaryMouseButton)`로 실제
// 오른쪽 클릭을 흉내내봤지만, 위젯 트리(빈 SizedBox)에서는 히트테스트가
// 기대한 대로 되지 않아 자꾸 실패했습니다. 이 부품이 실제로 확인해야
// 하는 것은 "GestureDetector/Listener에 올바른 콜백을 걸어뒀는가, 그
// 콜백이 불리면 메뉴가 뜨고 항목이 실행되는가"이지, Flutter 엔진의
// 마우스 우클릭 히트테스트 자체가 아닙니다. 그래서 위젯을 찾아 콜백을
// **직접 호출**하는, 더 간단하고 확실한 방식으로 확인합니다.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/widgets/context_menu.dart';

void main() {
  testWidgets('우클릭 콜백이 불리면 메뉴가 뜨고, 항목을 누르면 동작이 실행된다', (
    WidgetTester tester,
  ) async {
    bool pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContextMenuRegion(
            buildActions: () => <ContextMenuAction>[
              ContextMenuAction(
                label: '테스트 동작',
                onSelected: () => pressed = true,
              ),
            ],
            child: const SizedBox(width: 100, height: 100, key: Key('target')),
          ),
        ),
      ),
    );

    final GestureDetector detector = tester.widget<GestureDetector>(
      find.byType(GestureDetector),
    );
    detector.onSecondaryTapUp!(
      TapUpDetails(
        kind: PointerDeviceKind.mouse,
        globalPosition: tester.getCenter(find.byKey(const Key('target'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('테스트 동작'), findsOneWidget);

    await tester.tap(find.text('테스트 동작'));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
  });

  testWidgets('길게 누르면 메뉴가 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContextMenuRegion(
            buildActions: () => <ContextMenuAction>[
              ContextMenuAction(label: '롱프레스 동작', onSelected: () {}),
            ],
            child: const SizedBox(width: 100, height: 100, key: Key('target')),
          ),
        ),
      ),
    );

    final GestureDetector detector = tester.widget<GestureDetector>(
      find.byType(GestureDetector),
    );
    detector.onLongPressStart!(
      LongPressStartDetails(
        globalPosition: tester.getCenter(find.byKey(const Key('target'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('롱프레스 동작'), findsOneWidget);
  });

  testWidgets('enableLongPress=false면 길게 눌러도 메뉴가 안 뜬다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContextMenuRegion(
            enableLongPress: false,
            buildActions: () => <ContextMenuAction>[
              ContextMenuAction(label: '안 뜨는 동작', onSelected: () {}),
            ],
            child: const SizedBox(width: 100, height: 100, key: Key('target')),
          ),
        ),
      ),
    );

    final GestureDetector detector = tester.widget<GestureDetector>(
      find.byType(GestureDetector),
    );
    expect(detector.onLongPressStart, isNull);
  });

  testWidgets(
    'avoidGestureArena=true면 마우스 오른쪽 버튼 누름만으로 메뉴가 뜬다',
    (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextMenuRegion(
              avoidGestureArena: true,
              buildActions: () => <ContextMenuAction>[
                ContextMenuAction(
                  label: '아레나 회피 동작',
                  onSelected: () => pressed = true,
                ),
              ],
              child: const SizedBox(
                width: 100,
                height: 100,
                key: Key('target'),
              ),
            ),
          ),
        ),
      );

      final Listener listener = tester.widget<Listener>(
        find.byKey(const ValueKey<String>('context-menu-region-listener')),
      );
      listener.onPointerDown!(
        PointerDownEvent(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
          position: tester.getCenter(find.byKey(const Key('target'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('아레나 회피 동작'), findsOneWidget);

      await tester.tap(find.text('아레나 회피 동작'));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    },
  );

  testWidgets(
    'avoidGestureArena=true에서 왼쪽 버튼을 눌러도 메뉴가 안 뜬다',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContextMenuRegion(
              avoidGestureArena: true,
              buildActions: () => <ContextMenuAction>[
                ContextMenuAction(label: '안 뜨는 동작', onSelected: () {}),
              ],
              child: const SizedBox(
                width: 100,
                height: 100,
                key: Key('target'),
              ),
            ),
          ),
        ),
      );

      final Listener listener = tester.widget<Listener>(
        find.byKey(const ValueKey<String>('context-menu-region-listener')),
      );
      listener.onPointerDown!(
        PointerDownEvent(
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
          position: tester.getCenter(find.byKey(const Key('target'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('안 뜨는 동작'), findsNothing);
    },
  );

  testWidgets('빈 목록을 돌려주면 메뉴가 안 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContextMenuRegion(
            buildActions: () => const <ContextMenuAction>[],
            child: const SizedBox(width: 100, height: 100, key: Key('target')),
          ),
        ),
      ),
    );

    final GestureDetector detector = tester.widget<GestureDetector>(
      find.byType(GestureDetector),
    );
    detector.onSecondaryTapUp!(
      TapUpDetails(
        kind: PointerDeviceKind.mouse,
        globalPosition: tester.getCenter(find.byKey(const Key('target'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<ContextMenuAction>), findsNothing);
  });
}
