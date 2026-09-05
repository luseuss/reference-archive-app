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
}
