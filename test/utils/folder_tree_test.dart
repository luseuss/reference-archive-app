// lib/utils/folder_tree.dart의 순수 함수들을 확인하는 테스트입니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/utils/folder_tree.dart';

void main() {
  /// 테스트용 폴더를 하나 만듭니다.
  TaxonomyItem folder(String id, String name, {String? parentId}) {
    final DateTime now = DateTime.utc(2026, 1, 1);
    return TaxonomyItem(
      id: id,
      kind: TaxonomyKind.folder,
      name: name,
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('parentIdMap', () {
    test('id별로 parentId 표를 만든다', () {
      final List<TaxonomyItem> all = <TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
      ];

      expect(parentIdMap(all), <String, String?>{'a': null, 'b': 'a'});
    });
  });

  group('collectFolderAndDescendantIds', () {
    test('자기 자신만 있으면 자기 자신만 돌려준다', () {
      final Map<String, String?> map = parentIdMap(<TaxonomyItem>[folder('a', '인물')]);

      expect(collectFolderAndDescendantIds('a', map), <String>{'a'});
    });

    test('자식과 손자까지 모은다', () {
      final Map<String, String?> map = parentIdMap(<TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
        folder('c', '포즈', parentId: 'a'),
        folder('d', '옆얼굴', parentId: 'b'),
        folder('e', '풍경'), // 무관한 최상위 폴더
      ]);

      expect(
        collectFolderAndDescendantIds('a', map),
        <String>{'a', 'b', 'c', 'd'},
      );
    });

    test('형제의 하위는 포함하지 않는다', () {
      final Map<String, String?> map = parentIdMap(<TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
        folder('c', '포즈', parentId: 'a'),
        folder('d', '옆얼굴', parentId: 'b'),
      ]);

      expect(collectFolderAndDescendantIds('c', map), <String>{'c'});
    });
  });

  group('buildFolderTree', () {
    test('빈 목록이면 빈 트리를 돌려준다', () {
      expect(buildFolderTree(<TaxonomyItem>[]), isEmpty);
    });

    test('최상위 폴더끼리는 이름 가나다순이다', () {
      final List<TaxonomyItem> all = <TaxonomyItem>[
        folder('a', '풍경'),
        folder('b', '건축'),
        folder('c', '인물'),
      ];

      final List<FolderTreeEntry> tree = buildFolderTree(all);

      expect(
        tree.map((FolderTreeEntry e) => e.folder.name).toList(),
        <String>['건축', '인물', '풍경'],
      );
      expect(tree.every((FolderTreeEntry e) => e.depth == 0), isTrue);
    });

    test('부모 바로 다음에 자식이 오고 깊이가 늘어난다', () {
      final List<TaxonomyItem> all = <TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
        folder('c', '포즈', parentId: 'a'),
        folder('d', '옆얼굴', parentId: 'b'),
        folder('e', '풍경'),
      ];

      final List<FolderTreeEntry> tree = buildFolderTree(all);

      expect(
        tree.map((FolderTreeEntry e) => '${e.folder.name}:${e.depth}').toList(),
        <String>['인물:0', '얼굴:1', '옆얼굴:2', '포즈:1', '풍경:0'],
      );
    });

    test('excludeIds에 넣은 폴더와 그 하위는 빠진다', () {
      final List<TaxonomyItem> all = <TaxonomyItem>[
        folder('a', '인물'),
        folder('b', '얼굴', parentId: 'a'),
        folder('c', '옆얼굴', parentId: 'b'),
        folder('d', '풍경'),
      ];

      final List<FolderTreeEntry> tree = buildFolderTree(
        all,
        excludeIds: <String>{'b', 'c'},
      );

      expect(
        tree.map((FolderTreeEntry e) => e.folder.name).toList(),
        <String>['인물', '풍경'],
      );
    });
  });
}
