# 유사도 엔진 구현 계획 (6단계 1부)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 태그 자카드 + 카테고리/폴더/프로젝트 보너스 + dHash 퍼셉추얼 해시로 레퍼런스 유사도를 계산하고, 목록에 "유사한 것끼리" 정렬 옵션을 추가한다.

**Architecture:** 순수 함수 계산 계층(`lib/utils/similarity.dart`)과 이미지 해시 계산(`lib/services/image_hash.dart`)을 화면·DB와 분리해서 만들고, 레퍼런스를 새로 저장할 때 해시를 계산해 넣고(`reference_importer.dart`), 이미 저장된 것 중 해시가 없는 것은 앱을 켤 때 백그라운드로 채운다(`phash_backfill.dart`). 정렬은 기존 `ReferenceSortOrder` 열거형에 값 하나를 추가하고, SQL로 표현할 수 없는 부분만 저장소(`local_reference_repository.dart`)에서 Dart 쪽으로 재정렬한다.

**Tech Stack:** Flutter/Dart, `image` 패키지(이미 의존성에 있음, 디코드·리사이즈), drift(로컬 DB)

**Spec:** `docs/superpowers/specs/2026-08-31-similarity-engine-design.md`

## Global Constraints

- 가중치는 검증된 기존 웹앱 값을 그대로 씁니다: 태그 자카드 × 0.35, 같은 카테고리 +0.1, 같은 폴더 +0.1, 겹치는 프로젝트 있으면 +0.1, pHash `(1 - 해밍거리/64) × 0.35`.
- dHash: 이미지를 9×8 그레이스케일로 **강제**(가로세로 비율 무시) 리사이즈한 뒤, 각 행에서 가로로 인접한 픽셀의 밝기(`0.299R + 0.587G + 0.114B`)를 비교해 64비트(문자열 `'0'`/`'1'` 64개) 생성.
- **저장 구조는 안 바뀝니다.** `pHash` 칼럼은 이미 있습니다(schemaVersion 1부터). 마이그레이션 없음.
- "핀 고정된 항목은 정렬과 무관하게 항상 맨 위" 규칙을 "유사한 것끼리" 정렬에도 지킵니다.
- 이번 PR 범위는 **엔진 + 정렬 옵션까지만**입니다. 레퍼런스 상세 화면의 "비슷한 레퍼런스" 섹션은 포함하지 않습니다(다음 PR).
- 모든 새 파일 상단에 한국어로 그 파일의 역할을 설명하는 주석을 답니다. 모든 함수 위에 한국어 한 줄 주석을 답니다.
- `flutter analyze`가 항상 깨끗해야 하고, 각 태스크가 끝날 때마다 `flutter test`가 전부 통과해야 합니다.

---

### Task 1: 유사도 계산 (순수 함수)

**Files:**
- Create: `lib/utils/similarity.dart`
- Test: `test/utils/similarity_test.dart`

**Interfaces:**
- Consumes: `lib/models/reference_item.dart`의 `ReferenceItem`(이미 있음 — `tagIds: List<String>`, `categoryId`/`folderId: String?`, `projectIds: List<String>`, `pHash: String?`, `id`/`createdAt` 등)
- Produces:
  - `double jaccard(Set<String> a, Set<String> b)`
  - `int? hammingDistance(String? a, String? b)`
  - `double similarityScore(ReferenceItem a, ReferenceItem b)`
  - `List<ReferenceItem> similarItems(ReferenceItem item, List<ReferenceItem> list, {int limit, double minScore})`
  - `List<ReferenceItem> sortBySimilarity(List<ReferenceItem> list)`

  Task 5가 `sortBySimilarity`를 씁니다.

- [ ] **Step 1: 실패하는 테스트를 먼저 씁니다**

`test/utils/similarity_test.dart`:

```dart
// 유사도 계산이 맞는지 확인하는 테스트입니다. 화면·DB 없이 통과할 수
// 있는 순수 함수라 위젯 없이 봅니다.
//
// 가중치는 기존 웹앱(PR #12)에서 검증된 값을 그대로 가져왔습니다:
// 태그 자카드 0.35 + 같은 카테고리 0.1 + 같은 폴더 0.1 + 겹치는 프로젝트
// 0.1 + pHash 해밍거리 0.35.

import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/utils/similarity.dart';

void main() {
  /// 테스트용 레퍼런스를 하나 만들어 돌려줍니다.
  ReferenceItem makeItem(
    String id, {
    DateTime? createdAt,
    List<String> tagIds = const <String>[],
    String? categoryId,
    String? folderId,
    List<String> projectIds = const <String>[],
    String? pHash,
  }) {
    final DateTime now = createdAt ?? DateTime.utc(2026, 1, 1);
    return ReferenceItem(
      id: id,
      type: ReferenceType.image,
      tagIds: tagIds,
      categoryId: categoryId,
      folderId: folderId,
      projectIds: projectIds,
      pHash: pHash,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('jaccard', () {
    test('둘 다 비었으면 0이다', () {
      expect(jaccard(<String>{}, <String>{}), 0);
    });

    test('완전히 같으면 1이다', () {
      expect(jaccard(<String>{'a', 'b'}, <String>{'a', 'b'}), 1);
    });

    test('절반 겹치면 교집합/합집합이다', () {
      // 교집합 1, 합집합 3 -> 1/3
      expect(jaccard(<String>{'a', 'b'}, <String>{'b', 'c'}), closeTo(1 / 3, 0.0001));
    });

    test('하나도 안 겹치면 0이다', () {
      expect(jaccard(<String>{'a'}, <String>{'b'}), 0);
    });
  });

  group('hammingDistance', () {
    test('완전히 같으면 0이다', () {
      expect(hammingDistance('1010', '1010'), 0);
    });

    test('다른 비트 수만큼 돌려준다', () {
      expect(hammingDistance('1010', '1111'), 2);
    });

    test('길이가 다르면 null이다', () {
      expect(hammingDistance('101', '1010'), isNull);
    });

    test('둘 중 하나가 null이면 null이다', () {
      expect(hammingDistance(null, '1010'), isNull);
      expect(hammingDistance('1010', null), isNull);
    });
  });

  group('similarityScore', () {
    test('자기 자신과는 0이다', () {
      final ReferenceItem item = makeItem('a', tagIds: <String>['x']);
      expect(similarityScore(item, item), 0);
    });

    test('태그만 겹치면 자카드 x 0.35다', () {
      final ReferenceItem a = makeItem('a', tagIds: <String>['x', 'y']);
      final ReferenceItem b = makeItem('b', tagIds: <String>['y', 'z']);
      // 자카드 = 1/3
      expect(similarityScore(a, b), closeTo((1 / 3) * 0.35, 0.0001));
    });

    test('같은 카테고리면 0.1이 더해진다', () {
      final ReferenceItem a = makeItem('a', categoryId: 'cat-1');
      final ReferenceItem b = makeItem('b', categoryId: 'cat-1');
      expect(similarityScore(a, b), closeTo(0.1, 0.0001));
    });

    test('같은 폴더면 0.1이 더해진다', () {
      final ReferenceItem a = makeItem('a', folderId: 'folder-1');
      final ReferenceItem b = makeItem('b', folderId: 'folder-1');
      expect(similarityScore(a, b), closeTo(0.1, 0.0001));
    });

    test('겹치는 프로젝트가 하나라도 있으면 0.1이 더해진다', () {
      final ReferenceItem a = makeItem('a', projectIds: <String>['p1', 'p2']);
      final ReferenceItem b = makeItem('b', projectIds: <String>['p2', 'p3']);
      expect(similarityScore(a, b), closeTo(0.1, 0.0001));
    });

    test('겹치는 프로젝트가 없으면 안 더해진다', () {
      final ReferenceItem a = makeItem('a', projectIds: <String>['p1']);
      final ReferenceItem b = makeItem('b', projectIds: <String>['p2']);
      expect(similarityScore(a, b), 0);
    });

    test('pHash가 둘 다 있으면 (1 - 해밍거리/길이) x 0.35다', () {
      // 64비트 중 4비트만 다름 -> 1 - 4/64 = 0.9375
      final String hashA = '1' * 64;
      final String hashB = '${'1' * 60}0000';
      final ReferenceItem a = makeItem('a', pHash: hashA);
      final ReferenceItem b = makeItem('b', pHash: hashB);
      expect(similarityScore(a, b), closeTo(0.9375 * 0.35, 0.0001));
    });

    test('pHash가 하나라도 없으면 그 항목은 안 더해진다', () {
      final ReferenceItem a = makeItem('a', pHash: '1' * 64);
      final ReferenceItem b = makeItem('b');
      expect(similarityScore(a, b), 0);
    });

    test('여러 항목이 동시에 겹치면 전부 더해진다', () {
      final ReferenceItem a = makeItem(
        'a',
        tagIds: <String>['x'],
        categoryId: 'cat-1',
        folderId: 'folder-1',
      );
      final ReferenceItem b = makeItem(
        'b',
        tagIds: <String>['x'],
        categoryId: 'cat-1',
        folderId: 'folder-1',
      );
      // 태그 자카드(완전히 같음) 1 x 0.35 + 카테고리 0.1 + 폴더 0.1
      expect(similarityScore(a, b), closeTo(0.35 + 0.1 + 0.1, 0.0001));
    });
  });

  group('similarItems', () {
    test('점수가 높은 순으로 정렬해서 돌려준다', () {
      final ReferenceItem target = makeItem('target', tagIds: <String>['x', 'y']);
      final ReferenceItem high = makeItem('high', tagIds: <String>['x', 'y']); // 자카드 1
      final ReferenceItem low = makeItem('low', tagIds: <String>['x']); // 자카드 1/2
      final ReferenceItem none = makeItem('none', tagIds: <String>['z']); // 자카드 0

      final List<ReferenceItem> result = similarItems(
        target,
        <ReferenceItem>[low, none, high],
        limit: 10,
      );

      expect(result.map((ReferenceItem i) => i.id).toList(), <String>['high', 'low']);
    });

    test('자기 자신은 결과에서 빠진다', () {
      final ReferenceItem target = makeItem('target', tagIds: <String>['x']);
      final List<ReferenceItem> result = similarItems(
        target,
        <ReferenceItem>[target],
        limit: 10,
      );
      expect(result, isEmpty);
    });

    test('limit만큼만 돌려준다', () {
      final ReferenceItem target = makeItem('target', tagIds: <String>['x']);
      final List<ReferenceItem> list = List<ReferenceItem>.generate(
        5,
        (int i) => makeItem('item-$i', tagIds: <String>['x']),
      );
      final List<ReferenceItem> result = similarItems(target, list, limit: 2);
      expect(result.length, 2);
    });

    test('minScore 이하는 제외한다', () {
      final ReferenceItem target = makeItem('target', tagIds: <String>['x', 'y']);
      final ReferenceItem low = makeItem('low', tagIds: <String>['x']); // 자카드 1/2 -> 0.175
      final List<ReferenceItem> result = similarItems(
        target,
        <ReferenceItem>[low],
        limit: 10,
        minScore: 0.2,
      );
      expect(result, isEmpty);
    });
  });

  group('sortBySimilarity', () {
    test('가장 최근에 추가된 항목이 맨 앞에 고정된다', () {
      final ReferenceItem old = makeItem(
        'old',
        createdAt: DateTime.utc(2026, 1, 1),
        tagIds: <String>['x'],
      );
      final ReferenceItem newest = makeItem(
        'newest',
        createdAt: DateTime.utc(2026, 3, 1),
        tagIds: <String>['z'], // 아무와도 안 겹침
      );

      final List<ReferenceItem> result = sortBySimilarity(<ReferenceItem>[old, newest]);

      expect(result.first.id, 'newest');
    });

    test('나머지는 기준 항목과의 유사도 내림차순이다', () {
      final ReferenceItem anchor = makeItem(
        'anchor',
        createdAt: DateTime.utc(2026, 3, 1),
        tagIds: <String>['x', 'y'],
      );
      final ReferenceItem high = makeItem(
        'high',
        createdAt: DateTime.utc(2026, 1, 1),
        tagIds: <String>['x', 'y'], // 자카드 1
      );
      final ReferenceItem low = makeItem(
        'low',
        createdAt: DateTime.utc(2026, 1, 2),
        tagIds: <String>['x'], // 자카드 1/2
      );

      final List<ReferenceItem> result = sortBySimilarity(<ReferenceItem>[low, anchor, high]);

      expect(
        result.map((ReferenceItem i) => i.id).toList(),
        <String>['anchor', 'high', 'low'],
      );
    });

    test('빈 목록이면 빈 목록을 돌려준다', () {
      expect(sortBySimilarity(<ReferenceItem>[]), isEmpty);
    });

    test('한 장뿐이면 그대로 돌려준다', () {
      final ReferenceItem only = makeItem('only');
      final List<ReferenceItem> result = sortBySimilarity(<ReferenceItem>[only]);
      expect(result.map((ReferenceItem i) => i.id).toList(), <String>['only']);
    });
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/utils/similarity_test.dart
```

