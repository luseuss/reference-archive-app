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

  // ── 아래는 이 파일 안에서만 쓰는 도우미 함수들입니다 ──

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
