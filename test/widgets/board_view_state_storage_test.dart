// 판마다 마지막으로 보던 확대·이동 상태를 저장하고 불러오는 함수를
// 확인하는 테스트입니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/widgets/board_view_state_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('저장된 것이 없으면 null이다', () async {
    expect(await loadBoardViewState('board-1'), isNull);
  });

  test('저장하면 다시 읽어도 그 값 그대로다', () async {
    await saveBoardViewState('board-1', 1.5, const Offset(120, -40));

    final BoardViewState? state = await loadBoardViewState('board-1');
    expect(state, isNotNull);
    expect(state!.scale, 1.5);
    expect(state.offset, const Offset(120, -40));
  });

  test('판마다 따로 저장된다', () async {
    await saveBoardViewState('board-1', 1.0, Offset.zero);
    await saveBoardViewState('board-2', 2.0, const Offset(10, 10));

    expect((await loadBoardViewState('board-1'))!.scale, 1.0);
    expect((await loadBoardViewState('board-2'))!.scale, 2.0);
  });

  test('지우면 다시 null이 된다', () async {
    await saveBoardViewState('board-1', 1.5, const Offset(120, -40));
    await clearBoardViewState('board-1');

    expect(await loadBoardViewState('board-1'), isNull);
  });

  test('지워도 다른 판의 값은 그대로다', () async {
    await saveBoardViewState('board-1', 1.5, const Offset(120, -40));
    await saveBoardViewState('board-2', 2.0, const Offset(10, 10));

    await clearBoardViewState('board-1');

    expect(await loadBoardViewState('board-1'), isNull);
    expect((await loadBoardViewState('board-2'))!.scale, 2.0);
  });
}
