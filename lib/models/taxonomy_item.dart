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
