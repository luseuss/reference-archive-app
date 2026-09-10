// TaxonomyRepository 약속을 "내 컴퓨터의 데이터베이스"로 실제로 지키는 구현입니다.
//
// drift 관련 코드는 이 파일 안에만 있습니다.
// 자세한 이유는 local_reference_repository.dart 맨 위 설명을 보세요.

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../models/enums.dart';
import '../models/taxonomy_item.dart';
import '../utils/folder_tree.dart';
import 'taxonomy_repository.dart';

/// 분류 항목을 이 기기의 데이터베이스에 저장하는 구현체입니다.
class LocalTaxonomyRepository implements TaxonomyRepository {
  LocalTaxonomyRepository(this._db);

  final AppDatabase _db;

  /// 해당 종류의 살아있는 항목을 이름순으로 전부 가져옵니다.
  @override
  Future<List<TaxonomyItem>> getAll(TaxonomyKind kind) async {
    final SimpleSelectStatement<$TaxonomyItemsTable, TaxonomyItemRow> query =
        _db.select(_db.taxonomyItems)
          ..where(($TaxonomyItemsTable t) =>
              t.kind.equals(kind.storedName) & t.deletedAt.isNull())
          ..orderBy(<OrderClauseGenerator<$TaxonomyItemsTable>>[
            ($TaxonomyItemsTable t) => OrderingTerm(expression: t.name),
          ]);

    final List<TaxonomyItemRow> rows = await query.get();
    return rows.map(_toModel).whereType<TaxonomyItem>().toList();
  }