Expected: FAIL — `similarity.dart` 파일이 없어서 import 오류가 납니다.

- [ ] **Step 3: 구현합니다**

`lib/utils/similarity.dart`:

```dart
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
```

- [ ] **Step 4: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/utils/similarity_test.dart
```

Expected: 모든 테스트 PASS (26개)

- [ ] **Step 5: 커밋**

```bash
git add lib/utils/similarity.dart test/utils/similarity_test.dart
git commit -m "유사도 계산 순수 함수(자카드·해밍거리·similarityScore)를 만든다"
```

---

### Task 2: dHash(퍼셉추얼 해시) 계산

**Files:**
- Create: `lib/services/image_hash.dart`
- Test: `test/services/image_hash_test.dart`

**Interfaces:**
- Consumes: `package:image/image.dart`(이미 의존성에 있음, `image_resizer.dart`가 이미 씀)
- Produces: `String? dHashFromBytes(Uint8List bytes)` — Task 3(백필)과 Task 4(들여오기 연결)가 씁니다.

- [ ] **Step 1: 실패하는 테스트를 먼저 씁니다**

`test/services/image_hash_test.dart`:

```dart
// dHash(퍼셉추얼 해시) 계산이 맞는지 확인하는 테스트입니다.
// test/services/image_resize_test.dart와 같은 방식으로, 실제 사진 파일
// 없이 image 패키지로 즉석에서 테스트용 이미지를 만들어 씁니다.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reference_archive_app/services/image_hash.dart';
import 'package:reference_archive_app/utils/similarity.dart';

