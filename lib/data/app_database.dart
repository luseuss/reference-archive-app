// 실제 데이터베이스 파일을 열고 닫는 곳입니다.
//
// tables.dart가 "어떤 표를 만들지" 정한다면, 이 파일은 "그 표들을 담은 데이터베이스를
// 실제로 어디에 만들지"를 정합니다.
//
// 이 파일을 고친 뒤에는 반드시 아래를 실행해야 반영됩니다.
//   dart run build_runner build

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

// board.dart는 이 파일에서 직접 쓰지 않습니다. 그런데도 가져오는 이유:
// 코드 생성기가 만드는 app_database.g.dart는 이 파일의 "part"라서 **이 파일이
// 가져온 것만 볼 수 있습니다.** BoardCards 표의 기본값(defaultBoardCardWidth)이
// 생성된 코드에 그대로 들어가므로, 여기서 가져오지 않으면 "그런 이름 없다"는
// 오류가 납니다. 지우면 앱이 안 켜집니다.
import '../models/board.dart';
import 'tables.dart';

// 코드 생성기가 만들어주는 파일입니다. 빨간 줄이 떠도 build_runner를 돌리면 사라집니다.
part 'app_database.g.dart';

/// 앱의 데이터베이스입니다.
///
/// @DriftDatabase에 적은 표들이 이 데이터베이스에 들어갑니다.
/// 표를 새로 추가하면 여기 tables 목록에도 넣어야 합니다.
@DriftDatabase(
  tables: <Type>[
    References,
    TaxonomyItems,
    ReferenceTaxonomyLinks,
    Boards,
    BoardCards,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// 실제 파일에 저장되는 데이터베이스를 엽니다. 앱에서 쓰는 방식입니다.
  AppDatabase() : super(_openConnection());

  /// 메모리 안에서만 도는 데이터베이스를 엽니다. **테스트 전용입니다.**
  ///
  /// 파일을 만들지 않기 때문에 테스트가 끝나면 흔적 없이 사라지고,
  /// 테스트끼리 서로의 데이터에 영향을 주지 않습니다.
  AppDatabase.forTesting(super.connection);

  /// 데이터베이스 구조의 버전입니다.
  ///
  /// 표를 추가하거나 칸을 바꿀 때마다 이 숫자를 1 올리고, 아래 migration에
  /// "그때 무엇을 해야 하는지"를 적어야 합니다. 안 그러면 **기존 사용자의 앱이
  /// 업데이트 후 켜지지 않습니다.** (새로 설치한 사람은 멀쩡해서 놓치기 쉬운 실수입니다.)
  /// ── 버전 기록 ──
  ///   1 — 처음 만든 구조
  ///   2 — References에 partId 추가 (파트 기능). PR #16
  ///   3 — Boards, BoardCards 표 추가 (무드보드). PR #17
  ///   4 — References.memo를 순수 텍스트에서 Delta(JSON)로. 5단계 1번
  ///   5 — Boards에 folderId 추가 (무드보드를 폴더/프로젝트에 연결)
  ///   6 — 파트(Part) 개념을 없앰. References.partId 칼럼 삭제,
  ///       taxonomy_items의 kind='part' 행 삭제
  @override
  int get schemaVersion => 6;

  /// 데이터베이스를 처음 만들 때, 그리고 구조가 바뀌었을 때 무엇을 할지 정합니다.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // 앱을 처음 설치했을 때: 정의된 표를 전부 만듭니다.
      onCreate: (Migrator m) async {
        await m.createAll();
      },

      // 앱을 업데이트해서 schemaVersion이 올라갔을 때 할 일입니다.
      //
      // **여기를 빠뜨리면 새로 설치한 사람은 멀쩡한데 기존 사용자의 앱만
      // 안 켜집니다.** 개발하는 사람은 대개 새로 설치한 쪽이라 놓치기 쉽습니다.
      onUpgrade: (Migrator m, int from, int to) async {
        // from = 지금 기기에 있는 버전, to = 새 버전.
        //
        // `if (from < 2)`로 쓰는 이유: 한참 업데이트를 안 한 사용자는 1에서
        // 곧장 3, 4로 건너뜁니다. `== 1`로 적으면 그런 사람이 이 단계를
        // 통째로 건너뛰게 됩니다. 부등호로 적으면 필요한 단계가 차례로 다 실행됩니다.
        if (from < 2) {
          await _upgradeToVersion2(m);
        }

        // `if (from < 3)`도 마찬가지입니다. 버전 1에 머물러 있던 사용자는
        // 위의 2단계를 먼저 거친 뒤 여기까지 이어서 실행됩니다.
        if (from < 3) {
          await _upgradeToVersion3(m);
        }

        // `if (from < 4)`도 마찬가지입니다. v1이나 v2에 머물러 있던
        // 사용자는 위 단계를 먼저 거친 뒤 여기까지 이어서 실행됩니다.
        if (from < 4) {
          await _upgradeToVersion4();
        }

        // ── 여기만 `from < 5`가 아니라 `from >= 3 && from < 5`입니다 ──
        // `createTable`(바로 위 _upgradeToVersion3)은 **지금 이 시점의
        // tables.dart**로 표를 만듭니다. v1이나 v2에서 건너뛰어 올라오는
        // 사용자는 방금 _upgradeToVersion3에서 이미 folderId가 포함된
        // boards 표를 새로 만들었으므로, 여기서 또 addColumn을 하면
        // "칼럼이 이미 있다"는 오류가 납니다. boards 표가 **이번
        // 업데이트 전부터 실제로 있던**(버전 3 또는 4) 사용자만 이
        // 칸을 추가해야 합니다.
        if (from >= 3 && from < 5) {
          await _upgradeToVersion5(m);
        }

        // v6은 반대로 "이미 있는 칼럼을 지우는" 마이그레이션이라 PR #59의
        // v5처럼 특수한 부등호 조건이 필요 없습니다. createTable이 현재
        // 시점의 tables.dart를 쓰는 문제는 "칼럼을 새로 만들 때"만
        // 생기는데, 여기서는 어차피 안 만들기 때문입니다. v1이든 v5든
        // partId가 있었던 사람이든(v1은 애초에 없었지만 v2 단계에서
        // 이미 추가되고 채워진 뒤라 v6 시점에는 모두가 갖고 있습니다)
        // 그냥 지우면 됩니다.
        if (from < 6) {
          await _upgradeToVersion6(m);
        }
      },

      // 데이터베이스를 열 때마다 실행됩니다.
      beforeOpen: (OpeningDetails details) async {
        // 외래 키 검사를 켭니다. SQLite는 이걸 기본으로 꺼두기 때문에 직접 켜야 합니다.
        // 켜두면 "존재하지 않는 폴더에 들어있는 레퍼런스" 같은 깨진 데이터를 막아줍니다.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// v1 → v2에서 만들던 "기본 파트"의 고유 번호와 이름입니다.
  ///
  /// 예전에는 `lib/models/taxonomy_item.dart`의 `defaultPartId`/
  /// `defaultPartName` 상수였습니다. schemaVersion 6에서 파트 개념을
  /// 모델에서까지 완전히 지우면서(Task 1~8) 그 상수들도 함께
  /// 지워졌습니다. `_upgradeToVersion2`는 **그 시절 실제로 썼던 값
  /// 그대로**를 다시 만들어야 하는 역사적 단계라, 지금 앱 어디에도
  /// 이 값을 아는 곳이 없어야 함에도 이 마이그레이션만은 값을 알아야
  /// 합니다. 그래서 모델로 되살리지 않고 이 파일 안에 고정값으로
  /// 남겨뒀습니다.
  static const String _legacyDefaultPartId =
      '00000000-0000-4000-8000-000000000001';
  static const String _legacyDefaultPartName = '기본';

  /// 버전 1 → 2. 파트 기능을 위한 준비입니다.
  ///
  /// 세 가지를 순서대로 합니다.
  ///   1. References에 part_id 칸을 추가합니다.
  ///   2. 기본 파트를 만듭니다.
  ///   3. **이미 있던 레퍼런스를 전부 기본 파트에 넣습니다.**
  ///
  /// 3번을 빼먹으면 업데이트한 사용자의 레퍼런스가 **어느 파트에도 안 속해서
  /// 사이드바에서 아무 파트를 골라도 안 보이게** 됩니다. 데이터가 사라진 것처럼
  /// 보이는데 실제로는 멀쩡히 있어서, 원인을 찾기 아주 어려운 종류의 문제입니다.
  ///
  /// ── (schemaVersion 6에서 덧붙임) 왜 raw SQL을 쓰는가 ──
  /// 원래 이 메서드는 `m.addColumn(references, references.partId)`,
  /// `ReferencesCompanion(partId: ...)`처럼 drift가 만들어주는 타입
  /// API와 따로 뺀 `_createDefaultPart()` 도우미를 함께 썼습니다.
  /// 그런데 schemaVersion 6에서 tables.dart의 partId 정의 자체를
  /// 지웠기 때문에, 지금 시점의 생성 코드(`$ReferencesTable`,
  /// `ReferencesCompanion`)에는 partId가 아예 없습니다 — Dart 코드로는
  /// 더 이상 이 칸을 가리킬 방법이 없다는 뜻입니다. 그래서
  /// `_upgradeToVersion4()`가 이미 쓰고 있던 것과 같은 방식(raw SQL)으로
  /// 바꿨습니다. `_createDefaultPart()`도 이 메서드 말고는 아무도 안
  /// 쓰게 되어 별도 메서드로 안 두고 이 안으로 그대로 옮겼습니다.
  ///
  /// **동작 자체는 이전과 완전히 같습니다** — v1 사용자가 이 단계를
  /// 거치면 여전히 part_id 칸이 생기고 기본 파트가 만들어지고 기존
  /// 레퍼런스가 거기 채워집니다. 몇 걸음 뒤(v6)에서 그걸 도로 지우므로,
  /// 실제로 남는 결과는 "잠깐 만들었다가 없앤 것"입니다(아래
  /// `_upgradeToVersion6` 설명 참고).
  Future<void> _upgradeToVersion2(Migrator m) async {
    await customStatement('ALTER TABLE "references" ADD COLUMN part_id TEXT');

    // `insertOrIgnore`인 이유: 만약 이미 같은 id의 기본 파트가 있다면
    // (이론상 없어야 하지만) 덮어쓰지 않고 그대로 둡니다.
    final DateTime now = DateTime.now().toUtc();
    await into(taxonomyItems).insert(
      TaxonomyItemsCompanion.insert(
        id: _legacyDefaultPartId,
        kind: 'part',
        name: _legacyDefaultPartName,
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );

    // part_id가 비어 있는 것 = 이번 업데이트 전에 넣어둔 레퍼런스입니다.
    await customStatement(
      'UPDATE "references" SET part_id = ? WHERE part_id IS NULL',
      <Object?>[_legacyDefaultPartId],
    );
  }

  /// 버전 2 → 3. 무드보드를 위한 표 두 개를 만듭니다.
  ///
  /// 이번에는 **기존 데이터를 손대지 않습니다.** 새 표를 만들기만 하면 끝입니다.
  /// 파트를 붙일 때(v2)는 이미 있던 레퍼런스를 기본 파트에 넣어줘야 했지만,
  /// 무드보드는 사용자가 직접 만들기 전에는 하나도 없는 것이 맞는 상태입니다.
  /// 빈 무드보드를 자동으로 만들어두면 만든 적 없는 것이 목록에 있어서 오히려 헷갈립니다.
  ///
  /// createTable은 표 하나를 만듭니다. onCreate의 createAll()이 "정의된 표 전부"를
  /// 만드는 것과 달리, 여기서는 **이번에 새로 생긴 표만** 콕 집어 만들어야 합니다.
  /// createAll()을 부르면 이미 있는 References 표를 또 만들려다 오류가 납니다.
  Future<void> _upgradeToVersion3(Migrator m) async {
    await m.createTable(boards);
    await m.createTable(boardCards);
  }

  /// 버전 3 → 4. 메모를 순수 텍스트에서 리치텍스트(Delta JSON)로 바꿉니다.
  ///
  /// ── 칼럼을 추가하는 게 아니라 값을 다시 씁니다 ──
  /// memo 칼럼 자체는 그대로 TEXT입니다. 안에 들어가는 내용의 뜻만
  /// "순수 글자"에서 "서식이 붙은 JSON"으로 바뀝니다. 그래서 addColumn이
  /// 아니라 update를 씁니다.
  ///
  /// memo가 비어있는(null) 레퍼런스는 손대지 않습니다 — 빈 메모는 그대로
  /// 빈 메모입니다.
  ///
  /// ── select(references)가 아니라 raw SQL을 쓰는 이유 (중요) ──
  /// `select(references).get()`은 drift가 **지금 이 앱 버전**을 기준으로
  /// 생성해둔 `ReferencesTable` 코드를 거쳐서 읽습니다. 즉 "지금 이 시점까지
  /// 나온 모든 schemaVersion의 칼럼"을 다 포함한 모양으로 읽으려 듭니다.
  ///
  /// 문제는 이 마이그레이션 함수가 실행되는 시점의 **진짜 sqlite 표**는
  /// 그 모양이 아직 아닐 수 있다는 것입니다. 예를 들어 나중에 schemaVersion
  /// 5가 addColumn으로 칼럼을 하나 더 추가한다고 하면, 버전 3에서 곧장
  /// 5로 건너뛰는 사용자의 경우 drift는 `_upgradeToVersion4()`(`if (from < 4)`)를
  /// **먼저** 실행하고, 그 다음에야 버전 5의 addColumn(`if (from < 5)`)을
  /// 실행합니다. 이 순간 실제 sqlite 표에는 아직 그 새 칼럼이 없는데,
  /// `select(references).get()`이 생성한 매핑 코드는 그 칼럼을 읽으려고
  /// 시도해서 앱이 아예 안 켜지게 됩니다 — 딱 그렇게 여러 버전을 건너뛰어
  /// 올라오는 사용자한테서만 터지므로 개발 중에는 절대 못 잡는 종류의 버그입니다
  /// (CLAUDE.md의 "옛 버전에서 여러 단계를 건너뛰어도 되는지" 항목이 경고하는
  /// 바로 그 상황).
  ///
  /// 그래서 이 시점(버전 3 → 4)에 반드시 있다고 보장되는 칼럼(id, memo —
  /// 둘 다 schemaVersion 1부터 있었습니다)만 raw SQL로 콕 집어 읽고 씁니다.
  /// `$ReferencesTable`이나 `ReferenceRow` 같은 생성 코드를 아예 거치지
  /// 않으므로, 나중에 칼럼이 몇 개가 추가되든 이 마이그레이션은 영향을
  /// 받지 않습니다.
  Future<void> _upgradeToVersion4() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT id, memo FROM "references"',
    ).get();

    for (final QueryRow row in rows) {
      final String id = row.read<String>('id');
      final String? memo = row.read<String?>('memo');

      if (memo == null || memo.isEmpty) {
        continue;
      }

      // 최소 Delta로 감쌉니다: "이 글자를 그대로 넣어라"는 명령 하나뿐인
      // 문서입니다. 새 편집기로 열면 서식 없는 원래 글자가 그대로 보입니다.
      final String delta = jsonEncode(<Map<String, String>>[
        <String, String>{'insert': '$memo\n'},
      ]);

      await customStatement(
        'UPDATE "references" SET memo = ? WHERE id = ?',
        <Object?>[delta, id],
      );
    }
  }

  /// 버전 4 → 5. 무드보드를 폴더(프로젝트)에 연결하는 칸을 추가합니다.
  ///
  /// nullable 칸을 addColumn으로 더하기만 하면 됩니다. 기존 무드보드는
  /// 전부 "아직 폴더를 안 정한" 상태(null)로 시작합니다 — 억지로
  /// 아무 폴더나 골라줄 방법이 없으므로, 사용자가 나중에
  /// 무드보드 목록 화면의 "폴더 정하기"로 직접 정하게 둡니다.
  Future<void> _upgradeToVersion5(Migrator m) async {
    await m.addColumn(boards, boards.folderId);
  }

  /// 버전 5 → 6. 파트(Part) 개념을 완전히 없앱니다.
  ///
  /// 두 가지를 합니다.
  ///   1. References.partId 칼럼을 지웁니다.
  ///   2. taxonomy_items에서 kind='part'인 행(기본 파트 포함)을 지웁니다.
  ///
  /// ── 소프트 삭제가 아니라 진짜로 지우는 이유 ──
  /// 다른 분류 항목(폴더 등)을 지울 때는 deletedAt만 찍습니다(원칙 5,
  /// 소프트 삭제) — "이 기기에서 지운 건지 다른 기기에서 새로 만든
  /// 건지" 구분해야 하기 때문입니다. 하지만 파트는 **개념 자체가
  /// 사라지는 것**이라 이 구분이 필요 없습니다. 소프트 삭제로 남겨두면
  /// 영원히 안 보이는 죽은 행만 쌓입니다.
  ///
  /// ── dropColumn이 SQLite 3.35.0을 요구합니다 ──
  /// 이 프로젝트가 쓰는 sqlite3_flutter_libs는 훨씬 최신 SQLite를
  /// 번들하므로 문제없이 될 것으로 보입니다. Task 10의 마이그레이션
  /// 테스트가 실제로 되는지 확인합니다.
  Future<void> _upgradeToVersion6(Migrator m) async {
    // dropColumn은 칼럼을 Column 객체가 아니라 **SQL 이름(문자열)**으로
    // 받습니다. tables.dart에서 partId 정의 자체를 지웠으므로
    // `references.partId`처럼 Dart 코드로는 더 이상 이 칼럼을 가리킬
    // 방법이 없습니다 — drift가 camelCase를 snake_case로 바꿔 저장하는
    // 규칙(build.yaml 옆의 다른 칼럼들과 동일)에 따라 실제 SQL 칼럼
    // 이름인 'part_id'를 직접 적습니다.
    await m.dropColumn(references, 'part_id');

    await customStatement(
      "DELETE FROM taxonomy_items WHERE kind = 'part'",
    );
  }
}

/// 데이터베이스 파일을 어디에 만들지 정합니다.
///
/// 경로를 직접 적지 않습니다. 기기마다 앱 데이터 폴더 위치가 다르기 때문에
/// 절대경로를 코드에 적어두면 안 됩니다(설계 원칙 4-4).
///
/// ── databaseDirectory를 직접 지정한 이유 ──
/// 아무것도 지정하지 않으면 drift는 getApplicationDocumentsDirectory()를 씁니다.
/// 그런데 Windows에서 그곳은 **사용자의 "문서" 폴더**입니다. 그대로 두면
/// 사용자 문서 폴더 한가운데에 reference_archive.sqlite가 툭 생깁니다.
///
/// getApplicationSupportDirectory()는 앱 전용 폴더
/// (Windows에서는 %APPDATA%\com.luseuss\reference_archive_app)를 알려줍니다.
/// 사용자 눈에 띄지 않는 곳이고, 앱을 지울 때 함께 정리되는 자리입니다.
/// 이미지 파일도 같은 곳에 저장합니다(lib/services/local_image_storage.dart).
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'reference_archive',
    native: DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
