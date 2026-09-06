// 무드보드 판마다 마지막으로 보던 확대·이동 상태를 저장하고 불러옵니다.
//
// ── 왜 필요한가 ──
// 지금까지는 판을 나갔다 오면 늘 "카드 전부 보기"로 되돌아갔습니다.
// 같은 판을 자주 오가며 작업할 때, 매번 원하는 자리를 다시 확대해
// 찾아가야 해서 불편했습니다.
//
// ── 왜 데이터베이스가 아니라 SharedPreferences인가 ──
// 확대 배율·화면 위치는 "이 판에 무엇이 있는가"가 아니라 "지금 화면을
// 어떻게 보고 있는가"라는 화면 상태에 가깝습니다.
// board_window_controller.dart의 "항상 위" 기본값과 같은 성격입니다 —
// 저장 구조(마이그레이션)를 새로 만들 만큼 무게 있는 데이터가 아니라고
// 보고 여기 뒀습니다.
//
// ── board_viewport.dart는 이 파일을 모릅니다 ──
// BoardViewport(위젯)는 "카드가 뭔지 모른다"는 원칙과 같은 이유로
// "판이 뭔지도 모릅니다" — 화면 좌표·배율만 다루는 범용 위젯입니다.
// 판 번호(boardId)로 저장하고 불러오는 일은 board_screen.dart가
// 이 파일의 함수를 직접 불러서 하고, BoardViewport에는 값과 콜백으로만
// 전달합니다.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 저장할 때 쓰는 이름표 접두사입니다. 뒤에 판 번호(boardId)를 붙여
/// 판마다 따로 저장합니다.
const String _scaleKeyPrefix = 'boardViewScale_';
const String _offsetDxKeyPrefix = 'boardViewOffsetDx_';
const String _offsetDyKeyPrefix = 'boardViewOffsetDy_';

/// 저장된 판 보기 상태 하나입니다.
class BoardViewState {
  const BoardViewState({required this.scale, required this.offset});

  /// 확대 배율입니다.
  final double scale;

  /// 화면 이동값입니다(화면 좌표. board_viewport.dart의 _offset과 같은 뜻).
  final Offset offset;
}

/// [boardId]에 저장해둔 보기 상태를 읽습니다.
///
/// 저장된 적이 없으면(한 번도 안 저장했거나 "카드 전부 보기"로 지운
/// 뒤라면) null입니다 — 그러면 board_viewport.dart가 늘 하던 대로
/// "카드 전부 보기"로 시작합니다.
Future<BoardViewState?> loadBoardViewState(String boardId) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final double? scale = prefs.getDouble('$_scaleKeyPrefix$boardId');
  final double? offsetDx = prefs.getDouble('$_offsetDxKeyPrefix$boardId');
  final double? offsetDy = prefs.getDouble('$_offsetDyKeyPrefix$boardId');

  // 셋 중 하나라도 없으면(저장한 적이 없거나 값이 어긋나 있으면)
  // 저장 안 된 것으로 봅니다. 부분적으로만 읽으면 배율은 옛날 값인데
  // 자리는 기본값인 식으로 어긋난 화면이 나올 수 있습니다.
  if (scale == null || offsetDx == null || offsetDy == null) {
    return null;
  }

  return BoardViewState(scale: scale, offset: Offset(offsetDx, offsetDy));
}

/// [boardId]의 보기 상태를 저장합니다.
///
/// 판을 옮기거나(팬) 확대·축소를 마쳤을 때만 부릅니다 — 끄는 도중
/// 매 프레임 부르면 저장 요청이 쉴 새 없이 나갑니다
/// (board_interaction_controller.dart의 onSaved와 같은 "끝났을 때만"
/// 원칙입니다).
Future<void> saveBoardViewState(
  String boardId,
  double scale,
  Offset offset,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('$_scaleKeyPrefix$boardId', scale);
  await prefs.setDouble('$_offsetDxKeyPrefix$boardId', offset.dx);
  await prefs.setDouble('$_offsetDyKeyPrefix$boardId', offset.dy);
}

/// [boardId]의 저장된 보기 상태를 지웁니다.
///
/// "카드 전부 보기"(⛶)를 누르면 부릅니다 — 사용자가 직접 기본값으로
/// 되돌렸으니, 다음에 이 판을 열 때도 그 상태(전부 보기)에서 시작해야
/// 합니다.
Future<void> clearBoardViewState(String boardId) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove('$_scaleKeyPrefix$boardId');
  await prefs.remove('$_offsetDxKeyPrefix$boardId');
  await prefs.remove('$_offsetDyKeyPrefix$boardId');
}
