// BoardInteractionController의 onSaved 콜백이 저장이 실제로 끝난
// 순간에만 불리는지 확인하는 테스트입니다.
//
// ── 왜 확인하나 ──
// 무드보드 팝업 창(board_popup_controller.dart)이 이 신호를 받아
// 상대 창에 "다시 읽어라"고 알립니다. 드래그 **도중**에도 매번
// 신호가 나가면 상대 창이 매 프레임 다시 그리려 들어 버벅입니다.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/screens/board_interaction_controller.dart';
import 'package:reference_archive_app/utils/board_align.dart';
import 'package:reference_archive_app/utils/board_card_actions.dart';

void main() {
  late AppDatabase db;
  late LocalBoardRepository repository;
  late BoardInteractionController controller;
  late int savedCount;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalBoardRepository(db);
    savedCount = 0;

    final DateTime now = DateTime.now().toUtc();
    await repository.saveBoard(
      Board(id: 'board-1', name: '테스트 판', createdAt: now, updatedAt: now),
    );

    controller = BoardInteractionController(
      boardId: 'board-1',
      boardRepository: repository,
      onSaved: () => savedCount++,
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('카드를 담으면 onSaved가 한 번 불린다', (WidgetTester tester) async {
    await controller.addCards(<String>['ref-1', 'ref-2']);
    expect(savedCount, 1);
  });

  testWidgets('카드를 내리면 onSaved가 한 번 불린다', (WidgetTester tester) async {
    await controller.addCards(<String>['ref-1']);
    savedCount = 0;

    await controller.removeCard(controller.cards.single);
    expect(savedCount, 1);
  });

  testWidgets('드래그 도중에는 onSaved가 안 불리고, 손을 떼야 불린다', (
    WidgetTester tester,
  ) async {
    await controller.addCards(<String>['ref-1']);
    savedCount = 0;
    final BoardCard card = controller.cards.single;

    controller.onDragStart(card);
    controller.onDragUpdate(card, const Offset(10, 10));
    controller.onDragUpdate(card, const Offset(10, 10));
    expect(savedCount, 0, reason: '끄는 도중에는 아직 저장 전입니다');

    await controller.onDragEnd(controller.cards.single);
    expect(savedCount, 1);
  });

  testWidgets('크기조절 도중에는 onSaved가 안 불리고, 손을 떼야 불린다', (
    WidgetTester tester,
  ) async {
    await controller.addCards(<String>['ref-1']);
    savedCount = 0;
    final BoardCard card = controller.cards.single;

    controller.onResizeStart(
      card,
      const Size(200, 150),
      BoardResizeCorner.bottomRight,
    );
    controller.onResizeUpdate(card, const Offset(10, 10));
    expect(savedCount, 0);

    await controller.onResizeEnd(controller.cards.single);
    expect(savedCount, 1);
  });

  testWidgets('addCardAt은 지정한 자리에 정확히 카드를 놓는다', (
    WidgetTester tester,
  ) async {
    await controller.addCardAt('ref-1', const Offset(120, 340));

    final BoardCard card = controller.cards.single;
    expect(card.referenceId, 'ref-1');
    expect(card.x, 120);
    expect(card.y, 340);
  });

  testWidgets('addCardAt도 onSaved를 한 번 부른다', (WidgetTester tester) async {
    await controller.addCardAt('ref-1', const Offset(0, 0));
    expect(savedCount, 1);
  });

  testWidgets('addCardAt은 같은 레퍼런스를 여러 번 담아도 막지 않는다', (
    WidgetTester tester,
  ) async {
    await controller.addCardAt('ref-1', const Offset(0, 0));
    await controller.addCardAt('ref-1', const Offset(200, 50));

    expect(controller.cards.length, 2);
    expect(
      controller.cards.map((BoardCard c) => c.referenceId).toList(),
      <String>['ref-1', 'ref-1'],
    );
  });

  // ── 여기서부터는 탐색기·브라우저에서 파일 여러 개를 한꺼번에 끌어다
  // 놓았을 때 쓰는 addCardsAt입니다 ──

  testWidgets('addCardsAt은 첫 장을 놓은 자리 그대로에 둔다', (
    WidgetTester tester,
  ) async {
    await controller.addCardsAt(<String>['ref-1', 'ref-2'], const Offset(120, 340));

    final BoardCard first = controller.cards.first;
    expect(first.referenceId, 'ref-1');
    expect(first.x, 120);
    expect(first.y, 340);
  });

  testWidgets('addCardsAt은 나머지를 겹치지 않게 늘어놓는다', (
    WidgetTester tester,
  ) async {
    await controller.addCardsAt(
      <String>['ref-1', 'ref-2', 'ref-3'],
      const Offset(120, 340),
    );

    expect(controller.cards.length, 3);

    // 전부 같은 자리에 겹쳐 있으면 몇 개가 들어왔는지 알 수 없습니다.
    final Set<Offset> positions = controller.cards
        .map((BoardCard c) => Offset(c.x, c.y))
        .toSet();
    expect(positions.length, 3, reason: '카드들이 서로 겹치면 안 됩니다');
  });

  testWidgets('addCardsAt도 onSaved를 한 번 부른다', (WidgetTester tester) async {
    await controller.addCardsAt(<String>['ref-1', 'ref-2'], const Offset(0, 0));
    expect(savedCount, 1);
  });

  testWidgets('addCardsAt에 빈 목록을 주면 아무 일도 안 한다', (
    WidgetTester tester,
  ) async {
    await controller.addCardsAt(<String>[], const Offset(0, 0));

    expect(controller.cards, isEmpty);
    expect(savedCount, 0);
  });

  // ── 여기서부터는 되돌리기(Ctrl+Z, undo)입니다 ──
  //
  // 조작마다 "거꾸로 하는 법"을 따로 만들지 않고, 조작 직전 카드
  // 목록 전체를 스냅샷으로 찍어뒀다가 되돌립니다(board_interaction_
  // controller.dart의 _pushUndoSnapshot/_restoreSnapshot 설명 참고).
  // 그래서 여기서는 "이미 확인한 개별 조작이 맞는지"가 아니라
  // "그 조작을 되돌렸을 때 정말 원래대로 돌아가는지"만 봅니다.

  group('되돌리기(undo)', () {
    testWidgets('되돌릴 게 없으면 아무 일도 안 한다', (WidgetTester tester) async {
      await controller.undo();

      expect(controller.cards, isEmpty);
      expect(savedCount, 0);
    });

    testWidgets('카드 담기를 되돌리면 그 카드가 없어진다', (WidgetTester tester) async {
      await controller.addCards(<String>['ref-1']);
      expect(controller.cards.length, 1);

      await controller.undo();

      expect(controller.cards, isEmpty);
    });

    testWidgets('카드 내리기를 되돌리면 다시 나타난다', (WidgetTester tester) async {
      await controller.addCards(<String>['ref-1']);
      final BoardCard original = controller.cards.single;

      await controller.removeCard(original);
      expect(controller.cards, isEmpty);

      await controller.undo();

      expect(controller.cards.length, 1);
      final BoardCard restored = controller.cards.single;
      expect(restored.id, original.id);
      expect(restored.referenceId, 'ref-1');
      expect(restored.x, original.x);
      expect(restored.y, original.y);
    });

    testWidgets('카드 옮기기를 되돌리면 원래 자리로 돌아간다', (
      WidgetTester tester,
    ) async {
      await controller.addCards(<String>['ref-1']);
      final BoardCard original = controller.cards.single;

      controller.onDragStart(original);
      controller.onDragUpdate(original, const Offset(120, 60));
      await controller.onDragEnd(controller.cards.single);

      final BoardCard moved = controller.cards.single;
      expect(moved.x, isNot(original.x), reason: '옮겨졌는지부터 확인합니다');

      await controller.undo();

      final BoardCard back = controller.cards.single;
      expect(back.x, original.x);
      expect(back.y, original.y);
    });

    testWidgets('크기 조절을 되돌리면 원래 크기로 돌아간다', (WidgetTester tester) async {
      await controller.addCards(<String>['ref-1']);
      final BoardCard original = controller.cards.single;
      expect(original.height, isNull, reason: '처음엔 그림 비율대로라 비어 있습니다');

      controller.onResizeStart(
        original,
        const Size(300, 225),
        BoardResizeCorner.bottomRight,
      );
      controller.onResizeUpdate(original, const Offset(60, 0));
      await controller.onResizeEnd(controller.cards.single);

      final BoardCard resized = controller.cards.single;
      expect(resized.width, isNot(original.width), reason: '커졌는지부터 확인합니다');

      await controller.undo();

      final BoardCard back = controller.cards.single;
      expect(back.width, original.width);
      expect(back.height, isNull);
    });

    testWidgets('여러 단계를 순서대로 되돌릴 수 있다', (WidgetTester tester) async {
      await controller.addCards(<String>['ref-1']);
      await controller.addCards(<String>['ref-2']);
      expect(controller.cards.length, 2);

      // 한 번 되돌리면 가장 최근 것(ref-2)만 사라집니다.
      await controller.undo();
      expect(controller.cards.length, 1);
      expect(controller.cards.single.referenceId, 'ref-1');

      // 한 번 더 되돌리면 그다음 것(ref-1)도 사라집니다.
      await controller.undo();
      expect(controller.cards, isEmpty);
    });

    testWidgets('정렬을 되돌리면 원래 자리로 돌아간다', (WidgetTester tester) async {
      await controller.addCards(<String>['ref-1', 'ref-2']);
      final BoardCard a = controller.cards[0];
      final BoardCard b = controller.cards[1];

      controller.onCardPressed(a, shiftHeld: false);
      controller.onCardPressed(b, shiftHeld: true);

      await controller.alignSelected(BoardAlignMode.left);

      final BoardCard alignedB = controller.cards.firstWhere(
        (BoardCard c) => c.id == b.id,
      );
      expect(alignedB.x, a.x, reason: '왼쪽 정렬이 실제로 됐는지부터 확인합니다');

      await controller.undo();

      final BoardCard back = controller.cards.firstWhere(
        (BoardCard c) => c.id == b.id,
      );
      expect(back.x, b.x);
    });

    testWidgets('되돌리기도 onSaved를 부른다', (WidgetTester tester) async {
      await controller.addCards(<String>['ref-1']);
      savedCount = 0;

      await controller.undo();

      expect(savedCount, 1, reason: '상대 창(팝업)도 되돌린 결과를 알아야 합니다');
    });
  });
}
