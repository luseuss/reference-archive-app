// categorizeFontFamily(system_fonts.dart)가 글꼴 이름을 다섯 구역으로
// 잘 가리는지 확인합니다. 순수 함수라 레지스트리·파일 접근 없이
// 문자열만으로 테스트합니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/services/system_fonts.dart';

void main() {
  group('categorizeFontFamily', () {
    test('한글이 들어간 이름은 한국어로 가립니다', () {
      expect(
        categorizeFontFamily('케리스 케듀체 OTF B'),
        FontScriptCategory.korean,
      );
      expect(categorizeFontFamily('나눔고딕'), FontScriptCategory.korean);
    });

    test('로마자만 있는 이름은 영어로 가립니다', () {
      expect(categorizeFontFamily('Pretendard'), FontScriptCategory.english);
      expect(categorizeFontFamily('Arial'), FontScriptCategory.english);
    });

    test('히라가나·가타카나가 들어간 이름은 일본어로 가립니다', () {
      expect(categorizeFontFamily('メイリオ'), FontScriptCategory.japanese);
      // 한자와 가나가 섞여 있어도 가나가 있으면 일본어입니다.
      expect(categorizeFontFamily('游ゴシック'), FontScriptCategory.japanese);
    });

    test('한자만 있는 이름은 중국어로 가립니다', () {
      expect(categorizeFontFamily('微软雅黑'), FontScriptCategory.chinese);
    });

    test('기호 글꼴 이름은 특수문자로 가립니다', () {
      expect(categorizeFontFamily('Wingdings'), FontScriptCategory.symbol);
      expect(
        categorizeFontFamily('Segoe MDL2 Assets'),
        FontScriptCategory.symbol,
      );
    });
  });
}
