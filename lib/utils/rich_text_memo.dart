// 레퍼런스 메모(리치텍스트)를 저장용 문자열과 화면용 문서 사이에서
// 오가게 해주는 순수 함수 모음입니다.
//
// ── 왜 이 파일이 따로 있나 ──
// memo 칼럼에는 flutter_quill이 쓰는 Delta라는 JSON 형식이 들어갑니다.
// 이 파일이 없으면 "저장된 글자를 편집기가 읽을 수 있는 문서로 바꾸는 일"과
// "편집기 내용을 저장용 글자로 바꾸는 일"이 화면 코드 여기저기에 흩어집니다.
// 화면 없이도 맞는지 확인할 수 있는 순수한 셈이라 여기 모아뒀습니다.
// (test/utils/rich_text_memo_test.dart)
//
// ── 마이그레이션 전 순수 텍스트를 여기서도 한 번 더 방어하는 이유 ──
// 저장 구조 v4 마이그레이션이 있던 메모를 전부 Delta로 감싸주지만, 혹시
// 못 탄 값이 남아있어도(예: 아주 옛날에 손으로 만든 파일 등) 메모가
// 통째로 안 보이는 것보다는, 서식 없는 글자로라도 보이는 편이 낫습니다.

import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// 저장된 메모 문자열을 편집기가 쓸 수 있는 [Document]로 되돌립니다.
///
/// 비어있거나(null, 공백) 못 읽는 값(마이그레이션을 못 탄 순수 텍스트,
/// 깨진 JSON)이면 그 글자를 그대로 담은 문서를 대신 돌려줍니다 — 메모가
/// 통째로 사라지는 것보다 낫습니다.
Document documentFromMemo(String? memo) {
  final String? trimmed = memo?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return Document();
  }

  try {
    final dynamic decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return Document.fromJson(decoded);
    }
  } catch (_) {
    // 아래에서 순수 텍스트로 처리합니다.
  }

  return Document.fromDelta(Delta()..insert('$trimmed\n'));
}

/// 편집기의 [Document]를 저장용 Delta(JSON) 문자열로 바꿉니다.
String memoFromDocument(Document document) {
  return jsonEncode(document.toDelta().toJson());
}

/// 저장된 메모 문자열에서 서식을 뺀 순수 글자만 뽑아냅니다.
///
/// 목록 카드 미리보기(reference_card.dart)에 씁니다. 미리보기는 서식까지
/// 보여줄 자리가 아니라서, 글자만 있으면 됩니다.
String plainTextFromMemo(String? memo) {
  return documentFromMemo(memo).toPlainText().trim();
}