void main() {
  /// 왼쪽 절반은 [leftGray], 오른쪽 절반은 [rightGray] 밝기로 채운
  /// 테스트용 이미지를 만듭니다. 그레이스케일이라 r=g=b로 채웁니다.
  Uint8List makeHalfSplitImage({
    required int leftGray,
    required int rightGray,
    int width = 100,
    int height = 80,
  }) {
    final img.Image image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int gray = x < width ~/ 2 ? leftGray : rightGray;
        image.setPixelRgb(x, y, gray, gray, gray);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test('64비트(글자 64개) 문자열을 돌려준다', () {
    final Uint8List bytes = makeHalfSplitImage(leftGray: 0, rightGray: 255);
    final String? hash = dHashFromBytes(bytes);
    expect(hash, isNotNull);
    expect(hash!.length, 64);
    expect(hash.split('').every((String c) => c == '0' || c == '1'), isTrue);
  });

  test('같은 이미지면 해밍 거리가 0이다', () {
    final Uint8List bytes = makeHalfSplitImage(leftGray: 30, rightGray: 200);
    final String? hashA = dHashFromBytes(bytes);
    final String? hashB = dHashFromBytes(bytes);
    expect(hammingDistance(hashA, hashB), 0);
  });

  test('밝기가 뚜렷하게 반대인 이미지는 해밍 거리가 크다', () {
    // 왼쪽이 어둡고 오른쪽이 밝은 이미지 vs 그 반대.
    // dHash는 "가로로 인접한 픽셀 중 어느 쪽이 더 밝은가"를 비트로 담으므로,
    // 밝기 순서가 뒤집히면 대부분의 비트가 뒤집힙니다.
    final Uint8List a = makeHalfSplitImage(leftGray: 0, rightGray: 255);
    final Uint8List b = makeHalfSplitImage(leftGray: 255, rightGray: 0);

    final String? hashA = dHashFromBytes(a);
    final String? hashB = dHashFromBytes(b);

    final int? distance = hammingDistance(hashA, hashB);
    expect(distance, isNotNull);
    // 완전히 같은 밝기 구간 경계에서만 같을 수 있으니 절반 이상 다르면
    // "뚜렷하게 다르다"고 봅니다.
    expect(distance!, greaterThan(30));
  });

  test('그림 파일이 아니면 null을 돌려준다', () {
    final Uint8List notAnImage = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    expect(dHashFromBytes(notAnImage), isNull);
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/services/image_hash_test.dart
```

Expected: FAIL — `image_hash.dart` 파일이 없어서 import 오류가 납니다.

- [ ] **Step 3: 구현합니다**

`lib/services/image_hash.dart`:

```dart
// 이미지의 퍼셉추얼 해시(dHash)를 계산하는 곳입니다.
//
// ── dHash가 무엇인가 ──
// 이미지를 아주 작게(9x8) 축소한 뒤, 가로로 인접한 픽셀끼리 밝기를
// 비교해서 64비트(0/1 64개) "지문"을 만듭니다. 픽셀이 완전히 같지 않아도
// 시각적으로 비슷한 이미지끼리는 비슷한 비트 패턴이 나옵니다. 두 해시가
// 몇 비트 다른지(해밍 거리)로 "얼마나 비슷한가"를 잽니다.
// (해밍 거리 계산과 이걸 유사도 점수에 반영하는 곳은 utils/similarity.dart)
//
// ── 왜 CORS 걱정이 없나 ──
// 기존 웹앱은 브라우저 <canvas>로 이 계산을 했어서 외부 이미지가 CORS에
// 막히면 계산이 실패했습니다. 이 앱은 이미지가 전부 로컬 파일이라 그런
// 걱정이 없습니다. 대신 파일이 깨졌을 가능성은 여전히 있어서 실패하면
// null을 돌려줍니다.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 해시를 만들 때 축소하는 가로/세로 크기입니다.
/// 가로가 세로보다 1 더 큰 이유: 가로로 인접한 픽셀을 비교해서 비트를
/// 만들기 때문에, 8칸을 비교하려면 9개의 픽셀이 필요합니다.
const int dHashWidth = 9;
const int dHashHeight = 8;

/// 이미지 데이터에서 dHash(64비트 문자열)를 계산합니다.
/// 그림 파일이 아니거나 깨진 파일이면 null을 돌려줍니다.
String? dHashFromBytes(Uint8List bytes) {
  final img.Image? decoded = _tryDecode(bytes);
  if (decoded == null) {
    return null;
  }

  // 가로세로 비율은 무시하고 강제로 9x8에 맞춥니다. 해시를 만드는 데는
  // 원본 비율이 중요하지 않고, 비교하는 두 이미지가 항상 같은 방식으로
  // 눌려야 공정하게 비교할 수 있습니다.
  final img.Image resized = img.copyResize(
    decoded,
    width: dHashWidth,
    height: dHashHeight,
  );

  final StringBuffer bits = StringBuffer();
  for (int y = 0; y < dHashHeight; y++) {
    for (int x = 0; x < dHashWidth - 1; x++) {
      final double left = _luminance(resized.getPixel(x, y));
      final double right = _luminance(resized.getPixel(x + 1, y));
      bits.write(left > right ? '1' : '0');
    }
  }
  return bits.toString();
}

/// 픽셀 하나의 밝기를 구합니다. 사람 눈이 초록에 더 민감하다는 것을
/// 반영한 가중치입니다(기존 웹앱과 동일한 값).
double _luminance(img.Pixel pixel) {
  return 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
}

/// 이미지 데이터를 읽어봅니다. 읽지 못하면 null을 돌려줍니다.
/// (image_resizer.dart의 _tryDecode와 같은 이유로 try/catch로 감쌉니다 —
/// decodeImage는 그림이 아닌 데이터를 넣으면 오류를 내며 터질 수 있습니다)
img.Image? _tryDecode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/services/image_hash_test.dart
```

Expected: 모든 테스트 PASS (4개)

- [ ] **Step 5: 커밋**

```bash
git add lib/services/image_hash.dart test/services/image_hash_test.dart
git commit -m "dHash(퍼셉추얼 해시) 계산 함수를 만든다"
```

---

### Task 3: pHash 백필 (이미 있는 레퍼런스 채우기)

**Files:**
- Create: `lib/services/phash_backfill.dart`
- Test: `test/services/phash_backfill_test.dart`

**Interfaces:**
- Consumes: `dHashFromBytes`(Task 2), `ReferenceRepository`(`getAll()`, `save()` — 이미 있음), `ImageStorage`(`getFullPath()` — 이미 있음)
- Produces: `Future<void> backfillMissingPHashes({required ReferenceRepository repository, required ImageStorage imageStorage})` — Task 6이 씁니다.

- [ ] **Step 1: 실패하는 테스트를 먼저 씁니다**

`test/services/phash_backfill_test.dart`:

```dart
// pHash가 없는 레퍼런스를 채우는 백필 로직을 확인하는 테스트입니다.
//
// 진짜 이미지 파일이 필요해서(dHashFromBytes가 실제로 읽어야 합니다)
// migration 테스트들처럼 임시 폴더에 진짜 파일을 만들어 씁니다.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/services/image_storage.dart';
import 'package:reference_archive_app/services/phash_backfill.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

/// 실제 파일 시스템의 한 폴더를 가리키는 간단한 이미지 저장소입니다.
/// saveImage/deleteImageFile은 이 테스트에서 안 씁니다.
class _DiskImageStorage implements ImageStorage {
  _DiskImageStorage(this.directory);

  final Directory directory;

  @override
  Future<String> getFullPath(String fileName) async {
    return '${directory.path}/$fileName';
  }

  @override
  Future<String?> saveImage(Uint8List originalBytes) async {
    throw UnimplementedError('이 테스트에서는 안 씁니다');
  }

  @override
  Future<void> deleteImageFile(String fileName) async {}
}

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late Directory tempDir;
  late _DiskImageStorage imageStorage;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    tempDir = await Directory.systemTemp.createTemp('phash_backfill_test');
    imageStorage = _DiskImageStorage(tempDir);
  });

  tearDown(() async {
    await db.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  /// 임시 폴더 안에 진짜 이미지 파일을 하나 만들어 파일 이름을 돌려줍니다.
  Future<String> writeTestImage(String fileName) async {
    final img.Image image = img.Image(width: 20, height: 20);
    for (int y = 0; y < 20; y++) {
      for (int x = 0; x < 20; x++) {
        image.setPixelRgb(x, y, x < 10 ? 0 : 255, 0, 0);
      }
    }
    final Uint8List bytes = Uint8List.fromList(img.encodePng(image));
    await File('${tempDir.path}/$fileName').writeAsBytes(bytes);
    return fileName;
  }

  /// 테스트용 레퍼런스를 저장하고 돌려줍니다.
  Future<ReferenceItem> saveReference({String? fileName, String? pHash}) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      fileName: fileName,
      pHash: pHash,
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  test('pHash가 없는 레퍼런스를 채운다', () async {
    final String fileName = await writeTestImage('a.png');
    await saveReference(fileName: fileName);

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.first.pHash, isNotNull);
    expect(items.first.pHash!.length, 64);
  });

  test('이미 pHash가 있으면 안 건드린다', () async {
    const String existing = 'already-there';
    final String fileName = await writeTestImage('b.png');
    await saveReference(fileName: fileName, pHash: existing);

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.first.pHash, existing);
  });

  test('사진 파일이 없는 레퍼런스(유튜브 등)는 조용히 건너뛴다', () async {
    await saveReference(fileName: null);

    // 오류 없이 끝나야 합니다.
    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.first.pHash, isNull);
  });

  test('파일이 실제로 없으면(깨진 경로 등) 조용히 건너뛴다', () async {
    await saveReference(fileName: 'no-such-file.png');

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.first.pHash, isNull);
  });

  test('여러 장을 한 번에 채운다', () async {
    final String fileA = await writeTestImage('a.png');
    final String fileB = await writeTestImage('c.png');
    await saveReference(fileName: fileA);
    await saveReference(fileName: fileB);

    await backfillMissingPHashes(repository: repository, imageStorage: imageStorage);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.every((ReferenceItem i) => i.pHash != null), isTrue);
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/services/phash_backfill_test.dart
```

Expected: FAIL — `phash_backfill.dart` 파일이 없어서 import 오류가 납니다.

- [ ] **Step 3: 구현합니다**

`lib/services/phash_backfill.dart`:

```dart
// 이미 저장돼 있지만 아직 pHash가 없는 레퍼런스를 찾아 채우는 곳입니다.
//
// ── 언제 부르나 ──
// 앱을 켤 때 화면 뒤에서 한 번 조용히 돌립니다(screens/home_screen.dart의
// initState). 새로 추가하는 레퍼런스는 이미 들여오는 순간에 계산되므로
// (services/reference_importer.dart) 여기서 다시 볼 필요가 없습니다 —
// 이 함수는 "예전에 만들어져서 pHash가 비어있는" 것들만 대상으로 합니다.
//
// ── 실패해도 다시 시도합니다 ──
// 파일이 깨졌거나 없어서 계산에 실패한 레퍼런스는 pHash가 계속 null로
// 남고, 다음에 앱을 켤 때 또 시도합니다. 별도의 "포기" 표시를 두지
// 않습니다 — 그림 파일이 나중에 복구될 수도 있고, 매번 다시 시도해도
// 실패한 것들만 스치듯 다시 읽어보는 정도라 크게 부담스럽지 않습니다.

import 'dart:io';

import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import 'image_hash.dart';
import 'image_storage.dart';

/// pHash가 없는 레퍼런스를 전부 찾아 계산해서 채웁니다.
Future<void> backfillMissingPHashes({
  required ReferenceRepository repository,
  required ImageStorage imageStorage,
}) async {
  final List<ReferenceItem> items = await repository.getAll();

  for (final ReferenceItem item in items) {
    if (item.pHash != null) {
      continue;
    }

    final String? fileName = item.fileName;
    if (fileName == null) {
      // 유튜브인데 썸네일을 못 받아온 경우 등, 사진 자체가 없습니다.
      continue;
    }

    try {
      final String path = await imageStorage.getFullPath(fileName);
      final List<int> bytes = await File(path).readAsBytes();
      final String? hash = dHashFromBytes(Uint8List.fromList(bytes));
      if (hash == null) {
        continue;
      }
      await repository.save(item.copyWith(pHash: hash));
    } catch (_) {
      // 파일이 없거나 읽는 중 문제가 생겨도 나머지 레퍼런스는 계속
      // 채워야 하므로 여기서 조용히 넘어갑니다.
      continue;
    }
  }
}
```

`Uint8List`를 쓰므로 파일 맨 위 import에 `dart:typed_data`도 추가해야 합니다:

```dart
import 'dart:typed_data';
```

- [ ] **Step 4: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/services/phash_backfill_test.dart
```

Expected: 모든 테스트 PASS (5개)

- [ ] **Step 5: 커밋**

```bash
git add lib/services/phash_backfill.dart test/services/phash_backfill_test.dart
git commit -m "pHash가 없는 기존 레퍼런스를 채우는 백필 기능을 만든다"
```

---

### Task 4: 새 레퍼런스를 들여올 때 dHash 계산

**Files:**
- Modify: `lib/services/reference_importer.dart`
- Test: `test/services/reference_importer_hash_test.dart`

**Interfaces:**
- Consumes: `dHashFromBytes`(Task 2)
- Produces: 없음(저장되는 `ReferenceItem.pHash`가 채워진다는 것 자체가 결과물)

- [ ] **Step 1: 실패하는 테스트를 먼저 씁니다**

이 파일은 지금까지 전담 단위 테스트가 없었습니다(화면 테스트를 통해서만
간접적으로 확인됨). 이번에 추가하는 동작만 다루는 작은 테스트 파일을
새로 만듭니다. `saveYoutube`와 `importFromClipboard`는 플러그인(파일
선택 창 등)을 안 거치는 공개 메서드라 직접 부를 수 있습니다.

`test/services/reference_importer_hash_test.dart`:

```dart
// 레퍼런스를 새로 들여올 때 dHash가 함께 계산되어 저장되는지 확인하는
// 테스트입니다. 이미 있는 화면 테스트들(home_youtube_test.dart 등)이
// ReferenceImporter를 화면을 통해 간접적으로 쓰고 있어서, 여기서는 이번에
// 추가한 "저장할 때 pHash를 계산한다" 동작만 집중해서 봅니다.

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/services/image_hash.dart';
import 'package:reference_archive_app/services/reference_importer.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';

import '../fakes/fake_image_source.dart';
import '../fakes/fake_image_storage.dart';
import '../fakes/fake_youtube_info_source.dart';

void main() {
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late FakeImageSource imageSource;
  late FakeImageStorage imageStorage;
  late FakeYoutubeInfoSource youtubeInfoSource;
  late ReferenceImporter importer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalReferenceRepository(db);
    imageSource = FakeImageSource();
    imageStorage = FakeImageStorage();
    youtubeInfoSource = FakeYoutubeInfoSource();
    importer = ReferenceImporter(
      repository: repository,
      imageStorage: imageStorage,
      imageSource: imageSource,
      youtubeInfoSource: youtubeInfoSource,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// 진짜 이미지 데이터(PNG)를 만듭니다. dHashFromBytes가 계산할 수
  /// 있어야 하므로 [1,2,3] 같은 가짜 바이트가 아니라 실제 그림이어야 합니다.
  Uint8List makeRealImageBytes() {
    final img.Image image = img.Image(width: 20, height: 20);
    for (int y = 0; y < 20; y++) {
      for (int x = 0; x < 20; x++) {
        image.setPixelRgb(x, y, x < 10 ? 0 : 255, 100, 50);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test('클립보드에서 붙여넣은 이미지는 pHash가 계산되어 저장된다', () async {
    imageSource.hasClipboardImage = true;
    imageSource.bytes = makeRealImageBytes();

    await importer.importFromClipboard(partId: defaultPartId);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.pHash, dHashFromBytes(imageSource.bytes));
  });

  test('유튜브 썸네일도 pHash가 계산되어 저장된다', () async {
    // hasThumbnail은 기본값(true)을 그대로 둡니다 — thumbnailBytes 필드는
    // Uint8List(널 불가)라서 값만 실제 이미지로 바꿔주면 됩니다.
    youtubeInfoSource.thumbnailBytes = makeRealImageBytes();

    await importer.saveYoutube('dQw4w9WgXcQ', partId: defaultPartId);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.pHash, dHashFromBytes(youtubeInfoSource.thumbnailBytes));
  });

  test('그림이 아닌 데이터를 붙여넣어도 저장은 되고 pHash만 비어있다', () async {
    imageSource.hasClipboardImage = true;
    imageSource.bytes = Uint8List.fromList(<int>[1, 2, 3]);

    // FakeImageStorage.saveImage는 실제로 디코드하지 않아서 그대로
    // "저장된 척"하지만, dHashFromBytes는 진짜로 디코드를 시도하다
    // 실패해서 null을 돌려줘야 합니다.
    await importer.importFromClipboard(partId: defaultPartId);

    final List<ReferenceItem> items = await repository.getAll();
    expect(items.length, 1);
    expect(items.first.pHash, isNull);
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/services/reference_importer_hash_test.dart
```

Expected: FAIL — 아직 `pHash`를 계산해서 넣지 않으므로
`items.first.pHash`가 `null`이라 `dHashFromBytes(...)`(null이 아닌 값)와
다릅니다.

- [ ] **Step 3: `reference_importer.dart`를 고칩니다**

파일 맨 위 import 목록에 추가:

```dart
import 'image_hash.dart';
```

`saveYoutube` 안(현재 "썸네일은 있으면 저장하고" 블록 다음, `repository.save(...)` 호출부 근처)에서, `ReferenceItem(...)` 생성자에 `pHash` 인자를 추가합니다:

```dart
      final DateTime now = DateTime.now().toUtc();
      await repository.save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.youtube,
          title: info.title,
          fileName: savedFileName,
          partId: partId,
          youtubeVideoId: videoId,
          // 썸네일이 있으면 그 자리에서 dHash도 계산해둡니다. 시각적
          // 유사도(services/utils/similarity.dart)에 씁니다.
          pHash: thumbnail == null ? null : dHashFromBytes(thumbnail),
          createdAt: now,
          updatedAt: now,
        ),
      );
```

`_saveImageBytes` 안(현재 `savedFileName`을 구한 다음, `repository.save(...)` 호출부)에서도 마찬가지로 추가합니다:

```dart
      final DateTime now = DateTime.now().toUtc();
      await repository.save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.image,
          title: title ?? '',
          fileName: savedFileName,
          partId: partId,
          // 원본 바이트로 dHash를 계산해둡니다. 저장하며 줄인 크기가
          // 아니라 원본을 쓰는 이유: 어차피 9x8까지 줄여서 비교하므로
          // 결과가 달라지지 않고, 저장 파일을 다시 읽는 디스크 접근을
          // 아낄 수 있습니다.
          pHash: dHashFromBytes(bytes),
          createdAt: now,
          updatedAt: now,
        ),
      );
```

- [ ] **Step 4: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/services/reference_importer_hash_test.dart
```

Expected: 모든 테스트 PASS (3개)

- [ ] **Step 5: 기존 화면 테스트들도 여전히 통과하는지 확인합니다**

```bash
flutter test test/screens/home_youtube_test.dart test/screens/home_paste_test.dart
```

Expected: 전부 PASS (이 변경으로 저장되는 값이 하나 늘 뿐, 기존 동작은
그대로입니다)

- [ ] **Step 6: `flutter analyze`가 깨끗한지 확인합니다**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 7: 커밋**

```bash
git add lib/services/reference_importer.dart test/services/reference_importer_hash_test.dart
git commit -m "레퍼런스를 새로 들여올 때 dHash를 함께 계산해 저장한다"
```

---

### Task 5: "유사한 것끼리" 정렬 옵션

**Files:**
- Modify: `lib/models/reference_query.dart`
- Modify: `lib/repositories/local_reference_repository.dart`
- Test: `test/repositories/local_reference_repository_test.dart` (기존 파일에 추가)

**Interfaces:**
- Consumes: `sortBySimilarity`(Task 1)
- Produces: `ReferenceSortOrder.similar` — 위쪽 정렬 메뉴(`lib/widgets/reference_filter_bar.dart`)가 `ReferenceSortOrder.values`를 그대로 순회해서 그리므로, 이 값만 추가하면 **화면 쪽은 따로 안 고쳐도 메뉴에 자동으로 나타납니다.**

- [ ] **Step 1: 실패하는 테스트를 먼저 씁니다**

이 파일은 지금 `ReferenceQuery`/`ReferenceSortOrder`를 안 씁니다. 파일
맨 위 import 목록(`import 'package:reference_archive_app/repositories/local_reference_repository.dart';` 다음 줄)에 추가하세요:

```dart
import 'package:reference_archive_app/models/reference_query.dart';
```

그런 다음 `test/repositories/local_reference_repository_test.dart` 맨
아래(파일의 마지막 `});` 앞, 기존 `group(...)`들과 같은 위치)에 새 그룹을
추가합니다. `db`/`repository`는 파일 위쪽 `setUp`에서 이미 만들어둔
것을 그대로 씁니다.

```dart
  group('유사한 것끼리 정렬', () {
    test('태그가 겹치는 항목이 앞으로 온다', () async {
      final DateTime now = DateTime.now().toUtc();

      final ReferenceItem anchor = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>['sunset'],
        createdAt: now,
        updatedAt: now,
      );
      final ReferenceItem similar = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>['sunset'],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      );
      final ReferenceItem unrelated = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>['architecture'],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      await repository.save(unrelated);
      await repository.save(similar);
      await repository.save(anchor); // 가장 최근 -> 기준점

      final List<ReferenceItem> result = await repository.search(
        const ReferenceQuery(sortOrder: ReferenceSortOrder.similar),
      );

      expect(result.map((ReferenceItem i) => i.id).toList(), <String>[
        anchor.id,
        similar.id,
        unrelated.id,
      ]);
    });

    test('핀 고정된 항목은 유사도와 무관하게 맨 위에 남는다', () async {
      final DateTime now = DateTime.now().toUtc();

      final ReferenceItem pinnedButUnrelated = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>['architecture'],
        isPinned: true,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      );
      final ReferenceItem anchor = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        tagIds: <String>['sunset'],
        createdAt: now,
        updatedAt: now,
      );

      await repository.save(anchor);
      await repository.save(pinnedButUnrelated);

      final List<ReferenceItem> result = await repository.search(
        const ReferenceQuery(sortOrder: ReferenceSortOrder.similar),
      );

      expect(result.first.id, pinnedButUnrelated.id);
    });
  });
