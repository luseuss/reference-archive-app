// TaxonomyRepository 약속을 "내 컴퓨터의 데이터베이스"로 실제로 지키는 구현입니다.
//
// drift 관련 코드는 이 파일 안에만 있습니다.
// 자세한 이유는 local_reference_repository.dart 맨 위 설명을 보세요.

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../models/enums.dart';
import '../models/taxonomy_item.dart';
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
            createdAt: item.createdAt,
            updatedAt: now,
          ),
        );
  }

  /// 항목을 지웁니다(소프트 삭제). 이 항목을 쓰던 레퍼런스에서도 연결을 끊습니다.
  @override
  Future<void> delete(String id) async {
    final DateTime now = DateTime.now().toUtc();

    // 항목 본체와 그 항목을 쓰던 곳들을 함께 정리합니다.
    // 중간에 실패해서 "이미 지운 폴더에 들어있는 레퍼런스"가 남으면 그 레퍼런스가
    // 폴더 목록 어디에도 안 보이게 되므로, transaction으로 묶습니다.
    await _db.transaction(() async {
      await (_db.update(_db.taxonomyItems)..where(($TaxonomyItemsTable t) => t.id.equals(id)))
          .write(TaxonomyItemsCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ));

      // 태그·프로젝트로 쓰이던 연결을 끊습니다.
      await (_db.update(_db.referenceTaxonomyLinks)
            ..where(($ReferenceTaxonomyLinksTable t) =>
                t.taxonomyItemId.equals(id) & t.deletedAt.isNull()))
          .write(ReferenceTaxonomyLinksCompanion(deletedAt: Value<DateTime?>(now)));

      // 폴더로 쓰이던 레퍼런스는 폴더 없음 상태로 되돌립니다.
      await (_db.update(_db.references)..where(($ReferencesTable t) => t.folderId.equals(id)))
          .write(ReferencesCompanion(
        folderId: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ));

      // 카테고리로 쓰이던 레퍼런스도 마찬가지입니다.
      await (_db.update(_db.references)..where(($ReferencesTable t) => t.categoryId.equals(id)))
          .write(ReferencesCompanion(
        categoryId: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ));
    });
  }

  /// 같은 종류 안에 같은 이름이 이미 있는지 확인합니다.
  @override
  Future<bool> existsWithName(
    TaxonomyKind kind,
    String name, {
    String? excludeId,
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
      if (row.name.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
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
      // toUtc()를 한 번 더 씌우는 이유는 local_reference_repository.dart의
      // 같은 자리 설명을 보세요.
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
