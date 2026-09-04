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

  /// 항목을 지웁니다(소프트 삭제). 이 항목을 쓰던 레퍼런스도 함께 정리합니다.
  ///
  /// **기본 파트는 지우지 않습니다.** 아래 설명을 보세요.
  @override
  Future<void> delete(String id) async {
    // ── 기본 파트만은 지울 수 없습니다 ──
    // 파트를 지우면 그 안의 레퍼런스를 기본 파트로 옮기는데, 기본 파트 자신을
    // 지우면 옮길 곳이 없습니다. 게다가 새 레퍼런스는 아무 파트도 안 고른 상태에서
    // 기본 파트로 들어가므로(home_screen.dart의 `_partIdForNewItems`),
    // 기본 파트가 없어지면 **새로 넣는 레퍼런스가 전부 사라진 파트에 들어가** 버립니다.
    //
    // 화면에서도 지우기 버튼을 잠가두지만(taxonomy_manage_screen.dart),
    // 여기서 한 번 더 막습니다. 나중에 다른 화면에서 delete()를 부르게 되어도
    // 이 규칙이 저절로 지켜집니다.
    if (id == defaultPartId) {
      return;
    }

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

      // ── 파트만 다르게 다룹니다: 비우지 않고 기본 파트로 옮깁니다 ──
      // 폴더·카테고리는 비워도(null) 목록에서 그대로 보입니다. "폴더 없음"이
      // 정상적인 상태이기 때문입니다.
      //
      // 파트는 다릅니다. 사이드바가 **파트별로만** 레퍼런스를 보여주기 때문에,
      // 어느 파트에도 안 속한 레퍼런스는 어느 파트를 눌러도 안 보입니다
      // ("전체 레퍼런스"에는 남지만, 사용자 눈에는 사라진 것과 같습니다).
      //
      // 그래서 갈 곳을 만들어줍니다. 기본 파트는 지울 수 없으므로(위 참고)
      // 여기가 언제나 존재하는 안전한 자리입니다.
      await (_db.update(_db.references)..where(($ReferencesTable t) => t.partId.equals(id)))
          .write(ReferencesCompanion(
        partId: const Value<String?>(defaultPartId),
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

  /// 이 분류 항목을 쓰고 있는 살아있는 레퍼런스가 몇 개인지 세어 돌려줍니다.
  ///
  /// 폴더·카테고리로 쓰이는 경우와 태그·프로젝트로 쓰이는 경우를 모두 셉니다.
  /// 종류를 따로 확인하지 않아도 되는 이유: id 자체가 세상에 하나뿐이라
  /// 어차피 한쪽에서만 걸립니다.
  @override
  Future<int> countReferencesUsing(String id) async {
    // 폴더·카테고리·파트로 쓰이는 레퍼런스
    //
    // **파트를 빠뜨리면 안 됩니다.** 파트에 레퍼런스가 50장 들어있어도
    // "쓰는 레퍼런스는 없습니다"라고 안내하게 되어, 사용자는 아무 일도
    // 안 일어날 줄 알고 지웁니다. (파트를 만들 때 여기를 빠뜨렸던 실수입니다)
    final int directCount = await _db
        .references
        .count(
          where: ($ReferencesTable t) =>
              (t.folderId.equals(id) |
                  t.categoryId.equals(id) |
                  t.partId.equals(id)) &
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
      // toUtc()를 한 번 더 씌우는 이유는 local_reference_repository.dart의
      // 같은 자리 설명을 보세요.
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
