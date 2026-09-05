// reference_drag_payload.dart의 인코딩/디코딩이 서로 짝이 맞는지,
// 우리 것이 아닌 값은 조용히 걸러내는지 확인합니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/utils/reference_drag_payload.dart';

void main() {
  test('레퍼런스 id를 감쌌다가 그대로 풀 수 있다', () {
    final String payload = encodeReferenceDragPayload('ref-123');
    expect(tryDecodeReferenceDragPayload(payload), 'ref-123');
  });

  test('접두사가 없는 값이면 null이다 (다른 곳에서 온 텍스트)', () {
    expect(tryDecodeReferenceDragPayload('그냥 아무 텍스트'), isNull);
  });

  test('null이 들어오면 null이다', () {
    expect(tryDecodeReferenceDragPayload(null), isNull);
  });

  test('접두사만 있고 id가 비어 있으면 null이다', () {
    expect(tryDecodeReferenceDragPayload('refarchive-reference:'), isNull);
  });
}
