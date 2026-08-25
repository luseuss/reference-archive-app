// 레퍼런스를 읽고 쓰는 "약속"만 적어둔 파일입니다. 실제 동작은 들어있지 않습니다.
//
// ── 왜 이런 걸 만드나 (CLAUDE.md 설계 원칙 3) ──
// 화면 코드가 데이터베이스를 직접 만지면, 나중에 저장 방식을 바꿀 때
// (지금은 내 컴퓨터에만 저장하지만 언젠가 서버에도 저장하고 싶어지면)
// 데이터베이스를 만지는 코드가 화면 곳곳에 흩어져 있어서 전부 찾아 고쳐야 합니다.
//
// 그래서 중간에 이 "약속"을 하나 끼워둡니다.
//   화면 코드  →  ReferenceRepository(약속)  →  실제 저장소
//
// 화면은 이 약속만 알면 됩니다. 나중에 서버를 붙일 때는 이 약속을 지키는
// 새 구현체(SyncedReferenceRepository)를 만들어 갈아끼우기만 하면 되고,
// **화면 코드는 한 줄도 안 고쳐도 됩니다.** 이게 이 파일의 존재 이유 전부입니다.
//
// abstract class = "이런 기능이 있어야 한다"는 목록만 적고 내용은 안 적은 클래스입니다.
// 이걸 상속받는 쪽(local_reference_repository.dart)이 실제 내용을 채웁니다.

import '../models/enums.dart';
import '../models/reference_item.dart';
import '../models/reference_query.dart';

/// 레퍼런스를 읽고 쓰는 방법에 대한 약속입니다.
///
/// 여기 적힌 함수들은 전부 Future를 돌려줍니다. Future = "지금 당장은 결과가 없지만
/// 잠시 후에 준다"는 뜻입니다. 데이터베이스를 읽는 데는 시간이 걸리고, 그동안 화면이
/// 멈춰 있으면 안 되기 때문입니다. 쓰는 쪽에서는 await를 붙여서 결과를 기다립니다.
///
///   final items = await repository.getAll();
abstract class ReferenceRepository {
  /// 살아있는 레퍼런스를 전부 가져옵니다. (지운 항목은 빼고)
  ///
  /// 핀 고정된 항목이 항상 맨 위에 오고, 그다음은 최근에 고친 순서입니다.
  Future<List<ReferenceItem>> getAll();

  /// 조건에 맞는 레퍼런스만 가져옵니다.
  ///
  /// 검색어·폴더·태그·즐겨찾기 같은 조건과 정렬 방식은 [query]에 담아 넘깁니다.
  /// 조건을 하나도 안 걸면 getAll()과 같은 결과가 나옵니다.
  ///
  /// **거르는 일은 데이터베이스가 합니다.** 전부 가져와서 화면에서 걸러내면
  /// 레퍼런스가 수천 장이 됐을 때 검색할 때마다 전부 읽어야 해서 느려집니다.
  /// 나중에 서버용 구현체를 만들 때도 서버에 조건을 넘겨 거르게 해야 합니다.
  Future<List<ReferenceItem>> search(ReferenceQuery query);

  /// id로 레퍼런스 하나를 찾습니다. 없으면 null을 돌려줍니다.
  ///
  /// 지워진 항목도 null로 취급합니다. 화면 입장에서는 "없는 것"과 같기 때문입니다.
  Future<ReferenceItem?> getById(String id);

  /// 레퍼런스를 저장합니다. 없으면 새로 만들고, 있으면 덮어씁니다.
  ///
  /// updatedAt은 이 함수 안에서 현재 시각(UTC)으로 알아서 갱신합니다.
  /// 부르는 쪽에서 직접 챙기게 하면 언젠가 반드시 빠뜨리게 되고,
  /// 그러면 나중에 기기 간 동기화가 조용히 틀어집니다.
  Future<void> save(ReferenceItem item);

  /// 레퍼런스를 지웁니다.
  ///
  /// 진짜로 지우지 않고 deletedAt에 시각을 찍습니다(소프트 삭제).
  /// 진짜로 지워버리면 나중에 "이 기기에서 지운 건지, 저 기기에서 새로 만든 건지"를
  /// 구분할 수 없기 때문입니다.
  Future<void> delete(String id);

  /// 레퍼런스에 붙어있는 태그(또는 프로젝트)의 id 목록을 가져옵니다.
  Future<List<String>> getLinkedTaxonomyIds(String referenceId, TaxonomyKind kind);

  /// 레퍼런스에 붙는 태그(또는 프로젝트) 목록을 통째로 바꿉니다.
  ///
  /// 하나씩 붙이고 떼는 함수를 따로 두지 않고 "최종 목록"을 통째로 받습니다.
  /// 화면에서 태그를 편집할 때는 보통 "이 레퍼런스의 태그는 결국 이것들"이라는
  /// 형태로 결정되기 때문에, 이쪽이 쓰기도 쉽고 중간 상태가 어긋날 일도 없습니다.
  Future<void> setLinkedTaxonomyIds(
    String referenceId,
    TaxonomyKind kind,
    List<String> taxonomyItemIds,
  );
}