```

- [ ] **Step 2: 테스트가 실패하는지 확인합니다**

```bash
flutter test test/repositories/local_reference_repository_test.dart
```

Expected: FAIL — `ReferenceSortOrder.similar`가 아직 없어서 컴파일 오류가
납니다.

- [ ] **Step 3: `reference_query.dart`에 정렬 옵션을 추가합니다**

`lib/models/reference_query.dart`의 `ReferenceSortOrder` 열거형
(14~31번째 줄)에 값을 하나 추가합니다:

```dart
enum ReferenceSortOrder {
  /// 최근에 고친 것부터
  recentlyUpdated('최근 수정순'),

  /// 최근에 추가한 것부터
  recentlyAdded('최근 추가순'),

  /// 예전에 추가한 것부터
  oldestAdded('오래된 순'),

  /// 제목 가나다순
  titleAscending('제목순'),

  /// 가장 최근에 추가한 항목을 기준으로, 비슷한 것끼리 모아서
  /// (utils/similarity.dart의 sortBySimilarity 참고)
  similar('유사한 것끼리');

  const ReferenceSortOrder(this.displayName);

  /// 화면에 보여줄 한국어 이름
  final String displayName;
}
```

- [ ] **Step 4: `local_reference_repository.dart`를 고칩니다**

파일 맨 위 import 목록에 추가:

```dart
import '../utils/similarity.dart';
```

`_orderingFor` 함수(155~174번째 줄 부근)의 `switch`에 케이스를
추가합니다. SQL로는 유사도를 표현할 수 없으므로, **가장 최근에 추가한
순서로 가져온 뒤 Dart에서 다시 정렬**합니다(아래 `search()` 수정과
짝입니다):

```dart
      case ReferenceSortOrder.titleAscending:
        return ($ReferencesTable t) =>
            OrderingTerm(expression: t.title, mode: OrderingMode.asc);

      case ReferenceSortOrder.similar:
        // 유사도는 SQL로 표현할 수 없어서, 일단 최근 추가한 순서로
        // 가져온 뒤 search()에서 Dart 쪽으로 다시 정렬합니다.
        return ($ReferencesTable t) =>
            OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc);
