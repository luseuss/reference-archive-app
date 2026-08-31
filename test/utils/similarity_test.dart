// 유사도 계산이 맞는지 확인하는 테스트입니다. 화면·DB 없이 통과할 수
// 있는 순수 함수라 위젯 없이 봅니다.
//
// 가중치는 기존 웹앱(PR #12)에서 검증된 값을 그대로 가져왔습니다:
// 태그 자카드 0.35 + 같은 카테고리 0.1 + 같은 폴더 0.1 + 겹치는 프로젝트
// 0.1 + pHash 해밍거리 0.35.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/utils/similarity.dart';

void main() {
  /// 테스트용 레퍼런스를 하나 만들어 돌려줍니다.
  ReferenceItem makeItem(
    String id, {
    DateTime? createdAt,
    List<String> tagIds = const <String>[],
    String? categoryId,
    String? folderId,
    List<String> projectIds = const <String>[],
    String? pHash,
  }) {
    final DateTime now = createdAt ?? DateTime.utc(2026, 1, 1);
    return ReferenceItem(
      id: id,
      type: ReferenceType.image,
      tagIds: tagIds,
      categoryId: categoryId,
      folderId: folderId,
      projectIds: projectIds,
      pHash: pHash,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('jaccard', () {
    test('둘 다 비었으면 0이다', () {
      expect(jaccard(<String>{}, <String>{}), 0);
    });

    test('완전히 같으면 1이다', () {
      expect(jaccard(<String>{'a', 'b'}, <String>{'a', 'b'}), 1);
    });

    test('절반 겹치면 교집합/합집합이다', () {
      // 교집합 1, 합집합 3 -> 1/3
      expect(jaccard(<String>{'a', 'b'}, <String>{'b', 'c'}), closeTo(1 / 3, 0.0001));
    });

    test('하나도 안 겹치면 0이다', () {
      expect(jaccard(<String>{'a'}, <String>{'b'}), 0);
    });
  });

  group('hammingDistance', () {
    test('완전히 같으면 0이다', () {
      expect(hammingDistance('1010', '1010'), 0);
    });

    test('다른 비트 수만큼 돌려준다', () {
      expect(hammingDistance('1010', '1111'), 2);
    });

    test('길이가 다르면 null이다', () {
      expect(hammingDistance('101', '1010'), isNull);
    });

    test('둘 중 하나가 null이면 null이다', () {
      expect(hammingDistance(null, '1010'), isNull);
      expect(hammingDistance('1010', null), isNull);
    });
  });

  group('similarityScore', () {
    test('자기 자신과는 0이다', () {
      final ReferenceItem item = makeItem('a', tagIds: <String>['x']);
      expect(similarityScore(item, item), 0);
    });

    test('태그만 겹치면 자카드 x 0.35다', () {
      final ReferenceItem a = makeItem('a', tagIds: <String>['x', 'y']);
      final ReferenceItem b = makeItem('b', tagIds: <String>['y', 'z']);
      // 자카드 = 1/3
      expect(similarityScore(a, b), closeTo((1 / 3) * 0.35, 0.0001));
    });

    test('같은 카테고리면 0.1이 더해진다', () {
      final ReferenceItem a = makeItem('a', categoryId: 'cat-1');
      final ReferenceItem b = makeItem('b', categoryId: 'cat-1');
      expect(similarityScore(a, b), closeTo(0.1, 0.0001));
    });

    test('같은 폴더면 0.1이 더해진다', () {
      final ReferenceItem a = makeItem('a', folderId: 'folder-1');
      final ReferenceItem b = makeItem('b', folderId: 'folder-1');
      expect(similarityScore(a, b), closeTo(0.1, 0.0001));
    });

    test('겹치는 프로젝트가 하나라도 있으면 0.1이 더해진다', () {
      final ReferenceItem a = makeItem('a', projectIds: <String>['p1', 'p2']);
      final ReferenceItem b = makeItem('b', projectIds: <String>['p2', 'p3']);
      expect(similarityScore(a, b), closeTo(0.1, 0.0001));
    });

    test('겹치는 프로젝트가 없으면 안 더해진다', () {
      final ReferenceItem a = makeItem('a', projectIds: <String>['p1']);
      final ReferenceItem b = makeItem('b', projectIds: <String>['p2']);
      expect(similarityScore(a, b), 0);
    });

    test('pHash가 둘 다 있으면 (1 - 해밍거리/길이) x 0.35다', () {
      // 64비트 중 4비트만 다름 -> 1 - 4/64 = 0.9375
      final String hashA = '1' * 64;
      final String hashB = '${'1' * 60}0000';
      final ReferenceItem a = makeItem('a', pHash: hashA);
      final ReferenceItem b = makeItem('b', pHash: hashB);
      expect(similarityScore(a, b), closeTo(0.9375 * 0.35, 0.0001));
    });

    test('pHash가 하나라도 없으면 그 항목은 안 더해진다', () {
      final ReferenceItem a = makeItem('a', pHash: '1' * 64);
      final ReferenceItem b = makeItem('b');
      expect(similarityScore(a, b), 0);
    });

    test('여러 항목이 동시에 겹치면 전부 더해진다', () {
      final ReferenceItem a = makeItem(
        'a',
        tagIds: <String>['x'],
        categoryId: 'cat-1',
        folderId: 'folder-1',
      );
      final ReferenceItem b = makeItem(
        'b',
        tagIds: <String>['x'],
        categoryId: 'cat-1',
        folderId: 'folder-1',
      );
      // 태그 자카드(완전히 같음) 1 x 0.35 + 카테고리 0.1 + 폴더 0.1
      expect(similarityScore(a, b), closeTo(0.35 + 0.1 + 0.1, 0.0001));
    });
  });

  group('similarItems', () {
    test('점수가 높은 순으로 정렬해서 돌려준다', () {
      final ReferenceItem target = makeItem('target', tagIds: <String>['x', 'y']);
      final ReferenceItem high = makeItem('high', tagIds: <String>['x', 'y']); // 자카드 1
      final ReferenceItem low = makeItem('low', tagIds: <String>['x']); // 자카드 1/2
      final ReferenceItem none = makeItem('none', tagIds: <String>['z']); // 자카드 0

      final List<ReferenceItem> result = similarItems(
        target,
        <ReferenceItem>[low, none, high],
        limit: 10,
      );

      expect(result.map((ReferenceItem i) => i.id).toList(), <String>['high', 'low']);
    });

    test('자기 자신은 결과에서 빠진다', () {
      final ReferenceItem target = makeItem('target', tagIds: <String>['x']);
      final List<ReferenceItem> result = similarItems(
        target,
        <ReferenceItem>[target],
        limit: 10,
      );
      expect(result, isEmpty);
    });

    test('limit만큼만 돌려준다', () {
      final ReferenceItem target = makeItem('target', tagIds: <String>['x']);
      final List<ReferenceItem> list = List<ReferenceItem>.generate(
        5,
        (int i) => makeItem('item-$i', tagIds: <String>['x']),
      );
      final List<ReferenceItem> result = similarItems(target, list, limit: 2);
      expect(result.length, 2);
    });

    test('minScore 이하는 제외한다', () {
      final ReferenceItem target = makeItem('target', tagIds: <String>['x', 'y']);
      final ReferenceItem low = makeItem('low', tagIds: <String>['x']); // 자카드 1/2 -> 0.175
      final List<ReferenceItem> result = similarItems(
        target,
        <ReferenceItem>[low],
        limit: 10,
        minScore: 0.2,
      );
      expect(result, isEmpty);
    });
  });

  group('sortBySimilarity', () {
    test('가장 최근에 추가된 항목이 맨 앞에 고정된다', () {
      final ReferenceItem old = makeItem(
        'old',
        createdAt: DateTime.utc(2026, 1, 1),
        tagIds: <String>['x'],
      );
      final ReferenceItem newest = makeItem(
        'newest',
        createdAt: DateTime.utc(2026, 3, 1),
        tagIds: <String>['z'], // 아무와도 안 겹침
      );

      final List<ReferenceItem> result = sortBySimilarity(<ReferenceItem>[old, newest]);

      expect(result.first.id, 'newest');
    });

    test('나머지는 기준 항목과의 유사도 내림차순이다', () {
      final ReferenceItem anchor = makeItem(
        'anchor',
        createdAt: DateTime.utc(2026, 3, 1),
        tagIds: <String>['x', 'y'],
      );
      final ReferenceItem high = makeItem(
        'high',
        createdAt: DateTime.utc(2026, 1, 1),
        tagIds: <String>['x', 'y'], // 자카드 1
      );
      final ReferenceItem low = makeItem(
        'low',
        createdAt: DateTime.utc(2026, 1, 2),
        tagIds: <String>['x'], // 자카드 1/2
      );

      final List<ReferenceItem> result = sortBySimilarity(<ReferenceItem>[low, anchor, high]);

      expect(
        result.map((ReferenceItem i) => i.id).toList(),
        <String>['anchor', 'high', 'low'],
      );
    });

    test('빈 목록이면 빈 목록을 돌려준다', () {
      expect(sortBySimilarity(<ReferenceItem>[]), isEmpty);
    });

    test('한 장뿐이면 그대로 돌려준다', () {
      final ReferenceItem only = makeItem('only');
      final List<ReferenceItem> result = sortBySimilarity(<ReferenceItem>[only]);
      expect(result.map((ReferenceItem i) => i.id).toList(), <String>['only']);
    });
  });
}
