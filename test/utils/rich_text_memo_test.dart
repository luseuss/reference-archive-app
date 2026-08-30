// Delta(JSON) 문자열과 순수 텍스트를 오가는 계산이 맞는지 확인하는
// 테스트입니다. 화면 없이 통과할 수 있는 순수 함수라 위젯 없이 봅니다.

import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/utils/rich_text_memo.dart';

void main() {
  group('documentFromMemo', () {
    test('null이면 빈 문서를 돌려준다', () {
      final Document doc = documentFromMemo(null);
      expect(doc.toPlainText().trim(), '');
    });

    test('빈 글자면 빈 문서를 돌려준다', () {
      final Document doc = documentFromMemo('   ');
      expect(doc.toPlainText().trim(), '');
    });

    test('유효한 Delta JSON이면 그대로 읽는다', () {
      final String delta = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': '굵은 글자',
          'attributes': <String, dynamic>{'bold': true},
        },
        <String, dynamic>{'insert': '\n'},
      ]);

      final Document doc = documentFromMemo(delta);

      expect(doc.toPlainText().trim(), '굵은 글자');
    });

    test('마이그레이션 전 순수 텍스트도 그대로 문서로 읽는다', () {
      // v3까지는 memo가 그냥 글자였습니다. 마이그레이션(v4)이 대부분
      // 처리하지만, 혹시 못 탄 값이 남아있어도 여기서 한 번 더 방어합니다.
      final Document doc = documentFromMemo('색감 참고');

      expect(doc.toPlainText().trim(), '색감 참고');
    });

    test('깨진 JSON이어도 그 글자를 그대로 문서로 읽는다', () {
      final Document doc = documentFromMemo('{이건 JSON이 아님');

      expect(doc.toPlainText().trim(), '{이건 JSON이 아님');
    });
  });

  group('memoFromDocument', () {
    test('문서를 저장용 Delta 문자열로 바꾼다', () {
      final Document doc = Document.fromDelta(Delta()..insert('안녕\n'));

      final String saved = memoFromDocument(doc);

      // 저장한 뒤 다시 읽으면 같은 글자가 나와야 합니다(원본 왕복).
      expect(documentFromMemo(saved).toPlainText().trim(), '안녕');
    });
  });

  group('plainTextFromMemo', () {
    test('null이면 빈 글자를 돌려준다', () {
      expect(plainTextFromMemo(null), '');
    });

    test('서식이 있어도 글자만 뽑는다', () {
      final String delta = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': '색감',
          'attributes': <String, dynamic>{'color': '#ff0000'},
        },
        <String, dynamic>{'insert': ' 참고\n'},
      ]);

      expect(plainTextFromMemo(delta), '색감 참고');
    });

    test('마이그레이션 전 순수 텍스트도 그대로 돌려준다', () {
      expect(plainTextFromMemo('색감 참고'), '색감 참고');
    });
  });
}
