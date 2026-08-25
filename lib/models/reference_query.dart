// "어떤 레퍼런스를 어떤 순서로 가져올지"를 담는 클래스입니다.
//
// ── 왜 인자를 따로 넘기지 않고 이렇게 묶었나 ──
// getAll(검색어, 폴더, 태그, 즐겨찾기만, 정렬방식, ...) 처럼 인자를 늘어놓으면
// 조건이 하나 늘 때마다 저장소의 함수 모양이 바뀌고, 그 함수를 쓰는 곳을
// 전부 찾아 고쳐야 합니다.
//
// 이렇게 클래스로 묶어두면 조건이 늘어도 이 파일에 값 하나만 추가하면 되고,
// 기존 코드는 그대로 돌아갑니다. (기본값이 있으니까요)

import 'enums.dart';

/// 목록을 어떤 순서로 보여줄지 정합니다.
enum ReferenceSortOrder {
  /// 최근에 고친 것부터
  recentlyUpdated('최근 수정순'),

  /// 최근에 추가한 것부터
  recentlyAdded('최근 추가순'),

  /// 예전에 추가한 것부터
  oldestAdded('오래된 순'),

  /// 제목 가나다순
  titleAscending('제목순');

  const ReferenceSortOrder(this.displayName);

  /// 화면에 보여줄 한국어 이름
  final String displayName;
}

/// 목록을 가져올 때 쓸 조건들입니다.
///
/// 아무것도 넘기지 않으면 "전부, 최근 수정순"이 됩니다.
class ReferenceQuery {
  const ReferenceQuery({
    this.searchText = '',
    this.folderId,
    this.categoryId,
    this.tagId,
    this.projectId,
    this.favoritesOnly = false,
    this.sortOrder = ReferenceSortOrder.recentlyUpdated,
  });

  /// 검색어입니다. 제목과 메모에서 찾습니다.
  ///
  /// 비어 있으면 검색하지 않고 전부 가져옵니다.
  final String searchText;

  /// 이 폴더에 든 것만 가져옵니다. null이면 폴더로 거르지 않습니다.
  final String? folderId;

  /// 이 카테고리에 든 것만 가져옵니다. null이면 거르지 않습니다.
  final String? categoryId;

  /// 이 태그가 붙은 것만 가져옵니다. null이면 거르지 않습니다.
  final String? tagId;

  /// 이 프로젝트에 속한 것만 가져옵니다. null이면 거르지 않습니다.
  final String? projectId;

  /// 켜면 즐겨찾기한 것만 가져옵니다.
  final bool favoritesOnly;

  /// 어떤 순서로 정렬할지
  final ReferenceSortOrder sortOrder;

  /// 조건이 하나라도 걸려 있는지 알려줍니다.
  ///
  /// 화면에서 "조건에 맞는 게 없습니다"와 "아직 아무것도 없습니다"를
  /// 구분해서 안내하려고 씁니다. 아무것도 없는데 "조건에 맞는 게 없다"고 하면
  /// 사용자가 조건을 지우려고 헤매게 됩니다.
  bool get hasAnyFilter {
    return searchText.trim().isNotEmpty ||
        folderId != null ||
        categoryId != null ||
        tagId != null ||
        projectId != null ||
        favoritesOnly;
  }

  /// 몇 가지만 바꾼 사본을 만들어 돌려줍니다.
  ///
  /// 주의: 이 함수로는 필터를 **끌 수 없습니다.** null을 넘긴 것과 안 넘긴 것을
  /// 구분할 수 없기 때문입니다. 필터를 끄려면 clearFilter()를 쓰세요.
  /// (같은 이유와 해법이 lib/models/reference_item.dart에도 적혀 있습니다)
  ReferenceQuery copyWith({
    String? searchText,
    String? folderId,
    String? categoryId,
    String? tagId,
    String? projectId,
    bool? favoritesOnly,
    ReferenceSortOrder? sortOrder,
  }) {
    return ReferenceQuery(
      searchText: searchText ?? this.searchText,
      folderId: folderId ?? this.folderId,
      categoryId: categoryId ?? this.categoryId,
      tagId: tagId ?? this.tagId,
      projectId: projectId ?? this.projectId,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// 특정 종류의 필터를 끈 사본을 돌려줍니다.
  ///
  /// 예: clearFilter(TaxonomyKind.folder) → 폴더 필터만 해제
  ReferenceQuery clearFilter(TaxonomyKind kind) {
    return ReferenceQuery(
      searchText: searchText,
      folderId: kind == TaxonomyKind.folder ? null : folderId,
      categoryId: kind == TaxonomyKind.category ? null : categoryId,
      tagId: kind == TaxonomyKind.tag ? null : tagId,
      projectId: kind == TaxonomyKind.project ? null : projectId,
      favoritesOnly: favoritesOnly,
      sortOrder: sortOrder,
    );
  }

  /// 모든 필터와 검색어를 지운 사본을 돌려줍니다. 정렬 방식은 그대로 둡니다.
  ReferenceQuery clearAll() {
    return ReferenceQuery(sortOrder: sortOrder);
  }
}
