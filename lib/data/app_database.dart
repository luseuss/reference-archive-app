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
import '../models/enums.dart';
import '../models/taxonomy_item.dart';
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
  ///   5 — BoardCards에 groupId 추가 (무드보드 카드 묶음/그룹화)
  @override
  int get schemaVersion => 5;

  /// 데이터베이스를 처음 만들 때, 그리고 구조가 바뀌었을 때 무엇을 할지 정합니다.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // 앱을 처음 설치했을 때: 정의된 표를 전부 만들고 기본 파트를 하나 넣습니다.
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createDefaultPart();
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

        // ── 여기만 부등호가 다릅니다: `from >= 3 && from < 5` ──
        // BoardCards 표 자체가 v3에서 처음 생겼습니다. v3보다 낮은 버전
        // (v1, v2)에서 올라오는 사용자는 바로 위 `_upgradeToVersion3`의
        // `m.createTable(boardCards)`로 이 표를 **지금 막** 만드는데,
        // `createTable`은 Dart의 표 정의(tables.dart)를 그대로 읽어서
        // 만듭니다 — 그 정의는 "v3 당시 모습"이 아니라 **지금 코드에
        // 있는 최신 모습**이라, groupId 칸이 이미 들어간 채로 만들어집니다.
        //
        // 그 상태에서 addColumn(groupId)를 또 하면 "칸이 이미 있다"는
        // 오류가 납니다(실제로 테스트가 이렇게 잡았습니다). 그래서
        // **표가 진짜 v3 모습 그대로 남아있던 사용자**(from이 3 또는
        // 4)에게만 addColumn을 합니다. from이 3보다 작으면 위에서
        // 이미 최신 모습으로 만들어졌으니 할 일이 없습니다.
        if (from >= 3 && from < 5) {
          await _upgradeToVersion5(m);
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

  /// 버전 1 → 2. 파트 기능을 위한 준비입니다.
  ///
  /// 세 가지를 순서대로 합니다.
  ///   1. References에 partId 칸을 추가합니다.
  ///   2. 기본 파트를 만듭니다.
  ///   3. **이미 있던 레퍼런스를 전부 기본 파트에 넣습니다.**
  ///
  /// 3번을 빼먹으면 업데이트한 사용자의 레퍼런스가 **어느 파트에도 안 속해서
  /// 사이드바에서 아무 파트를 골라도 안 보이게** 됩니다. 데이터가 사라진 것처럼
  /// 보이는데 실제로는 멀쩡히 있어서, 원인을 찾기 아주 어려운 종류의 문제입니다.
  Future<void> _upgradeToVersion2(Migrator m) async {
    await m.addColumn(references, references.partId);

    await _createDefaultPart();

    // partId가 비어 있는 것 = 이번 업데이트 전에 넣어둔 레퍼런스입니다.
    await (update(references)
          ..where(($ReferencesTable t) => t.partId.isNull()))
        .write(const ReferencesCompanion(partId: Value<String>(defaultPartId)));
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

  /// 버전 4 → 5. 무드보드 카드 묶음(그룹화)을 위한 준비입니다.
  ///
  /// BoardCards에 groupId 칸을 하나 추가할 뿐입니다. 기존 카드는 전부
  /// 그룹에 안 속한 상태(null)가 맞으므로, addColumn 말고는 할 일이 없습니다.
  ///
  /// **v3보다 낮은 버전에서 올라오는 사용자에게는 이 함수를 부르면 안
  /// 됩니다.** 위 `onUpgrade`의 `from >= 3 && from < 5` 조건을 보세요 —
  /// BoardCards 표를 지금 막 만드는 경우(`createTable`)에는 이 칸이
  /// 이미 들어있어서, 여기서 또 추가하면 오류가 납니다.
  Future<void> _upgradeToVersion5(Migrator m) async {
    await m.addColumn(boardCards, boardCards.groupId);
  }

  /// 기본 파트를 만듭니다. 이미 있으면 아무 일도 하지 않습니다.
  ///
  /// `insertOnConflictUpdate`가 아니라 `DoNothing`인 이유: 사용자가 기본 파트의
  /// **이름을 바꿔뒀을 수 있습니다.** 덮어쓰면 앱을 켤 때마다 이름이 '기본'으로
  /// 되돌아갑니다.
  Future<void> _createDefaultPart() async {
    final DateTime now = DateTime.now().toUtc();

    await into(taxonomyItems).insert(
      TaxonomyItemsCompanion.insert(
        id: defaultPartId,
        kind: TaxonomyKind.part.storedName,
        name: defaultPartName,
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
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
