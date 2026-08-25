// 한글 조사 붙이기가 제대로 되는지 확인하는 테스트입니다.
//
// 조사가 틀리면 "폴더을 지웁니다"처럼 어색한 문구가 사용자에게 그대로 보입니다.
// 지금 쓰는 분류 이름은 넷 다 받침이 없지만, 나중에 받침 있는 이름
// (예: "앨범")이 추가돼도 자동으로 맞도록 만들어뒀습니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/utils/korean_particle.dart';

void main() {
  group('목적격 조사 (을/를)', () {
    test('받침이 없으면 "를"', () {
      expect(withObjectParticle('폴더'), '폴더를');
      expect(withObjectParticle('카테고리'), '카테고리를');
      expect(withObjectParticle('태그'), '태그를');
      expect(withObjectParticle('프로젝트'), '프로젝트를');
    });

    test('받침이 있으면 "을"', () {
      expect(withObjectParticle('앨범'), '앨범을');
      expect(withObjectParticle('작업'), '작업을');
    });
  });

  group('주격 조사 (이/가)', () {
    test('받침이 없으면 "가"', () {
      expect(withSubjectParticle('폴더'), '폴더가');
      expect(withSubjectParticle('태그'), '태그가');
    });

    test('받침이 있으면 "이"', () {
      expect(withSubjectParticle('앨범'), '앨범이');
    });
  });

  group('보조사 (은/는)', () {
    test('받침이 없으면 "는"', () {
      expect(withTopicParticle('폴더'), '폴더는');
    });

    test('받침이 있으면 "은"', () {
      expect(withTopicParticle('앨범'), '앨범은');
    });
  });

  group('한글이 아닌 경우', () {
    test('영어는 받침 없음으로 본다', () {
      expect(withSubjectParticle('folder'), 'folder가');
    });

    test('빈 글자를 넣어도 오류가 나지 않는다', () {
      // 앱이 죽는 것보다 어색한 문구가 낫습니다.
      expect(withSubjectParticle(''), '가');
    });
  });
}
