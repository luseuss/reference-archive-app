// 레퍼런스 한 건을 나타내는 모델 클래스입니다.
//
// ── drift가 만들어준 클래스도 있는데 왜 또 만드나 ──
// build_runner가 References 표를 보고 Reference라는 클래스를 자동으로 만들어줍니다.
// 하지만 그건 "데이터베이스의 한 줄"을 그대로 옮긴 것이라 데이터베이스 사정
// (type이 enum이 아니라 문자열이라는 것 등)이 그대로 드러납니다.
//
// 화면 코드가 그걸 직접 쓰면, 나중에 저장 방식을 서버로 바꿀 때 화면까지 같이
// 고쳐야 합니다. 그래서 화면이 쓸 모델은 이렇게 따로 두고, 데이터베이스 모양과의
// 변환은 repositories/local_*.dart 안에서만 합니다.

import 'enums.dart';

/// 레퍼런스 한 건(이미지 또는 유튜브 영상)입니다.
class ReferenceItem {
  ReferenceItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.fileName,
    this.youtubeVideoId,
    this.memo,
    this.folderId,
    this.categoryId,
    this.partId,
    this.isPinned = false,
    this.isFavorite = false,
    this.pHash,
    this.tagIds = const <String>[],
    this.projectIds = const <String>[],
  });

  /// 고유 번호(UUID v4). 한 번 정해지면 절대 바뀌지 않습니다.
  final String id;

  /// 이미지인지 유튜브인지
  final ReferenceType type;

  /// 사용자가 붙인 제목
  final String title;

  /// 이미지일 때 저장된 파일 이름. 절대경로가 아니라 이름만 들어갑니다.
  final String? fileName;

  /// 유튜브일 때 영상 ID
  final String? youtubeVideoId;

  /// 사용자가 적어둔 메모
  final String? memo;

  /// 들어있는 폴더의 id (없으면 null)
  final String? folderId;

  /// 들어있는 카테고리의 id (없으면 null)
  final String? categoryId;

  /// 들어있는 파트의 id (없으면 null)
  ///
  /// 파트는 디자인/파티클 같은 **큰 갈래**입니다. 사이드바에서 고릅니다.
  final String? partId;

  /// 목록 맨 위 고정 여부
  final bool isPinned;

  /// 즐겨찾기 여부
  final bool isFavorite;

  /// 이미지 유사도 비교용 해시 (아직 계산 안 했으면 null)
  final String? pHash;

  /// 붙어있는 태그들의 id 목록
  final List<String> tagIds;

  /// 속해있는 프로젝트들의 id 목록
  final List<String> projectIds;

  /// 만든 시각 (UTC)
  final DateTime createdAt;

  /// 마지막으로 고친 시각 (UTC)
  final DateTime updatedAt;

  /// 이 레퍼런스에서 몇 가지만 바꾼 새 레퍼런스를 만들어 돌려줍니다.
  ///
  /// 이 클래스의 값들은 전부 final이라 한 번 만들면 못 바꿉니다(불변).
  /// 값이 마음대로 바뀌지 않으면 "누가 언제 이걸 바꿨지?" 하고 헤맬 일이 없습니다.
  /// 대신 바꾸고 싶을 때는 이렇게 바뀐 사본을 새로 만듭니다.
  ///
  ///   final 고친것 = 원본.copyWith(title: '새 제목');
  ///
  /// 주의: null로 만들고 싶은 값(예: 폴더에서 빼내기)은 이 함수로는 안 됩니다.
  /// 인자를 안 넘긴 것과 null을 넘긴 것을 구분할 수 없기 때문입니다.
  /// 그럴 때는 clearFolder / clearCategory를 쓰세요.
  ReferenceItem copyWith({
    String? title,
    ReferenceType? type,
    String? fileName,
    String? youtubeVideoId,
    String? memo,
    String? folderId,
    String? categoryId,
    String? partId,
    bool? isPinned,
    bool? isFavorite,
    String? pHash,
    List<String>? tagIds,
    List<String>? projectIds,
    DateTime? updatedAt,
  }) {
    return ReferenceItem(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      memo: memo ?? this.memo,
      folderId: folderId ?? this.folderId,
      categoryId: categoryId ?? this.categoryId,
      partId: partId ?? this.partId,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      pHash: pHash ?? this.pHash,
      tagIds: tagIds ?? this.tagIds,
      projectIds: projectIds ?? this.projectIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 폴더에서 빼낸 사본을 돌려줍니다.
  ReferenceItem clearFolder() {
    return ReferenceItem(
      id: id,
      type: type,
      title: title,
      fileName: fileName,
      youtubeVideoId: youtubeVideoId,
      memo: memo,
      folderId: null,
      categoryId: categoryId,
      partId: partId,
      isPinned: isPinned,
      isFavorite: isFavorite,
      pHash: pHash,
      tagIds: tagIds,
      projectIds: projectIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 카테고리에서 빼낸 사본을 돌려줍니다.
  ReferenceItem clearCategory() {
    return ReferenceItem(
      id: id,
      type: type,
      title: title,
      fileName: fileName,
      youtubeVideoId: youtubeVideoId,
      memo: memo,
      folderId: folderId,
      categoryId: null,
      partId: partId,
      isPinned: isPinned,
      isFavorite: isFavorite,
      pHash: pHash,
      tagIds: tagIds,
      projectIds: projectIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