  /// id로 항목 하나를 찾습니다. 없거나 지워졌으면 null입니다.
  @override
  Future<TaxonomyItem?> getById(String id) async {
    final TaxonomyItemRow? row = await (_db.select(_db.taxonomyItems)
          ..where(($TaxonomyItemsTable t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();

    if (row == null) {
      return null;
    }
    return _toModel(row);
  }

  /// 항목을 저장합니다. 없으면 새로 만들고, 있으면 덮어씁니다.
  @override
  Future<void> save(TaxonomyItem item) async {
    // updatedAt은 부르는 쪽에 맡기지 않고 여기서 무조건 갱신합니다.
    // (이유는 local_reference_repository.dart의 save 설명 참고)
    final DateTime now = DateTime.now().toUtc();

    await _db.into(_db.taxonomyItems).insertOnConflictUpdate(
          TaxonomyItemsCompanion.insert(
            id: item.id,
            kind: item.kind.storedName,
            name: item.name,
            // Value로 명시적으로 감싸야 null도 그대로 저장됩니다. 그냥
            // item.parentId만 넘기면(감싸지 않으면) "이 칸은 안 건드린다"는
            // 뜻이 되어, 최상위로 옮긴 것(null로 바꾼 것)이 저장되지 않습니다.
            // (local_board_repository.dart의 folderId와 같은 이유입니다)
            parentId: Value<String?>(item.parentId),
            createdAt: item.createdAt,
            updatedAt: now,
          ),
        );
  }

  /// 항목을 지웁니다(소프트 삭제). 이 항목을 쓰던 레퍼런스도 함께 정리합니다.
  ///
  /// 폴더라면 하위 폴더(자식, 손자, ...)까지 전부 함께 지웁니다.
  @override
  Future<void> delete(String id) async {
    final DateTime now = DateTime.now().toUtc();

    // 항목 본체와 그 항목을 쓰던 곳들을 함께 정리합니다.
    // 중간에 실패해서 "이미 지운 폴더에 들어있는 레퍼런스"가 남으면 그 레퍼런스가
    // 폴더 목록 어디에도 안 보이게 되므로, transaction으로 묶습니다.
    await _db.transaction(() async {
      final Set<String> idsToDelete = await _folderAndDescendantIds(id);

      await (_db.update(_db.taxonomyItems)
            ..where(($TaxonomyItemsTable t) => t.id.isIn(idsToDelete)))
          .write(TaxonomyItemsCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ));

      // 태그·프로젝트로 쓰이던 연결을 끊습니다.
      await (_db.update(_db.referenceTaxonomyLinks)
            ..where(($ReferenceTaxonomyLinksTable t) =>
                t.taxonomyItemId.isIn(idsToDelete) & t.deletedAt.isNull()))
          .write(ReferenceTaxonomyLinksCompanion(deletedAt: Value<DateTime?>(now)));

      // 폴더로 쓰이던 레퍼런스는 폴더 없음 상태로 되돌립니다. (지운 폴더나
      // 그 하위 폴더 중 어디에 있었든 전부 대상입니다)
      await (_db.update(_db.references)
            ..where(($ReferencesTable t) => t.folderId.isIn(idsToDelete)))
          .write(ReferencesCompanion(
        folderId: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ));

      // 카테고리로 쓰이던 레퍼런스도 마찬가지입니다.
      await (_db.update(_db.references)
            ..where(($ReferencesTable t) => t.categoryId.isIn(idsToDelete)))
          .write(ReferencesCompanion(
        categoryId: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ));
    });
  }

  /// [id]와(폴더라면) 그 하위 폴더 전부의 id를 모아 돌려줍니다.
  /// 폴더가 아니면(하위 개념이 없으면) [id] 하나만 담긴 집합입니다.
  Future<Set<String>> _folderAndDescendantIds(String id) async {
    final List<TaxonomyItem> allFolders = await getAll(TaxonomyKind.folder);
    final bool isFolder = allFolders.any((TaxonomyItem f) => f.id == id);
    if (!isFolder) {
      return <String>{id};
    }
    return collectFolderAndDescendantIds(id, parentIdMap(allFolders));
  }

  /// 폴더의 상위 폴더를 바꿉니다. [newParentId]가 null이면 최상위로 옮깁니다.
  @override
  Future<void> moveFolder(String id, String? newParentId) async {
    final DateTime now = DateTime.now().toUtc();

    if (newParentId != null) {
      final List<TaxonomyItem> allFolders = await getAll(TaxonomyKind.folder);
      final Set<String> forbidden =
          collectFolderAndDescendantIds(id, parentIdMap(allFolders));
      if (forbidden.contains(newParentId)) {
        throw const FolderMoveCycleException();
      }
    }

    await (_db.update(_db.taxonomyItems)
          ..where(($TaxonomyItemsTable t) => t.id.equals(id)))
        .write(TaxonomyItemsCompanion(
      parentId: Value<String?>(newParentId),
      updatedAt: Value<DateTime>(now),
    ));
  }

  /// 같은 종류 안에, 폴더라면 같은 상위 폴더 밑에 같은 이름이 이미 있는지
  /// 확인합니다.
  @override
  Future<bool> existsWithName(
    TaxonomyKind kind,
    String name, {
    String? excludeId,
    String? parentId,
  }) async {
    // 사용자가 "인물"과 "인물 "(뒤에 공백)을 다른 것으로 만들 이유는 없습니다.
    // 앞뒤 공백을 떼고, 대소문자도 구분하지 않고 비교합니다.
    final String normalized = name.trim().toLowerCase();

    final SimpleSelectStatement<$TaxonomyItemsTable, TaxonomyItemRow> query =
        _db.select(_db.taxonomyItems)
          ..where(($TaxonomyItemsTable t) =>
              t.kind.equals(kind.storedName) & t.deletedAt.isNull());

    final List<TaxonomyItemRow> rows = await query.get();

    for (final TaxonomyItemRow row in rows) {
      if (excludeId != null && row.id == excludeId) {
        continue;
      }
      // 같은 상위 폴더 밑에 있는 것만 비교합니다. 카테고리·태그·프로젝트는
      // parentId가 늘 null이라(호출하는 쪽도 안 넘기므로) 지금처럼 전체
      // 기준 그대로입니다.
      if (row.parentId != parentId) {
        continue;
      }
      if (row.name.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }

  /// 이 분류 항목을 쓰고 있는 살아있는 레퍼런스가 몇 개인지 세어 돌려줍니다.
  ///
  /// 폴더·카테고리로 쓰이는 경우와 태그·프로젝트로 쓰이는 경우를 모두 셉니다.
  /// 종류를 따로 확인하지 않아도 되는 이유: id 자체가 세상에 하나뿐이라
  /// 어차피 한쪽에서만 걸립니다.
  @override
  Future<int> countReferencesUsing(String id) async {
    // 폴더·카테고리로 쓰이는 레퍼런스
    final int directCount = await _db
        .references
        .count(
          where: ($ReferencesTable t) =>
              (t.folderId.equals(id) |
                  t.categoryId.equals(id)) &
              t.deletedAt.isNull(),
        )
        .getSingle();

    // 태그나 프로젝트로 붙어있는 레퍼런스
    //
    // 연결 표만 세면 안 됩니다. 레퍼런스가 지워졌어도 연결 줄은 남아 있어서,
    // "이미 지운 사진 3개가 이 태그를 쓴다"는 엉뚱한 안내가 나갑니다.
    // 그래서 살아있는 레퍼런스와 이어붙여(join) 확인합니다.
    final JoinedSelectStatement<HasResultSet, dynamic> linkQuery =
        _db.selectOnly(_db.referenceTaxonomyLinks).join(
      <Join<HasResultSet, dynamic>>[
        innerJoin(
          _db.references,
          _db.references.id.equalsExp(_db.referenceTaxonomyLinks.referenceId),
        ),
      ],
    );

    final Expression<int> linkCount =
        _db.referenceTaxonomyLinks.referenceId.count();
    linkQuery.addColumns(<Expression<Object>>[linkCount]);
    linkQuery.where(
      _db.referenceTaxonomyLinks.taxonomyItemId.equals(id) &
          _db.referenceTaxonomyLinks.deletedAt.isNull() &
          _db.references.deletedAt.isNull(),
    );

    final TypedResult linkRow = await linkQuery.getSingle();
    final int linkedCount = linkRow.read(linkCount) ?? 0;

    return directCount + linkedCount;
  }

  /// 데이터베이스에서 읽은 한 줄을 화면이 쓸 모델로 바꿉니다.
  ///
  /// kind가 모르는 값이면 null을 돌려줍니다. 폴더를 태그로 잘못 취급하는 것보다
  /// 목록에서 빼는 편이 안전하기 때문입니다.
  TaxonomyItem? _toModel(TaxonomyItemRow row) {
    final TaxonomyKind? kind = TaxonomyKind.fromStoredName(row.kind);
    if (kind == null) {
      return null;
    }

    return TaxonomyItem(
      id: row.id,
      kind: kind,
      name: row.name,
      parentId: row.parentId,
      // toUtc()를 한 번 더 씌우는 이유는 local_reference_repository.dart의
      // 같은 자리 설명을 보세요.
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
