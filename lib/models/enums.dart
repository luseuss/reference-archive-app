// 앱 전체에서 쓰는 "종류" 값들을 모아둔 파일입니다.
//
// 이런 값을 문자열('image', 'youtube')로 그냥 들고 다니면 오타가 나도 아무도
// 안 알려줍니다. enum으로 만들어두면 오타를 컴파일 시점에 잡아줍니다.
//
// 주의: 각 항목의 storedName은 데이터베이스에 실제로 저장되는 글자입니다.
// **이미 저장된 데이터가 있는 상태에서 이 글자를 바꾸면 기존 데이터를 못 읽습니다.**
// 화면에 보여줄 이름을 바꾸고 싶다면 storedName 말고 displayName만 고치세요.

/// 레퍼런스 한 건이 무엇인지 나타냅니다.
enum ReferenceType {
  /// 이미지 파일 (앱 데이터 폴더에 저장된 그림)
  image('image', '이미지'),

  /// 유튜브 영상 (파일이 아니라 영상 ID만 저장)
  youtube('youtube', '유튜브');

  const ReferenceType(this.storedName, this.displayName);

  /// 데이터베이스에 저장되는 글자
  final String storedName;

  /// 화면에 보여줄 한국어 이름
  final String displayName;

  /// 데이터베이스에서 읽은 글자를 다시 enum으로 바꿉니다.
  ///
  /// 모르는 값이 들어오면(예: 나중에 종류가 추가된 뒤 옛 버전 앱으로 열었을 때)
  /// 앱을 죽이지 않고 image로 취급합니다. 데이터를 못 읽어서 앱이 안 켜지는 것보다
  /// 하나를 잘못 표시하는 편이 낫기 때문입니다.
  static ReferenceType fromStoredName(String value) {
    for (final ReferenceType type in ReferenceType.values) {
      if (type.storedName == value) {
        return type;
      }
    }
    return ReferenceType.image;
  }
}

/// 레퍼런스를 정리하는 분류 항목의 종류입니다.
///
/// 폴더·카테고리·태그·프로젝트는 담고 있는 정보가 (이름 + 만든 시각)으로 전부 같습니다.
/// 그래서 각각 따로 테이블을 만들지 않고 한 테이블에 담되, 이 값으로 구분합니다.
/// 기존 웹앱에서 makeTaxonomy() 하나로 폴더와 카테고리를 함께 처리했던 것과 같은 방식입니다.
enum TaxonomyKind {
  /// 폴더 — 레퍼런스 하나가 폴더 하나에만 들어갑니다.
  folder('folder', '폴더'),

  /// 카테고리 — 레퍼런스 하나가 카테고리 하나에만 들어갑니다.
  category('category', '카테고리'),

  /// 태그 — 레퍼런스 하나에 여러 개를 붙일 수 있습니다.
  tag('tag', '태그'),

  /// 프로젝트 — 레퍼런스 하나가 여러 프로젝트에 속할 수 있습니다.
  project('project', '프로젝트');

  const TaxonomyKind(this.storedName, this.displayName);

  /// 데이터베이스에 저장되는 글자
  final String storedName;

  /// 화면에 보여줄 한국어 이름
  final String displayName;

  /// 데이터베이스에서 읽은 글자를 다시 enum으로 바꿉니다.
  ///
  /// 모르는 값이면 null을 돌려줍니다. ReferenceType과 달리 아무 값으로나 때울 수 없습니다.
  /// 폴더를 태그로 잘못 취급하면 화면이 엉망이 되기 때문입니다.
  static TaxonomyKind? fromStoredName(String value) {
    for (final TaxonomyKind kind in TaxonomyKind.values) {
      if (kind.storedName == value) {
        return kind;
      }
    }
    return null;
  }
}
