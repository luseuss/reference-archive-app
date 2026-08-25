// 폴더·카테고리·태그·프로젝트를 읽고 쓰는 "약속"만 적어둔 파일입니다.
//
// 왜 약속(abstract class)을 따로 두는지는 reference_repository.dart의
// 맨 위 설명을 보세요. 같은 이유입니다.
//
// 넷을 각각 따로 만들지 않고 하나로 합친 이유는 lib/models/enums.dart의
// TaxonomyKind 설명을 보세요. 담는 정보가 전부 같기 때문입니다.

import '../models/enums.dart';
import '../models/taxonomy_item.dart';

/// 분류 항목(폴더/카테고리/태그/프로젝트)을 읽고 쓰는 방법에 대한 약속입니다.
abstract class TaxonomyRepository {
  /// 해당 종류의 살아있는 항목을 전부 가져옵니다. 이름 가나다순입니다.
  Future<List<TaxonomyItem>> getAll(TaxonomyKind kind);

  /// id로 항목 하나를 찾습니다. 없거나 지워졌으면 null입니다.
  Future<TaxonomyItem?> getById(String id);

  /// 항목을 저장합니다. 없으면 새로 만들고, 있으면 덮어씁니다.
  ///
  /// updatedAt은 이 함수 안에서 알아서 갱신합니다.
  Future<void> save(TaxonomyItem item);

  /// 항목을 지웁니다(소프트 삭제).
  ///
  /// 이 항목을 쓰고 있던 레퍼런스들에서도 연결을 끊습니다.
  /// 안 그러면 "이미 지운 폴더에 들어있는 레퍼런스"가 남아서 목록에서 사라져 보입니다.
  Future<void> delete(String id);

  /// 같은 종류 안에 같은 이름이 이미 있는지 확인합니다.
  ///
  /// 폴더 "인물"이 두 개 생기면 사용자가 어느 쪽에 넣었는지 알 수 없게 됩니다.
  /// [excludeId]는 이름 바꾸기를 할 때 자기 자신은 빼고 검사하려고 쓰는 값입니다.
  Future<bool> existsWithName(TaxonomyKind kind, String name, {String? excludeId});
}
