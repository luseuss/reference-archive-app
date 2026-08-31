// 레퍼런스끼리 얼마나 비슷한지 계산하는 순수 함수 모음입니다.
//
// ── 왜 이 파일이 따로 있나 ──
// 이 계산들은 화면·DB 없이도 맞는지 확인할 수 있는 순수한 셈입니다.
// (test/utils/similarity_test.dart)
//
// ── 가중치는 어디서 왔나 ──
// 이 프로젝트가 재구축 중인 기존 웹앱(reference-archive, PR #12)에서
// 이미 검증된 값을 그대로 가져왔습니다. AI 호출 없이 태그·분류·이미지
// 세 가지를 가중합해서 0~1 사이 점수를 냅니다.
//   1) 태그 겹침 — 자카드 유사도(교집합/합집합) x 0.35
//   2) 같은 카테고리/폴더/프로젝트에 속하는지 — 각각 +0.1
//   3) 이미지 시각적 유사도 — dHash(퍼셉추얼 해시)의 해밍 거리 x 0.35
//      (해시 자체를 만드는 계산은 services/image_hash.dart에 있습니다)

import '../models/reference_item.dart';

/// 두 집합이 얼마나 겹치는지를 "교집합 ÷ 합집합"으로 나타냅니다.
/// 둘 다 비어 있으면 0입니다(겹치는 게 없다고 봅니다).
double jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) {
    return 0;
  }
  final int intersection = a.intersection(b).length;
  final int union = a.length + b.length - intersection;
  return union == 0 ? 0 : intersection / union;
}

/// 두 dHash 문자열이 몇 비트 다른지 셉니다.
/// 길이가 다르거나 둘 중 하나가 없으면(null) 비교할 수 없으므로 null입니다.
int? hammingDistance(String? a, String? b) {
  if (a == null || b == null || a.length != b.length) {
    return null;
  }
  int distance = 0;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      distance++;
    }
  }
  return distance;
}

/// 두 레퍼런스가 얼마나 비슷한지 0~1 사이 점수로 계산합니다.
/// 자기 자신과 비교하면 0입니다.
double similarityScore(ReferenceItem a, ReferenceItem b) {
  if (a.id == b.id) {
    return 0;
  }

  double score = 0;

  score += jaccard(a.tagIds.toSet(), b.tagIds.toSet()) * 0.35;

  if (a.categoryId != null && a.categoryId == b.categoryId) {
    score += 0.1;
  }
  if (a.folderId != null && a.folderId == b.folderId) {
    score += 0.1;
  }
  if (a.projectIds.any((String p) => b.projectIds.contains(p))) {
    score += 0.1;
  }

  final int? distance = hammingDistance(a.pHash, b.pHash);
  if (distance != null && a.pHash!.isNotEmpty) {
    score += (1 - distance / a.pHash!.length) * 0.35;
  }

  return score;
}

/// [item]과 가장 비슷한 항목 상위 [limit]개를 점수 내림차순으로 돌려줍니다.
/// 점수가 [minScore] 이하인(태그·분류·이미지 어디서도 접점이 거의 없는)
/// 항목은 제외합니다.
List<ReferenceItem> similarItems(
  ReferenceItem item,
  List<ReferenceItem> list, {
  int limit = 6,
  double minScore = 0,
}) {
  final List<MapEntry<ReferenceItem, double>> scored = list
      .where((ReferenceItem i) => i.id != item.id)
      .map(
        (ReferenceItem i) => MapEntry<ReferenceItem, double>(i, similarityScore(item, i)),
      )
      .where((MapEntry<ReferenceItem, double> e) => e.value > minScore)
      .toList();

  scored.sort((a, b) => b.value.compareTo(a.value));

  return scored.take(limit).map((MapEntry<ReferenceItem, double> e) => e.key).toList();
}

/// 목록을 "유사한 것끼리" 정렬합니다.
///
/// 완전한 클러스터링이 아니라, 목록에서 **가장 최근에 추가된 항목**을
/// 기준점으로 고정하고 나머지를 그 항목과의 유사도 내림차순으로 정렬하는
/// 단순한 방식입니다(기존 웹앱과 동일). 기준 항목 자체는 맨 앞에 옵니다.
List<ReferenceItem> sortBySimilarity(List<ReferenceItem> list) {
  if (list.isEmpty) {
    return list;
  }

  final ReferenceItem anchor = list.reduce(
    (ReferenceItem latest, ReferenceItem i) =>
        i.createdAt.isAfter(latest.createdAt) ? i : latest,
  );

  final List<ReferenceItem> rest = list
      .where((ReferenceItem i) => i.id != anchor.id)
      .toList();
  rest.sort(
    (ReferenceItem a, ReferenceItem b) =>
        similarityScore(anchor, b).compareTo(similarityScore(anchor, a)),
  );

  return <ReferenceItem>[anchor, ...rest];
}
