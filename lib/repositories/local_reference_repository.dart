// ReferenceRepository 약속을 "내 컴퓨터의 데이터베이스"로 실제로 지키는 구현입니다.
//
// **drift(데이터베이스) 관련 코드는 이 파일 안에만 있습니다.**
// 화면 코드는 ReferenceRepository 약속만 보고, 여기 내용은 몰라도 됩니다.
// 나중에 서버 저장을 붙일 때는 이 파일과 짝이 되는
// synced_reference_repository.dart를 새로 만들어 갈아끼우면 됩니다.

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../models/enums.dart';
import '../models/reference_item.dart';
import '../models/reference_query.dart';
import '../utils/similarity.dart';
import 'reference_repository.dart';

/// 레퍼런스를 이 기기의 데이터베이스에 저장하는 구현체입니다.
class LocalReferenceRepository implements ReferenceRepository {
  LocalReferenceRepository(this._db);

  final AppDatabase _db;

  /// 살아있는 레퍼런스를 전부 가져옵니다. 핀 고정된 것이 항상 맨 위입니다.
  @override
  Future<List<ReferenceItem>> getAll() async {
    final SimpleSelectStatement<$ReferencesTable, ReferenceRow> query =
        _db.select(_db.references)..where(($ReferencesTable t) => t.deletedAt.isNull());

    // 정렬 순서: 핀 고정된 것 먼저 → 그다음 최근에 고친 순서.
    // 핀 고정을 정렬보다 먼저 적용해야 "정렬을 바꿔도 고정한 건 항상 위"가 됩니다.
    query.orderBy(<OrderClauseGenerator<$ReferencesTable>>[
      ($ReferencesTable t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
      ($ReferencesTable t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
    ]);

    final List<ReferenceRow> rows = await query.get();

    // 각 레퍼런스에 붙은 태그·프로젝트 목록을 함께 채워서 돌려줍니다.
    final List<ReferenceItem> result = <ReferenceItem>[];
    for (final ReferenceRow row in rows) {
      result.add(await _toModel(row));
    }
    return result;
  }

  /// 조건에 맞는 레퍼런스만 가져옵니다.
  ///
  /// 거르는 일을 전부 데이터베이스에 맡깁니다. 전부 가져와서 Dart에서 걸러내면
  /// 레퍼런스가 많아졌을 때 검색할 때마다 전부 읽어야 해서 느려집니다.
  @override
  Future<List<ReferenceItem>> search(ReferenceQuery query) async {
    final SimpleSelectStatement<$ReferencesTable, ReferenceRow> statement =
        _db.select(_db.references);

    // 지운 항목은 언제나 제외합니다.
    statement.where(($ReferencesTable t) => t.deletedAt.isNull());

    // ── 검색어: 제목이나 메모에 들어있으면 통과 ──
    final String keyword = query.searchText.trim();
    if (keyword.isNotEmpty) {
      statement.where(($ReferencesTable t) {
        return _containsText(t.title, keyword) | _containsText(t.memo, keyword);
      });
    }

    // ── 폴더 / 카테고리 필터 ──
    final String? folderId = query.folderId;
    if (folderId != null) {
      statement.where(($ReferencesTable t) => t.folderId.equals(folderId));
    }

    final String? categoryId = query.categoryId;
    if (categoryId != null) {
      statement.where(($ReferencesTable t) => t.categoryId.equals(categoryId));
    }

    // ── 파트 필터 ──
    // 사이드바에서 고른 파트입니다. 다른 필터보다 앞선 갈래라서,
    // 파트를 고르면 그 안에서만 검색·폴더·태그가 동작합니다.
    final String? partId = query.partId;
    if (partId != null) {
      statement.where(($ReferencesTable t) => t.partId.equals(partId));
    }

    // ── 즐겨찾기 필터 ──
    if (query.favoritesOnly) {
      statement.where(($ReferencesTable t) => t.isFavorite.equals(true));
    }

    // ── 태그 / 프로젝트 필터 ──
    // 이 둘은 다른 표(연결 표)에 있어서 위와 같은 방식으로는 못 거릅니다.
    // "연결 표에 이 레퍼런스와 이 태그를 잇는 살아있는 줄이 있는가"를 묻습니다.
    final String? tagId = query.tagId;
    if (tagId != null) {
      statement.where(($ReferencesTable t) => _hasLink(t, tagId));
    }

    final String? projectId = query.projectId;
    if (projectId != null) {
      statement.where(($ReferencesTable t) => _hasLink(t, projectId));
    }

    // ── 정렬 ──
    // 핀 고정을 항상 맨 앞에 두고, 그다음에 사용자가 고른 순서를 적용합니다.
    // 순서가 반대면 "정렬을 바꾸면 고정이 풀린 것처럼 보이는" 문제가 생깁니다.
    statement.orderBy(<OrderClauseGenerator<$ReferencesTable>>[
      ($ReferencesTable t) =>
          OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
      _orderingFor(query.sortOrder),
    ]);

    final List<ReferenceRow> rows = await statement.get();

    final List<ReferenceItem> result = <ReferenceItem>[];
    for (final ReferenceRow row in rows) {
      result.add(await _toModel(row));
    }

    // "유사한 것끼리"는 SQL로 못 하므로 여기서 다시 정렬합니다.
    // 핀 고정된 항목은 유사도 정렬 대상에서 빼고, 이미 SQL이 맨 앞에
    // 모아준 순서를 그대로 둡니다 — "정렬을 바꿔도 고정한 건 항상 위"
    // 규칙을 유사도 정렬에도 지키기 위해서입니다.
    if (query.sortOrder == ReferenceSortOrder.similar) {
      final List<ReferenceItem> pinned = result
          .where((ReferenceItem item) => item.isPinned)
          .toList();
      final List<ReferenceItem> rest = result
          .where((ReferenceItem item) => !item.isPinned)
          .toList();
      return <ReferenceItem>[...pinned, ...sortBySimilarity(rest)];
    }

    return result;
  }

  /// [column]의 글자 안에 [needle]이 들어있는지를 묻는 조건을 만듭니다. 대소문자는 무시합니다.
  ///
  /// ── LIKE를 쓰지 않는 이유 ──
  /// 보통 검색은 `LIKE '%검색어%'`로 합니다. 그런데 LIKE에서 `%`는 "아무 글자나
  /// 몇 개든", `_`는 "아무 글자 한 개"라는 **특수한 뜻**을 가집니다.
  /// 그래서 사용자가 "50%"나 "IMG_1234"를 검색하면 그 글자들이 와일드카드로
  /// 해석되어 엉뚱한 결과가 나옵니다.
  ///
  /// 막으려면 `\`로 감싸고 `ESCAPE '\'`를 붙여야 하는데, 이걸 빠뜨리면
  /// 오히려 `\`를 글자 그대로 찾게 되어 더 나빠집니다(실제로 처음에 그렇게 틀렸습니다).
  ///
  /// `instr(찾을대상, 검색어)`는 **와일드카드 개념 자체가 없어서** 언제나 글자
  /// 그대로 찾습니다. 들어있으면 그 위치(1부터), 없으면 0을 돌려줍니다.
  /// 양쪽 다 lower()로 소문자로 바꿔서 대소문자를 구분하지 않게 합니다.
  Expression<bool> _containsText(Expression<String> column, String needle) {
    return FunctionCallExpression<int>('instr', <Expression<Object>>[
      column.lower(),
      Variable<String>(needle.toLowerCase()),
    ]).isBiggerThanValue(0);
  }

  /// 이 레퍼런스에 [taxonomyItemId]가 붙어 있는지를 묻는 조건을 만듭니다.
  ///
  /// 태그와 프로젝트는 같은 연결 표에 들어있고, id 자체가 세상에 하나뿐이라
  /// 종류를 따로 확인하지 않아도 됩니다.
  Expression<bool> _hasLink($ReferencesTable t, String taxonomyItemId) {
    return existsQuery(
      _db.select(_db.referenceTaxonomyLinks)
        ..where(($ReferenceTaxonomyLinksTable link) =>
            link.referenceId.equalsExp(t.id) &
            link.taxonomyItemId.equals(taxonomyItemId) &
            link.deletedAt.isNull()),
    );
  }

  /// 정렬 방식에 맞는 정렬 조건을 만들어 돌려줍니다.
  OrderClauseGenerator<$ReferencesTable> _orderingFor(ReferenceSortOrder order) {
    switch (order) {
      case ReferenceSortOrder.recentlyUpdated:
        return ($ReferencesTable t) =>
            OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc);

      case ReferenceSortOrder.recentlyAdded:
        return ($ReferencesTable t) =>
            OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc);

      case ReferenceSortOrder.oldestAdded:
        return ($ReferencesTable t) =>
            OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc);

      case ReferenceSortOrder.titleAscending:
        return ($ReferencesTable t) =>
            OrderingTerm(expression: t.title, mode: OrderingMode.asc);

      case ReferenceSortOrder.similar:
        // 유사도는 SQL로 표현할 수 없어서, 일단 최근 추가한 순서로
        // 가져온 뒤 search()에서 Dart 쪽으로 다시 정렬합니다.
        return ($ReferencesTable t) =>
            OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc);
    }
  }

  /// id로 레퍼런스 하나를 찾습니다. 없거나 지워졌으면 null입니다.
  @override
  Future<ReferenceItem?> getById(String id) async {
    final ReferenceRow? row = await (_db.select(_db.references)
          ..where(($ReferencesTable t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();

    if (row == null) {
      return null;
    }
    return _toModel(row);
  }

  /// 레퍼런스를 저장합니다. 없으면 새로 만들고, 있으면 덮어씁니다.
  @override
  Future<void> save(ReferenceItem item) async {
    // updatedAt은 부르는 쪽에 맡기지 않고 여기서 무조건 지금 시각으로 갱신합니다.
    // 부르는 쪽이 챙기게 하면 언젠가 반드시 빠뜨리게 되고, 그러면 나중에
    // 기기 간 동기화가 "어느 쪽이 최신인지" 판단을 틀리게 합니다.
    final DateTime now = DateTime.now().toUtc();

    // 레퍼런스 본체와 태그·프로젝트 연결을 함께 저장합니다.
    // transaction = "전부 성공하거나 전부 실패하거나" 둘 중 하나만 되게 묶는 것입니다.
    // 본체는 저장됐는데 태그 연결에서 오류가 나면 반쪽짜리 데이터가 남기 때문입니다.
    await _db.transaction(() async {
      await _db.into(_db.references).insertOnConflictUpdate(
            ReferencesCompanion.insert(
              id: item.id,
              type: item.type.storedName,
              title: Value<String>(item.title),
              fileName: Value<String?>(item.fileName),
              youtubeVideoId: Value<String?>(item.youtubeVideoId),
              memo: Value<String?>(item.memo),
              folderId: Value<String?>(item.folderId),
              categoryId: Value<String?>(item.categoryId),
              partId: Value<String?>(item.partId),
              isPinned: Value<bool>(item.isPinned),
              isFavorite: Value<bool>(item.isFavorite),
              pHash: Value<String?>(item.pHash),
              createdAt: item.createdAt,
              updatedAt: now,
            ),
          );

      await _replaceLinks(item.id, TaxonomyKind.tag, item.tagIds, now);
      await _replaceLinks(item.id, TaxonomyKind.project, item.projectIds, now);
    });
  }

  /// 레퍼런스를 지웁니다. 진짜로 지우지 않고 deletedAt에 시각을 찍습니다.
  @override
  Future<void> delete(String id) async {
    final DateTime now = DateTime.now().toUtc();
    await (_db.update(_db.references)..where(($ReferencesTable t) => t.id.equals(id))).write(
      ReferencesCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// 레퍼런스에 붙어있는 태그(또는 프로젝트)의 id 목록을 가져옵니다.
  @override
  Future<List<String>> getLinkedTaxonomyIds(String referenceId, TaxonomyKind kind) async {
    // 연결 표에는 종류(태그인지 프로젝트인지)가 안 적혀 있습니다.
    // 그래서 분류 항목 표와 이어붙여서(join) 원하는 종류만 걸러냅니다.
    final JoinedSelectStatement<HasResultSet, dynamic> query = _db.select(_db.referenceTaxonomyLinks).join(
      <Join<HasResultSet, dynamic>>[
        innerJoin(
          _db.taxonomyItems,
          _db.taxonomyItems.id.equalsExp(_db.referenceTaxonomyLinks.taxonomyItemId),
        ),
      ],
    );

    query.where(
      _db.referenceTaxonomyLinks.referenceId.equals(referenceId) &
          _db.referenceTaxonomyLinks.deletedAt.isNull() &
          _db.taxonomyItems.kind.equals(kind.storedName) &
          _db.taxonomyItems.deletedAt.isNull(),
    );

    // 순서가 매번 달라지면 화면에서 태그 순서가 들쭉날쭉해 보입니다. 이름순으로 고정합니다.
    query.orderBy(<OrderingTerm>[OrderingTerm(expression: _db.taxonomyItems.name)]);

    final List<TypedResult> rows = await query.get();
    return rows
        .map((TypedResult row) => row.readTable(_db.taxonomyItems).id)
        .toList();
  }

  /// 레퍼런스에 붙는 태그(또는 프로젝트) 목록을 통째로 바꿉니다.
  @override
  Future<void> setLinkedTaxonomyIds(
    String referenceId,
    TaxonomyKind kind,
    List<String> taxonomyItemIds,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _replaceLinks(referenceId, kind, taxonomyItemIds, now);
    });
  }

  /// 여러 레퍼런스를 한 폴더로 옮깁니다. [folderId]가 null이면 폴더에서 빼냅니다.
  ///
  /// 한 줄씩 고치지 않고 **UPDATE 한 번**으로 끝냅니다.
  /// isIn(...)은 SQL의 `WHERE id IN ('a','b','c')`가 됩니다.
  @override
  Future<void> moveManyToFolder(
    List<String> referenceIds,
    String? folderId,
  ) async {
    // 빈 목록으로 부르면 조건이 `WHERE id IN ()`이 되어 아무것도 안 걸립니다.
    // 그래도 쓸데없이 데이터베이스를 건드릴 이유가 없으므로 먼저 돌아갑니다.
    if (referenceIds.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();

    await (_db.update(_db.references)
          ..where(($ReferencesTable t) => t.id.isIn(referenceIds)))
        .write(
          ReferencesCompanion(
            // Value<String?>(null)은 "null로 덮어써라"는 뜻입니다.
            // 그냥 두는 것(값을 안 넘김)과 명확히 다릅니다.
            folderId: Value<String?>(folderId),
            updatedAt: Value<DateTime>(now),
          ),
        );
  }

  /// 여러 레퍼런스에 같은 태그(또는 프로젝트)를 붙입니다.
  ///
  /// 이미 붙어있는 것은 건너뜁니다. 그냥 다시 붙이면 붙인 시각(createdAt)이
  /// 새로 찍혀서, 나중에 기기 간 동기화가 "방금 새로 붙은 태그"로 착각합니다.
  @override
  Future<void> addTaxonomyItemToMany(
    List<String> referenceIds,
    String taxonomyItemId,
  ) async {
    if (referenceIds.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();

    // transaction = "전부 성공하거나 전부 실패하거나". 중간에 오류가 나면
    // 일부에만 태그가 붙은 어정쩡한 상태로 남지 않습니다.
    await _db.transaction(() async {
      for (final String referenceId in referenceIds) {
        final bool alreadyLinked = await _isLinked(referenceId, taxonomyItemId);
        if (alreadyLinked) {
          continue;
        }

        // insertOnConflictUpdate를 쓰는 이유: 예전에 뗐던 태그를 다시 붙이는
        // 경우 그 줄이 deletedAt만 찍힌 채 표에 남아 있습니다. 그냥 insert하면
        // "이미 있는 줄"이라며 실패하므로, 덮어쓰면서 deletedAt을 비워 되살립니다.
        await _db
            .into(_db.referenceTaxonomyLinks)
            .insertOnConflictUpdate(
              ReferenceTaxonomyLinksCompanion.insert(
                referenceId: referenceId,
                taxonomyItemId: taxonomyItemId,
                createdAt: now,
                deletedAt: const Value<DateTime?>(null),
              ),
            );

        // 레퍼런스 본체의 updatedAt도 갱신합니다.
        //
        // 태그는 다른 표에 있어서 본체는 글자 하나 안 바뀌지만, 사용자 입장에서는
        // 이 레퍼런스를 고친 것이 맞습니다. 여기서 안 갱신하면 "마지막 동기화
        // 이후 바뀐 것"을 고를 때 이 레퍼런스가 빠져서, 다른 기기에는 태그가
        // 안 붙은 채로 남습니다.
        await (_db.update(_db.references)
              ..where(($ReferencesTable t) => t.id.equals(referenceId)))
            .write(ReferencesCompanion(updatedAt: Value<DateTime>(now)));
      }
    });
  }

  /// 여러 레퍼런스를 한꺼번에 지웁니다. 소프트 삭제입니다.
  @override
  Future<void> deleteMany(List<String> referenceIds) async {
    if (referenceIds.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();

    await (_db.update(_db.references)
          ..where(($ReferencesTable t) => t.id.isIn(referenceIds)))
        .write(
          ReferencesCompanion(
            deletedAt: Value<DateTime?>(now),
            updatedAt: Value<DateTime>(now),
          ),
        );
  }

  // ── 아래는 이 파일 안에서만 쓰는 도우미 함수들입니다 ──

  /// 이 레퍼런스에 이 분류 항목이 지금 붙어 있는지 확인합니다.
  ///
  /// 연결 표에는 종류(태그/프로젝트)가 안 적혀 있지만, 분류 항목 id 자체가
  /// 세상에 하나뿐이라 종류를 따로 확인할 필요가 없습니다.
  Future<bool> _isLinked(String referenceId, String taxonomyItemId) async {
    final ReferenceTaxonomyLinkRow? link =
        await (_db.select(_db.referenceTaxonomyLinks)..where(
              ($ReferenceTaxonomyLinksTable t) =>
                  t.referenceId.equals(referenceId) &
                  t.taxonomyItemId.equals(taxonomyItemId) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    return link != null;
  }

  /// 특정 종류의 연결을 [wantedIds] 목록과 똑같아지도록 맞춥니다.
  ///
  /// 통째로 지우고 다시 넣지 않는 이유: 그러면 태그를 하나도 안 건드렸는데도
  /// 붙인 시각(createdAt)이 매번 새로 바뀝니다. 그러면 나중에 기기 간 동기화가
  /// "이 태그는 방금 새로 붙은 것"으로 착각합니다. 그래서 실제로 달라진 것만 고칩니다.
  Future<void> _replaceLinks(
    String referenceId,
    TaxonomyKind kind,
    List<String> wantedIds,
    DateTime now,
  ) async {
    final List<String> currentIds = await getLinkedTaxonomyIds(referenceId, kind);

    // 없어진 것: 지금은 붙어있지만 새 목록엔 없는 것 → 뗀 시각을 찍습니다.
    for (final String existingId in currentIds) {
      if (!wantedIds.contains(existingId)) {
        await (_db.update(_db.referenceTaxonomyLinks)
              ..where(($ReferenceTaxonomyLinksTable t) =>
                  t.referenceId.equals(referenceId) & t.taxonomyItemId.equals(existingId)))
            .write(ReferenceTaxonomyLinksCompanion(deletedAt: Value<DateTime?>(now)));
      }
    }

    // 새로 생긴 것: 새 목록엔 있지만 지금은 안 붙어있는 것 → 붙입니다.
    //
    // insertOnConflictUpdate를 쓰는 이유: 예전에 뗐던 태그를 다시 붙이는 경우
    // 그 줄이 deletedAt만 찍힌 채 아직 표에 남아 있습니다. 그냥 insert하면
    // "이미 있는 줄"이라며 실패하므로, 덮어쓰면서 deletedAt을 비워 되살립니다.
    for (final String wantedId in wantedIds) {
      if (!currentIds.contains(wantedId)) {
        await _db.into(_db.referenceTaxonomyLinks).insertOnConflictUpdate(
              ReferenceTaxonomyLinksCompanion.insert(
                referenceId: referenceId,
                taxonomyItemId: wantedId,
                createdAt: now,
                deletedAt: const Value<DateTime?>(null),
              ),
            );
      }
    }
  }

  /// 데이터베이스에서 읽은 한 줄을 화면이 쓸 모델로 바꿉니다.
  ///
  /// 태그·프로젝트는 다른 표에 있어서 여기서 따로 읽어와 채웁니다.
  Future<ReferenceItem> _toModel(ReferenceRow row) async {
    final List<String> tagIds = await getLinkedTaxonomyIds(row.id, TaxonomyKind.tag);
    final List<String> projectIds = await getLinkedTaxonomyIds(row.id, TaxonomyKind.project);

    return ReferenceItem(
      id: row.id,
      type: ReferenceType.fromStoredName(row.type),
      title: row.title,
      fileName: row.fileName,
      youtubeVideoId: row.youtubeVideoId,
      memo: row.memo,
      folderId: row.folderId,
      categoryId: row.categoryId,
      partId: row.partId,
      isPinned: row.isPinned,
      isFavorite: row.isFavorite,
      pHash: row.pHash,
      tagIds: tagIds,
      projectIds: projectIds,
      // toUtc()를 한 번 더 씌우는 이유:
      // build.yaml에서 시각을 UTC 글자로 저장하도록 설정해뒀지만, 그 설정을 누가
      // 실수로 지우면 시각이 조용히 현지 시각으로 바뀌어 돌아옵니다. 화면과 동기화가
      // 전부 UTC를 전제로 하므로, 여기서 한 번 더 확실히 못 박아둡니다.
      // 이미 UTC인 값에 toUtc()를 해도 아무 일도 일어나지 않아 손해가 없습니다.
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
