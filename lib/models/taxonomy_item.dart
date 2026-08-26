// 분류 항목(폴더/카테고리/태그/프로젝트) 하나를 나타내는 모델 클래스입니다.
//
// 넷을 한 클래스로 합친 이유는 lib/models/enums.dart의 TaxonomyKind 설명을 보세요.

import 'enums.dart';

/// 분류 항목 하나입니다. kind가 이게 폴더인지 태그인지를 알려줍니다.
class TaxonomyItem {
  TaxonomyItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 고유 번호(UUID v4)
  final String id;

  /// 폴더/카테고리/태그/프로젝트 중 무엇인지
  final TaxonomyKind kind;

  /// 사용자가 붙인 이름
  final String name;

  /// 만든 시각 (UTC)
  final DateTime createdAt;

  /// 마지막으로 고친 시각 (UTC)
  final DateTime updatedAt;

  /// 몇 가지만 바꾼 사본을 만들어 돌려줍니다.
  /// 왜 이런 방식인지는 reference_item.dart의 copyWith 설명을 보세요.
  TaxonomyItem copyWith({String? name, DateTime? updatedAt}) {
    return TaxonomyItem(
      id: id,
      kind: kind,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 기본 파트의 고유 번호입니다.
///
/// ── 왜 정해진 값을 쓰나 (다른 것들은 만들 때마다 새로 뽑는데) ──
/// 이 앱은 모든 항목에 새 UUID를 뽑아 붙입니다(설계 원칙 1). 그런데 기본 파트만은
/// **미리 정해둔 값**을 씁니다. 이유가 둘입니다.
///
/// 1. 앱 코드가 "기본 파트"를 가리켜야 할 때가 있습니다. 새 레퍼런스를 넣을 때
///    어느 파트에 넣을지 정하는 곳 등입니다. 값이 매번 달라지면 그때마다
///    데이터베이스를 뒤져 찾아야 합니다.
/// 2. **나중에 기기 간 동기화를 붙일 때 유리합니다.** 기기마다 다른 번호를 뽑았다면
///    "이 컴퓨터의 기본 파트"와 "폰의 기본 파트"가 서로 다른 것으로 취급되어
///    파트가 두 개로 늘어납니다. 같은 번호를 쓰면 저절로 같은 것이 됩니다.
///
/// 모양은 평범한 UUID와 같아서 다른 항목과 부딪히지 않습니다.
const String defaultPartId = '00000000-0000-4000-8000-000000000001';

/// 기본 파트의 이름입니다.
///
/// 의뢰인이 "일단 기본으로 두고 나중에 이름 바꾸자"고 정했습니다.
/// 이름은 분류 관리 화면에서 바꿀 수 있고, 바꿔도 위의 번호는 그대로라
/// 레퍼런스 연결이 끊기지 않습니다.
const String defaultPartName = '기본';
