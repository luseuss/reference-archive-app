// 폴더의 부모-자식 관계를 계산하는 순수 함수 모음입니다.
//
// "순수 함수"로 뽑아둔 이유는 lib/utils/board_layout.dart와 같습니다 —
// 데이터베이스나 화면 없이, 폴더 목록만 넣으면 결과가 나와서 앱을 안
// 띄우고 테스트할 수 있습니다.
//
// 여기 있는 함수들은 전부 "폴더"(TaxonomyKind.folder)만 다룹니다. 카테고리·
// 태그·프로젝트는 parentId가 항상 null이라 애초에 트리를 이룰 일이 없습니다.

import '../models/taxonomy_item.dart';

/// 폴더 하나와 트리에서의 깊이(최상위 = 0)를 함께 담는 값입니다.
class FolderTreeEntry {
  const FolderTreeEntry({required this.folder, required this.depth});

  /// 이 자리의 폴더입니다.
  final TaxonomyItem folder;

  /// 트리에서의 깊이입니다. 최상위 폴더는 0, 그 하위는 1, 그 하위는 2...
  final int depth;
}

/// [folders] 목록에서 (id → parentId) 표를 만듭니다.
///
/// [collectFolderAndDescendantIds]에 넘길 때 씁니다. 저장소 쪽처럼
/// TaxonomyItem 전체를 만들기보다 (id, parentId)만 가벼운 쿼리로 읽어온
/// 곳에서도 같은 함수를 쓸 수 있도록, 그 계산 결과와 이 표는 형태가
/// 같습니다.
Map<String, String?> parentIdMap(List<TaxonomyItem> folders) {
  return <String, String?>{
    for (final TaxonomyItem folder in folders) folder.id: folder.parentId,
  };
}

/// [rootId]와 그 아래 모든 하위 폴더(자식, 손자, ...)의 id를 모아 돌려줍니다.
/// [rootId] 자신도 결과에 포함됩니다.
///
/// [parentById]는 (폴더 id → 그 폴더의 상위 폴더 id) 표입니다. 폴더를
/// 지울 때(하위까지 함께 지우기), 폴더를 옮길 때(순환 방지) 둘 다
/// "이 폴더 아래로는 못 간다/지운다"는 집합이 필요해서 하나로 묶었습니다.
Set<String> collectFolderAndDescendantIds(
  String rootId,
  Map<String, String?> parentById,
) {
  final Map<String, List<String>> childrenOf = <String, List<String>>{};
  parentById.forEach((String id, String? parentId) {
    if (parentId != null) {
      childrenOf.putIfAbsent(parentId, () => <String>[]).add(id);
    }
  });

  final Set<String> collected = <String>{rootId};
  final List<String> toVisit = <String>[rootId];

  while (toVisit.isNotEmpty) {
    final String currentId = toVisit.removeLast();
    for (final String childId in childrenOf[currentId] ?? const <String>[]) {
      // add()가 false를 돌려주면 이미 방문한 것입니다. 데이터가 깨져서
      // parentId가 순환을 이루더라도(정상 경로로는 안 생기지만) 무한
      // 루프에 빠지지 않도록 막아줍니다.
      if (collected.add(childId)) {
        toVisit.add(childId);
      }
    }
  }

  return collected;
}

/// 폴더 목록을 트리 순서로 펼칩니다.
///
/// 부모 바로 다음에 그 자식들이 오고, 형제끼리는 이름 가나다순입니다.
/// [excludeIds]에 들어있는 폴더는 결과에서 빠집니다 — **그 하위도 자동으로
/// 함께 빠집니다**(parentId 체인이 끊어져서 더 이상 안 걸리기 때문입니다).
/// 그래서 이 인자에는 항상 [collectFolderAndDescendantIds]로 구한 "자기
/// 자신+하위 전체" 집합을 넘기세요 — 하위 일부만 빠진 어중간한 집합을
/// 넘기면 그 하위가 트리에서 통째로 안 보이게 됩니다(부모가 없어져서).
///
/// 예: 폴더를 옮길 때 "자기 자신과 자기 하위"를 상위 폴더 후보에서
/// 빼는 용도로 씁니다.
List<FolderTreeEntry> buildFolderTree(
  List<TaxonomyItem> allFolders, {
  Set<String> excludeIds = const <String>{},
}) {
  final List<TaxonomyItem> eligible = allFolders
      .where((TaxonomyItem folder) => !excludeIds.contains(folder.id))
      .toList();

  final Map<String?, List<TaxonomyItem>> childrenByParent =
      <String?, List<TaxonomyItem>>{};
  for (final TaxonomyItem folder in eligible) {
    childrenByParent
        .putIfAbsent(folder.parentId, () => <TaxonomyItem>[])
        .add(folder);
  }
  for (final List<TaxonomyItem> siblings in childrenByParent.values) {
    siblings.sort((TaxonomyItem a, TaxonomyItem b) => a.name.compareTo(b.name));
  }

  final List<FolderTreeEntry> result = <FolderTreeEntry>[];

  void addChildrenOf(String? parentId, int depth) {
    for (final TaxonomyItem folder
        in childrenByParent[parentId] ?? const <TaxonomyItem>[]) {
      result.add(FolderTreeEntry(folder: folder, depth: depth));
      addChildrenOf(folder.id, depth + 1);
    }
  }

  addChildrenOf(null, 0);
  return result;
}
