// 레퍼런스를 무드보드로 끌어다 놓을 때, 드래그 데이터에 담을 문자열을
// 만들고 해석하는 순수 함수 모음입니다.
//
// ── 왜 접두사를 붙이나 ──
// 창 사이 드래그(메인 창 → 무드보드 팝업 창)는 super_drag_and_drop의
// 표준 텍스트 포맷(Formats.plainText)으로 전달됩니다. 이 포맷은 다른
// 어떤 텍스트 드래그(예: 브라우저에서 끌어온 글자)에도 쓰이는 범용
// 포맷이라, 접두사가 없으면 "이게 우리 레퍼런스 드래그인지"를 구분할
// 방법이 없습니다.
//
// ── 왜 여기 있나 ──
// 화면을 안 띄우고 유닛 테스트로 확인할 수 있는 순수 계산이라,
// board_viewport.dart(받는 쪽)와 reference_card.dart(보내는 쪽) 양쪽이
// 이 파일 하나를 가져다 씁니다. 접두사 문자열을 두 곳에 따로 적어두면
// 나중에 오타로 어긋날 수 있습니다.

/// 이 접두사로 시작하는 값만 "레퍼런스를 무드보드로 끌어다 놓은 것"입니다.
const String _referenceDragPrefix = 'refarchive-reference:';

/// 레퍼런스 id를 드래그 데이터로 보낼 문자열로 만듭니다.
String encodeReferenceDragPayload(String referenceId) {
  return '$_referenceDragPrefix$referenceId';
}

/// 드래그 데이터 문자열에서 레퍼런스 id를 꺼냅니다.
///
/// 접두사가 없거나(다른 곳에서 온 텍스트), id 부분이 비어 있으면
/// null을 돌려줍니다 — 이런 값은 조용히 무시하면 됩니다.
String? tryDecodeReferenceDragPayload(String? payload) {
  if (payload == null || !payload.startsWith(_referenceDragPrefix)) {
    return null;
  }

  final String id = payload.substring(_referenceDragPrefix.length);
  return id.isEmpty ? null : id;
}