```

`search()` 함수(50~118번째 줄 부근)에서, `result`를 다 채운 뒤
`return result;`로 끝나는 부분을 찾아 이렇게 바꿉니다:

```dart
    final List<ReferenceItem> result = <ReferenceItem>[];
    for (final ReferenceRow row in rows) {
      result.add(await _toModel(row));
    }

    // "유사한 것끼리"는 SQL로 못 하므로 여기서 다시 정렬합니다.
    // 핀 고정된 항목은 유사도 정렬 대상에서 빼고, 이미 SQL이 맨 앞에
    // 모아준 순서를 그대로 둡니다 — "정렬을 바꿔도 고정한 건 항상 위"
    // 규칙을 유사도 정렬에도 지키기 위해서입니다.
    if (query.sortOrder == ReferenceSortOrder.similar) {
      final List<ReferenceItem> pinned = result
          .where((ReferenceItem item) => item.isPinned)
          .toList();
      final List<ReferenceItem> rest = result
          .where((ReferenceItem item) => !item.isPinned)
          .toList();
      return <ReferenceItem>[...pinned, ...sortBySimilarity(rest)];
    }

    return result;
  }
```

(기존에 `return result;` 한 줄이었던 자리를 위 블록으로 통째로
바꿉니다 — `search()` 함수를 닫는 `}`는 그대로 유지됩니다.)

- [ ] **Step 5: 테스트가 통과하는지 확인합니다**

```bash
flutter test test/repositories/local_reference_repository_test.dart
```

Expected: 이 파일의 모든 테스트 PASS (새로 추가한 2개 포함)

- [ ] **Step 6: 다른 정렬 관련 테스트도 여전히 통과하는지 확인합니다**

```bash
flutter test
```

Expected: 전체 PASS (특히 `home_search_test.dart`처럼 정렬 메뉴를 쓰는
화면 테스트가 있다면 `ReferenceSortOrder.values`를 순회하는 곳에서
새 옵션이 나타나 개수가 안 맞는 것으로 깨지는지 확인 — 깨진다면 그
테스트가 정렬 옵션 "정확히 4개" 같은 식으로 하드코딩돼 있다는 뜻이니,
개수 대신 필요한 라벨이 있는지로 확인하도록 고치세요)

- [ ] **Step 7: `flutter analyze`가 깨끗한지 확인합니다**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 8: 커밋**

```bash
git add lib/models/reference_query.dart lib/repositories/local_reference_repository.dart test/repositories/local_reference_repository_test.dart
git commit -m "목록에 '유사한 것끼리' 정렬 옵션을 추가한다"
```

---

### Task 6: 앱을 켤 때 pHash 백필 실행 + 검증 + 문서화 + PR

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `CLAUDE.md`
- Modify: `update.md`

**Interfaces:**
- Consumes: `backfillMissingPHashes`(Task 3)
- Produces: 없음(마무리 태스크)

- [ ] **Step 1: `home_screen.dart`에 백필을 연결합니다**

`initState()`(233~243번째 줄 부근)에서, 기존 `_loadTaxonomyOptions();`와
`_loadItems();` 호출 다음에 한 줄을 추가합니다:

```dart
  @override
  void initState() {
    super.initState();

    // 검색창에 글자가 바뀔 때마다 알림을 받습니다.
    _searchController.addListener(_onSearchTextChanged);

    _loadTaxonomyOptions();
    _loadItems();

    // 예전에 만들어져서 아직 pHash가 없는 레퍼런스를 화면 뒤에서 조용히
    // 채웁니다. 새로 추가하는 레퍼런스는 들여오는 순간 이미 계산되므로
    // (services/reference_importer.dart) 여기서는 그 전에 만들어진
    // 것들만 대상이 됩니다. 결과를 기다리지 않고(await 없이) 그냥
    // 던져둡니다 — 화면이 뜨는 걸 늦출 이유가 없고, 다 채워지고 나면
    // 다음에 "유사한 것끼리"로 정렬하거나 화면을 다시 열 때 반영됩니다.
    backfillMissingPHashes(
      repository: widget.repository,
      imageStorage: widget.imageStorage,
    );
  }
