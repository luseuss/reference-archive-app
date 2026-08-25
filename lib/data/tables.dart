// 데이터베이스에 어떤 표(테이블)를 만들지 정의하는 파일입니다.
//
// drift에서는 이렇게 Dart 클래스로 표를 정의해두면, 코드 생성기가 이걸 읽어서
// 실제 SQL과 Dart 코드를 자동으로 만들어줍니다. 이 파일을 고친 뒤에는 반드시
// 아래를 실행해야 반영됩니다.
//
//   dart run build_runner build --delete-conflicting-outputs
//
// 안 하면 "정의는 고쳤는데 앱은 그대로"인 상태가 됩니다.
//
// ── 모든 표가 공통으로 지키는 3가지 규칙 (CLAUDE.md의 설계 원칙) ──
//  1. id는 UUID 문자열입니다. 1, 2, 3 같은 번호를 쓰면 나중에 두 기기의 데이터를
//     합칠 때 "서로 다른 기기에서 만든 3번"이 충돌합니다.
//  2. createdAt / updatedAt을 항상 기록합니다. 나중에 "어느 기기 버전이 최신인가"를
//     판단하는 유일한 근거입니다. 반드시 UTC로 저장하고, 화면에 보여줄 때만 현지 시각으로 바꿉니다.
//  3. 삭제는 진짜로 지우지 않고 deletedAt에 시각을 찍습니다(소프트 삭제).
//     진짜로 지워버리면 나중에 "이 기기에서 지운 건지, 저 기기에서 새로 만든 건지"를
//     구분할 수 없습니다.

import 'package:drift/drift.dart';

/// 레퍼런스 한 건(이미지 또는 유튜브 영상)을 담는 표입니다.
///
/// @DataClassName은 "이 표의 한 줄"을 나타내는 클래스 이름을 정합니다.
/// 이름 끝에 Row를 붙여서 **데이터베이스의 한 줄**임을 드러냅니다.
/// 화면이 쓰는 모델(lib/models/reference_item.dart의 ReferenceItem)과
/// 헷갈리지 않게 하려는 것입니다. 둘은 담는 내용은 비슷하지만 역할이 다릅니다.
@DataClassName('ReferenceRow')
class References extends Table {
  /// 이 레퍼런스의 고유 번호(UUID v4 문자열)입니다.
  TextColumn get id => text()();

  /// 사용자가 붙인 제목입니다.
  TextColumn get title => text().withDefault(const Constant(''))();

  /// 'image' 또는 'youtube'. ReferenceType enum의 storedName이 들어갑니다.
  TextColumn get type => text()();

  /// 이미지일 때 저장된 파일 이름입니다. 예: "a1b2c3....jpg"
  ///
  /// **절대경로를 넣으면 안 됩니다.** 기기마다 앱 데이터 폴더 위치가 다르고,
  /// 나중에 클라우드 저장소로 옮길 때 경로 매핑이 전부 깨집니다.
  /// 실제 경로는 앱이 실행될 때 폴더 위치와 이 이름을 합쳐서 만듭니다.
  TextColumn get fileName => text().nullable()();

  /// 유튜브일 때 영상 ID입니다. 예: "dQw4w9WgXcQ"
  TextColumn get youtubeVideoId => text().nullable()();

  /// 사용자가 적어둔 메모입니다.
  TextColumn get memo => text().nullable()();

  /// 어느 폴더에 들어있는지. 폴더는 하나만 가질 수 있어서 여기에 직접 담습니다.
  TextColumn get folderId => text().nullable()();

  /// 어느 카테고리에 들어있는지. 카테고리도 하나만 가질 수 있습니다.
  TextColumn get categoryId => text().nullable()();

  /// 목록 맨 위에 고정할지 여부입니다. 정렬 방식과 무관하게 항상 위에 옵니다.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// 즐겨찾기 표시 여부입니다.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// 이미지 유사도 비교에 쓰는 값(퍼셉추얼 해시)입니다.
  ///
  /// 계산에 시간이 걸려서 한 번 구해두고 재사용합니다(캐시).
  /// 아직 계산하지 않았으면 비어 있습니다. 실제 계산은 6단계에서 붙입니다.
  TextColumn get pHash => text().nullable()();

  /// 만든 시각 (UTC)
  DateTimeColumn get createdAt => dateTime()();

  /// 마지막으로 고친 시각 (UTC)
  DateTimeColumn get updatedAt => dateTime()();

  /// 지운 시각 (UTC). 비어 있으면 살아있는 항목입니다.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 폴더·카테고리·태그·프로젝트를 함께 담는 표입니다.
///
/// 넷 다 담는 정보가 (이름 + 시각)으로 똑같아서 표를 네 개 만들지 않고
/// kind 칸으로 구분합니다. 기존 웹앱에서 makeTaxonomy() 하나로 폴더와 카테고리를
/// 함께 처리했던 것과 같은 방식입니다.
@DataClassName('TaxonomyItemRow')
class TaxonomyItems extends Table {
  /// 고유 번호(UUID v4 문자열)
  TextColumn get id => text()();

  /// 'folder' | 'category' | 'tag' | 'project'. TaxonomyKind enum의 storedName입니다.
  TextColumn get kind => text()();

  /// 사용자가 붙인 이름입니다.
  TextColumn get name => text()();

  /// 만든 시각 (UTC)
  DateTimeColumn get createdAt => dateTime()();

  /// 마지막으로 고친 시각 (UTC)
  DateTimeColumn get updatedAt => dateTime()();

  /// 지운 시각 (UTC). 비어 있으면 살아있는 항목입니다.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 레퍼런스와 태그/프로젝트를 이어주는 표입니다.
///
/// 폴더·카테고리는 레퍼런스가 하나만 가질 수 있어서 References 표 안에 직접 담았지만,
/// 태그와 프로젝트는 **여러 개를 붙일 수 있어서** 이렇게 따로 이어주는 표가 필요합니다.
/// (레퍼런스 A에 태그 3개 = 이 표에 줄 3개)
///
/// 이 표는 id를 따로 두지 않습니다. (referenceId, taxonomyItemId) 짝 자체가
/// 이미 세상에 하나뿐인 조합이기 때문입니다(양쪽 다 UUID라서).
/// 대신 여기에도 deletedAt이 있습니다 — 태그를 뗀 것과 아예 붙인 적 없는 것을
/// 구분해야 나중에 기기 간 데이터를 합칠 때 "A 기기에서 뗀 태그"가 되살아나지 않습니다.
@DataClassName('ReferenceTaxonomyLinkRow')
class ReferenceTaxonomyLinks extends Table {
  /// 어느 레퍼런스인지
  TextColumn get referenceId => text()();

  /// 어느 태그/프로젝트인지
  TextColumn get taxonomyItemId => text()();

  /// 이어붙인 시각 (UTC)
  DateTimeColumn get createdAt => dateTime()();

  /// 떼어낸 시각 (UTC). 비어 있으면 현재 붙어 있는 상태입니다.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{referenceId, taxonomyItemId};
}
