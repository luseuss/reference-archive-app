// 데이터베이스에 어떤 표(테이블)를 만들지 정의하는 파일입니다.
//
// drift에서는 이렇게 Dart 클래스로 표를 정의해두면, 코드 생성기가 이걸 읽어서
// 실제 SQL과 Dart 코드를 자동으로 만들어줍니다. 이 파일을 고친 뒤에는 반드시
// 아래를 실행해야 반영됩니다.
//
//   dart run build_runner build
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

import '../models/board.dart';

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

  /// 어느 파트에 들어있는지. (디자인/파티클 등 큰 갈래)
  ///
  /// 파트도 하나만 가질 수 있어서 폴더·카테고리처럼 여기에 직접 담습니다.
  ///
  /// nullable인 이유: 이 칸은 나중에 추가됐습니다(스키마 v2). 이미 저장돼 있던
  /// 레퍼런스에는 값이 없으므로 빈 칸을 허용해야 합니다. 마이그레이션에서
  /// 전부 기본 파트로 채우지만, 그래도 구조상은 비어 있을 수 있어야 합니다.
  TextColumn get partId => text().nullable()();

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

/// 무드보드 한 개(씬)를 담는 표입니다.
///
/// 무드보드 = 레퍼런스를 격자가 아니라 **원하는 자리에 자유롭게 늘어놓는 판**입니다.
/// 목록은 컴퓨터가 정한 순서대로 줄을 세우지만, 무드보드는 사람이 직접
/// "이건 여기, 저건 저기"로 배치해서 분위기를 잡아보는 곳입니다.
///
/// 이 표에는 판 자체(이름 등)만 들어갑니다. 판 위에 무엇이 어디 놓였는지는
/// 아래의 BoardCards 표가 담습니다.
@DataClassName('BoardRow')
class Boards extends Table {
  /// 고유 번호(UUID v4 문자열)
  TextColumn get id => text()();

  /// 사용자가 붙인 이름입니다. 예: "겨울 무드", "3화 배경 톤"
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

/// 무드보드 위에 놓인 카드 한 장을 담는 표입니다.
///
/// "어느 판(boardId)에, 어느 레퍼런스(referenceId)를, 어디에(x, y) 놓았는가"를 적어둡니다.
///
/// ── References 표에 x, y를 넣지 않은 이유 ──
/// 같은 레퍼런스를 여러 판에 올릴 수 있어야 하고, 판마다 놓인 자리가 다릅니다.
/// References에 자리를 적으면 레퍼런스 하나당 자리도 하나뿐이라 판을 두 개 만들 수 없습니다.
///
/// ── id를 따로 두는 이유 (ReferenceTaxonomyLinks는 안 뒀는데) ──
/// 태그 연결은 (레퍼런스, 태그) 짝이 하나뿐이라 짝 자체를 열쇠로 썼습니다.
/// 하지만 무드보드에서는 **같은 사진을 한 판에 두 번 올리는 것이 말이 됩니다**
/// (같은 색감을 좌우에 나란히 두고 비교하는 등). 그래서 배치마다 고유 번호를 줍니다.
@DataClassName('BoardCardRow')
class BoardCards extends Table {
  /// 이 배치의 고유 번호(UUID v4 문자열)
  TextColumn get id => text()();

  /// 어느 무드보드에 놓였는지
  TextColumn get boardId => text()();

  /// 어느 레퍼런스인지
  TextColumn get referenceId => text()();

  /// 판 위에서의 가로 위치입니다. 판의 왼쪽 끝이 0입니다.
  ///
  /// 화면 좌표가 아니라 **판 좌표**입니다. 창 크기를 바꿔도 카드가 제자리에
  /// 있어야 하므로, 화면에서 몇 픽셀인지를 저장하면 안 됩니다.
  RealColumn get x => real()();

  /// 판 위에서의 세로 위치입니다. 판의 위쪽 끝이 0입니다.
  RealColumn get y => real()();

  /// 카드의 가로 크기입니다.
  RealColumn get width =>
      real().withDefault(const Constant(defaultBoardCardWidth))();

  /// 카드의 세로 크기입니다. **비어 있으면 "그림 비율대로 알아서"** 라는 뜻입니다.
  ///
  /// 처음 올린 카드는 여기가 비어 있어서 원본 비율 그대로 보입니다.
  /// 사용자가 직접 크기를 조절하면(2단계에서 붙일 기능) 그때 값이 채워집니다.
  /// 0을 기본값으로 두지 않은 이유: 0은 "높이가 0"인지 "아직 안 정했다"인지
  /// 구분할 수 없습니다. 빈 칸은 그 구분이 분명합니다.
  RealColumn get height => real().nullable()();

  /// 카드가 겹쳤을 때 누가 위로 오는지 정하는 값입니다. 클수록 위입니다.
  ///
  /// 무드보드는 카드가 겹치는 것이 정상입니다. 겹칠 때 순서가 없으면
  /// 아래 깔린 카드를 영영 집을 수 없게 됩니다.
  IntColumn get zOrder => integer().withDefault(const Constant(0))();

  /// 이 카드가 속한 그룹의 번호입니다. 그룹에 안 속해 있으면 비어 있습니다.
  ///
  /// 같은 groupId를 가진 카드들은 **하나처럼** 다뤄집니다 — 그중 아무거나
  /// 골라도 전부 같이 골라지고, 하나를 끌면 다 같이 끌립니다(4단계 5번의
  /// 마퀴 다중선택과 비슷하지만, 마퀴는 판을 나가면 잊혀지고 이 값은
  /// 저장됩니다).
  ///
  /// 카드의 고유 번호([id])와는 다른 값입니다. 이건 "묶음 자체"를 가리키는
  /// 번호이고, 같은 묶음의 카드 여러 장이 같은 groupId를 나눠 가집니다.
  TextColumn get groupId => text().nullable()();

  /// 판에 올린 시각 (UTC)
  DateTimeColumn get createdAt => dateTime()();

  /// 마지막으로 옮기거나 고친 시각 (UTC)
  DateTimeColumn get updatedAt => dateTime()();

  /// 판에서 내린 시각 (UTC). 비어 있으면 아직 판 위에 있습니다.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