```

파일 맨 위 import 목록에 추가합니다(다른 `services/` import들 근처):

```dart
import '../services/phash_backfill.dart';
```

- [ ] **Step 2: 홈 화면 테스트가 여전히 통과하는지 확인합니다**

```bash
flutter test test/screens/
```

Expected: 전부 PASS. `FakeImageStorage.getFullPath`가 존재하지 않는
가짜 경로를 돌려주므로, 백필은 파일을 못 읽어 조용히 아무것도 안 하고
끝납니다(예외가 화면 테스트를 깨뜨리지 않아야 합니다 — Task 3의
`backfillMissingPHashes`가 `try/catch`로 이미 이걸 처리해뒀습니다).

- [ ] **Step 3: 전체 테스트를 돌립니다**

```bash
flutter test
```

Expected: 전부 PASS

- [ ] **Step 4: 정적 분석을 돌립니다**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Windows 빌드를 확인합니다**

```bash
flutter build windows
```

Expected: 빌드 성공

- [ ] **Step 6: 빌드된 앱을 실제로 켜서 확인합니다**

레퍼런스가 여러 장 있는 상태(없다면 몇 장 추가)에서:
- 정렬 메뉴에 "유사한 것끼리"가 나타나는지
- 태그가 겹치는 레퍼런스들이 실제로 가까이 모이는지
- 비슷한 사진(같은 인물/색감 등)을 몇 장 넣었을 때, pHash 계산이 실제로
  그 사진들을 가깝게 묶어주는지(눈으로 대략 확인)

문제가 있으면 여기서 고치고 Step 3부터 다시 확인합니다.

- [ ] **Step 7: `CLAUDE.md`를 갱신합니다**

"개발 단계" 표에서 6단계 줄을 찾아 이번 범위(엔진 + 정렬)만큼 갱신하고,
5단계처럼 "이렇게 되어 있습니다" 설명 블록을 추가합니다. 다음 내용을
포함하세요: 가중치를 기존 웹앱에서 그대로 가져왔다는 것과 그 출처,
dHash가 9x8 강제 리사이즈 방식이라는 것, `pHash`는 저장 구조 변경 없이
이미 있던 칸을 채우는 것뿐이라는 것, "비슷한 레퍼런스" 화면 섹션은
다음 PR로 미뤘다는 것.

- [ ] **Step 8: `update.md`에 PR 항목을 추가합니다**

가장 최근 PR 항목 뒤에 `---` 구분선과 함께 새 항목을 추가합니다. 이
프로젝트의 기존 PR 항목들과 같은 형식(무엇을 했나 / 주요 결정 하위
섹션들 / 어떻게 확인했나 / 알고 있는 한계 / 새로 나온 개념)으로,
Task 1~6에서 실제로 한 일을 정확하게 적습니다. 특히 다음을 짚으세요:
- 가중치·dHash 방식은 기존 웹앱 PR #12를 그대로 이식했다는 것
- "핀 고정 항상 위" 규칙을 유사도 정렬에도 지키기 위해 SQL이 아니라
  Dart에서 재정렬한다는 것과 그 이유
- "비슷한 레퍼런스" 상세 화면 섹션은 다음 PR로 미뤘다는 것(알고 있는
  한계로)

- [ ] **Step 9: 커밋 + push**

```bash
git add lib/screens/home_screen.dart CLAUDE.md update.md
git commit -m "PR 이력 기록 + pHash 백필 연결: 유사도 엔진 (6단계 1부)"
git push -u origin <브랜치 이름>
```

(브랜치는 Task 1을 시작하기 전에 `main`에서 미리 만들어뒀어야 합니다.
이 계획 문서에는 브랜치 생성 스텝을 별도로 안 넣었으니, 실행자는
Task 1의 Step 1보다 먼저 브랜치를 만드세요 — 예:
`git checkout -b similarity-engine`.)

- [ ] **Step 10: PR을 엽니다**

```bash
gh pr create --title "유사도 엔진 (6단계 1부 — 엔진 + 정렬 옵션)" --body "..."
```

PR 본문에는 Summary, 나중에 고치려면 어디를 보면 되는지
(`similarity.dart`, `image_hash.dart`, `phash_backfill.dart`), Test
plan(analyze/test/build 결과, 의뢰인 확인 여부), 새로 나온 개념(자카드
유사도, 퍼셉추얼 해시)을 CLAUDE.md 프로젝트 관례대로 적습니다.

**의뢰인의 명시적 "병합해줘" 전까지 병합하지 않고 대기합니다.**

---

## 계획 자체 점검 (self-review)

- **스펙 커버리지**: 스펙의 결정 사항 — 유사도 점수 공식(Task 1), dHash
  계산 방식(Task 2), 언제 계산하나(Task 4=저장 시점, Task 3=백필), 핀
  고정과의 관계 + Dart 쪽 재정렬(Task 5) — 전부 태스크가 있습니다.
  "비슷한 레퍼런스" 화면 섹션은 스펙에서도 명시적으로 범위 밖이라
  태스크가 없는 것이 맞습니다.
- **플레이스홀더 스캔**: "TBD", "나중에", "적절히 처리" 같은 문구 없음.
  모든 코드 스텝에 실제 코드가 있습니다. Task 4·5·6에는 정확한 파일
  이름을 실행자가 직접 한 번 확인하도록 안내하는 문장이 있는데(예:
  `FakeYoutubeInfoSource`의 필드 이름, `home_screen.dart`의 정확한
  필드 이름), 이건 플레이스홀더가 아니라 이 계획 작성 시점에 그 파일들을
  전부 다시 열어보지 않고 이름이 바뀌었을 가능성을 대비한 안전장치입니다
  — 실제 함수 시그니처·핵심 로직은 전부 구체적으로 적혀 있습니다.
- **타입 일관성**: `dHashFromBytes(Uint8List) -> String?`(Task 2)이
  Task 3·4에서 동일하게 쓰입니다. `backfillMissingPHashes({required
  ReferenceRepository repository, required ImageStorage imageStorage})`
  (Task 3)이 Task 6에서 동일한 이름·인자로 호출됩니다. `sortBySimilarity
  (List<ReferenceItem>) -> List<ReferenceItem>`(Task 1)이 Task 5에서
  동일하게 쓰입니다. `ReferenceSortOrder.similar`(Task 5)가 테스트와
  구현 양쪽에서 같은 이름입니다.
