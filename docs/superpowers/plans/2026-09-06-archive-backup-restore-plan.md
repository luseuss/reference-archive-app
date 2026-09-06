# 아카이브 백업/복원 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설정 화면에서 데이터베이스+사진 전체를 zip 파일 하나로 백업하고,
다른(또는 같은) 컴퓨터에서 그 zip을 불러와 지금 아카이브에 **합칠** 수
있게 한다.

**Architecture:** sqlite의 `VACUUM INTO`로 켜진 채로도 항상 일관된
데이터베이스 복사본을 만들고(drift `customStatement`로 호출), `archive`
패키지로 그 파일 + `images/` 폴더를 zip 하나로 묶는다. 복원은 zip을 풀어
안의 sqlite 파일을 **별도 연결**로 열고(drift의 마이그레이션이 자동으로
최신 구조로 올려줌), 표마다 "id가 없으면 추가"(`INSERT OR IGNORE`)로
지금 데이터베이스에 합친다. 이 프로젝트가 처음부터 지켜온 "모든 항목은
UUID"라는 설계 원칙 덕분에, 서로 다른 컴퓨터에서 만든 두 항목의 id가
겹칠 일이 없어서 이 방식이 안전하다.

**Tech Stack:** Flutter, drift(기존), `archive`(새로 추가, zip 만들고
풀기), `file_picker`(기존), `path_provider`(기존).

**Spec:** 별도 스펙 문서 없이(의뢰인이 "바로 계획 세워서 만들자"를
선택) 채팅에서 확정한 설계를 이 계획 문서에 그대로 옮겼습니다. 핵심
결정 세 가지:
- 복원은 **덮어쓰기가 아니라 합치기**입니다(기존 데이터는 안 사라짐).
- 복원이 끝나면 **화면을 그대로 두지 않고 앱을 다시 켜달라고 안내**합니다
  (켜진 채로 데이터베이스 연결을 바꿔치는 것은 위험함).
- 백업 파일에 **앱 설정(밝기 모드·이름)은 안 넣습니다.**

## Global Constraints

- **저장 구조를 바꾸지 않는다.** 새 칸·새 표 없음. 마이그레이션 없음.
- **백업 파일 형식**: zip 하나에 `reference_archive.sqlite`(파일 이름
  고정) + `images/` 폴더(있는 그대로)를 담는다.
- **복원은 합치기(merge)만 한다.** "지금 것을 통째로 지우고 바꿔치기"는
  이번 범위가 아니다.
- **합치기 규칙은 표마다 동일하다**: id(또는 복합키)가 지금 데이터베이스에
  이미 있으면 건너뛰고, 없으면 그대로 추가한다(`INSERT OR IGNORE`).
  이름이 같은 항목을 하나로 합쳐주지는 않는다(알려진 한계로 남긴다).
- **표를 채우는 순서**: `TaxonomyItems` → `References` →
  `ReferenceTaxonomyLinks` → `Boards` → `BoardCards`. 공식 외래키
  제약은 없지만(schema에 `.references()` 선언 없음), 개념상 부모를
  먼저 넣는 편이 안전하고 읽기도 자연스럽다.
- **화면이 있는 param을 새로 추가할 때는 선택적(nullable, 기본값
  null)으로 둔다.** `ReferenceArchiveApp`/`HomeScreen`을 직접 만드는
  기존 테스트 파일이 9개나 있다 — 필수 param으로 추가하면 전부 고쳐야
  한다. null이면 설정 화면의 "데이터 관리" 구역 자체를 안 보여준다.
- **파일 대화상자가 얽힌 부분은 위젯 테스트로 못 잡는 부류다**(이
  프로젝트의 다른 파일 저장/열기 기능들과 같은 사정 —
  `board_export_controller.dart`, `reference_importer.dart` 참고).
  그래서 서비스의 **핵심 로직**(zip 만들기, 합치기)만 파일 대화상자
  없이 직접 부를 수 있는 함수로 분리해서 자동 테스트하고, 대화상자를
  감싸는 바깥 함수는 `flutter run -d windows`로 직접 확인한다.
- **`VACUUM INTO`가 실제로 되는지, `archive` 패키지로 묶고 푼 구조가
  기대대로 나오는지는 계획을 쓰기 전에 스파이크로 이미 확인했다**(코드는
  버림). 아래 코드는 그 확인을 거친 진짜 API입니다.

---

## Task 1: 백업 만들기 — `writeBackupZip` (파일 대화상자 없는 핵심 로직)

**Files:**
- Create: `lib/services/archive_backup_service.dart`
- Test: `test/services/archive_backup_service_test.dart`

**Interfaces:**
- Produces: `class ArchiveBackupService`, 생성자
  `ArchiveBackupService(AppDatabase database)`,
  메서드 `Future<void> writeBackupZip(String zipPath)`.
  Task 2·3·4가 이 클래스를 계속 채웁니다.

- [ ] **Step 1: `archive` 패키지가 추가되어 있는지 확인한다**

이미 이 계획을 준비하며 `flutter pub add archive`를 실행해뒀습니다.
`pubspec.yaml`에 `archive: ^4.2.0` 줄이 있는지 확인만 하세요. 없다면:

```bash
flutter pub add archive
```

- [ ] **Step 2: 실패하는 테스트부터 쓴다**

`test/services/archive_backup_service_test.dart` (새 파일):

```dart
// 아카이브 백업/복원의 핵심 로직(zip 만들기·합치기)을 확인하는
// 테스트입니다. 파일 대화상자는 안 거칩니다 — createBackup()/
// restoreFromBackup()처럼 대화상자를 여는 부분은 위젯 테스트로 못
// 잡는 부류라(이 프로젝트의 다른 파일 저장 기능들과 같은 사정),
// writeBackupZip()/mergeBackupZipBytes()만 직접 부릅니다.
//
// 데이터베이스는 진짜 파일로 엽니다(NativeDatabase(File(...))).
// VACUUM INTO는 실제 파일 시스템에 파일을 쓰는 명령이라, 메모리
// 데이터베이스만으로는 이 기능의 핵심을 확인했다고 보기 어렵습니다.

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/services/archive_backup_service.dart';
import 'package:reference_archive_app/utils/id_generator.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late LocalReferenceRepository repository;
  late ArchiveBackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
    db = AppDatabase.forTesting(
      NativeDatabase(File('${tempDir.path}/live.sqlite')),
    );
    repository = LocalReferenceRepository(db);
    service = ArchiveBackupService(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 테스트용 이미지 레퍼런스를 하나 만들어 저장하고 돌려줍니다.
  Future<ReferenceItem> saveImage(String title) async {
    final DateTime now = DateTime.now().toUtc();
    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.image,
      title: title,
      fileName: '$title.jpg',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(item);
    return item;
  }

  test('백업 zip 안에 데이터베이스 파일이 들어있다', () async {
    await saveImage('노을');

    final String zipPath = '${tempDir.path}/backup.zip';
    await service.writeBackupZip(zipPath);

    expect(await File(zipPath).exists(), isTrue);

    final Archive archive = ZipDecoder().decodeBytes(
      await File(zipPath).readAsBytes(),
    );
    final ArchiveFile? sqliteEntry = archive.findFile(
      'reference_archive.sqlite',
    );
    expect(sqliteEntry, isNotNull);
  });

  test('백업한 데이터베이스를 열어보면 저장해둔 레퍼런스가 그대로 있다', () async {
    await saveImage('노을');

    final String zipPath = '${tempDir.path}/backup.zip';
    await service.writeBackupZip(zipPath);

    final Directory extractDir = Directory('${tempDir.path}/extracted');
    final Archive archive = ZipDecoder().decodeBytes(
      await File(zipPath).readAsBytes(),
    );
    await extractArchiveToDisk(archive, extractDir.path);

    final AppDatabase reopened = AppDatabase.forTesting(
      NativeDatabase(File('${extractDir.path}/reference_archive.sqlite')),
    );
    final List<ReferenceItem> items = await LocalReferenceRepository(
      reopened,
    ).getAll();
    await reopened.close();

    expect(items.single.title, '노을');
  });
}
```

- [ ] **Step 3: 테스트가 실패하는 것을 확인한다**

Run: `flutter test test/services/archive_backup_service_test.dart`
Expected: FAIL — `archive_backup_service.dart`가 아직 없어서 컴파일 오류.

- [ ] **Step 4: `ArchiveBackupService`와 `writeBackupZip`을 구현한다**

`lib/services/archive_backup_service.dart` (새 파일):

```dart
// 아카이브(데이터베이스 + 사진)를 zip 파일 하나로 백업하고, 그 zip을
// 다시 지금 아카이브에 합쳐 넣는(복원) 일을 맡습니다.
//
// ── 왜 여기 있나 ──
// repositories/는 표 하나하나를 다루지만, 백업은 데이터베이스
// 전체(모든 표)와 사진 폴더를 함께 다루는 일이라 어느 한 저장소에도
// 속하지 않습니다. services/에 두고 AppDatabase를 직접 받습니다.
//
// ── 백업 파일 형식 ──
// zip 하나 안에 다음 둘만 있습니다(앱 설정은 안 넣습니다 — 설정은
// 컴퓨터마다 따로 두는 게 자연스럽습니다).
//   reference_archive.sqlite   데이터베이스 전체
//   images/                    사진 폴더 그대로
//
// ── 데이터베이스를 어떻게 복사하나 (VACUUM INTO) ──
// 앱이 켜진 채로 sqlite 파일을 그냥 파일 복사하면, 쓰는 중인 내용이
// 걸려서 깨질 수 있습니다. sqlite의 `VACUUM INTO` 명령은 지금 켜져
// 있는 연결에서 바로 "항상 완전하고 일관된 복사본"을 새 파일로
// 만들어줍니다. drift의 customStatement()로 그 SQL을 직접 부릅니다.
//
// ── 복원은 "합치기"입니다 (통째로 바꾸기가 아닙니다) ──
// mergeBackupZipBytes()를 참고하세요.
//
// ── 파일 대화상자가 있는 부분과 없는 부분을 나눈 이유 ──
// writeBackupZip()/mergeBackupZipBytes()는 파일 대화상자 없이 경로/
// 바이트만 받아 일하므로, 화면 없이 유닛 테스트로 확인할 수 있습니다.
// createBackup()/restoreFromBackup()은 그 위에 file_picker 대화상자를
// 씌운 것으로, 진짜 운영체제 대화상자를 열려고 해서 테스트 환경에서는
// 못 씁니다(board_export_controller.dart의 저장 대화상자와 같은 사정).

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';

/// 백업 zip 안에서 데이터베이스 파일에 쓰는 이름입니다.
///
/// **`local_image_storage.dart`의 이미지 폴더 이름, `app_database.dart`의
/// 실제 sqlite 파일 이름과는 별개입니다** — 이건 zip 안에서 쓰는 이름일
/// 뿐이라 굳이 똑같을 필요는 없지만, 헷갈리지 않게 같은 이름을 씁니다.
const String _sqliteEntryName = 'reference_archive.sqlite';

/// 백업 zip 안에서 사진 폴더가 들어갈 이름입니다.
///
/// **`local_image_storage.dart`의 `_imagesFolderName`과 반드시 같아야
/// 합니다** — 실제 사진 폴더를 zip에 넣을 때 폴더의 실제 이름을 그대로
/// 쓰기 때문에, 이 폴더가 여기서 이름이 바뀌면 이 상수도 같이 고쳐야
/// 합니다.
const String _imagesFolderName = 'images';

/// 아카이브 백업을 만들고 복원하는 일을 맡습니다.
class ArchiveBackupService {
  ArchiveBackupService(this._database);

  /// 지금 켜져 있는 데이터베이스 연결입니다.
  final AppDatabase _database;

  /// 지금 데이터베이스 + 사진 폴더를 [zipPath]에 zip 파일로 만듭니다.
  ///
  /// 파일 대화상자를 안 거치는 핵심 로직입니다. 실제로 사용자에게 저장할
  /// 자리를 물어보는 일은 [createBackup]이 합니다.
  Future<void> writeBackupZip(String zipPath) async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'reference_archive_backup_',
    );

    try {
      // ── 1. 데이터베이스를 일관된 상태로 복사합니다 ──
      final String tempSqlitePath = p.join(tempDir.path, _sqliteEntryName);

      // 작은따옴표를 두 번 써서 이스케이프합니다(SQL 문자열 리터럴 규칙).
      // Windows 경로의 역슬래시는 SQL에서 특별한 뜻이 없어 그대로 써도
      // 안전합니다.
      final String escapedPath = tempSqlitePath.replaceAll("'", "''");
      await _database.customStatement("VACUUM INTO '$escapedPath'");

      // ── 2. zip으로 묶습니다 ──
      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(zipPath);

      await encoder.addFile(File(tempSqlitePath), _sqliteEntryName);

      final Directory imagesDir = await _imagesDirectory();
      if (await imagesDir.exists()) {
        // addDirectory는 폴더의 **실제 이름**을 zip 안 폴더 이름으로
        // 씁니다. images 폴더 이름이 바뀌면 이 파일 위쪽의
        // _imagesFolderName 상수도 같이 고쳐야 하는 이유입니다.
        await encoder.addDirectory(imagesDir);
      }

      await encoder.close();
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  /// 사진이 저장된 폴더를 찾습니다.
  ///
  /// local_image_storage.dart의 _getImagesDirectory()와 같은 위치를
  /// 가리키지만, 이 서비스는 ImageStorage(약속)가 아니라 실제 파일
  /// 시스템을 직접 다뤄야 하는 일이라(폴더 전체를 zip에 넣고, zip에서
  /// 풀어야 함) 독립적으로 구합니다.
  Future<Directory> _imagesDirectory() async {
    final Directory appDir = await getApplicationSupportDirectory();
    return Directory(p.join(appDir.path, _imagesFolderName));
  }
}
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run: `flutter test test/services/archive_backup_service_test.dart`
Expected: PASS (2개)

- [ ] **Step 6: `flutter analyze`로 확인한다**

Run: `flutter analyze lib/services/archive_backup_service.dart`
Expected: 이슈 없음.

- [ ] **Step 7: 커밋한다**

```bash
git add pubspec.yaml pubspec.lock lib/services/archive_backup_service.dart test/services/archive_backup_service_test.dart
git commit -m "Task 1: 백업 zip 만들기(writeBackupZip)를 구현한다"
```

---

## Task 2: 복원(합치기) — `mergeBackupZipBytes`

**Files:**
- Modify: `lib/services/archive_backup_service.dart`
- Create: `test/fakes/fake_path_provider.dart` (기존 `local_image_storage_test.dart`의
  `_FakePathProvider`를 공유 파일로 뺍니다 — 이번 테스트도 같은 기법이
  필요합니다)
- Modify: `test/services/local_image_storage_test.dart` (뺀 가짜를 가져다
  쓰도록 바꿉니다)
- Modify: `test/services/archive_backup_service_test.dart`

**Interfaces:**
- Consumes: `writeBackupZip`(Task 1, 합치기 테스트에서 백업을 만드는 데
  재사용).
- Produces: `Future<void> mergeBackupZipBytes(Uint8List zipBytes)` —
  Task 3(`restoreFromBackup`)이 이걸 그대로 부릅니다.

- [ ] **Step 1: 공유 가짜 path_provider를 뺀다**

`test/services/local_image_storage_test.dart`에서 `_FakePathProvider`
클래스 전체를 잘라내(cut) 새 파일로 옮깁니다.

`test/fakes/fake_path_provider.dart` (새 파일):

```dart
// path_provider(앱 데이터 폴더가 어디인지 운영체제에 물어보는 플러그인)
// 대신 정해둔 임시 폴더를 알려주는 가짜입니다.
//
// ── 왜 필요한가 ──
// 실제 구현은 운영체제에 물어봐야 하는데, 테스트 환경에는 대답해줄
// 상대가 없어서 영원히 기다리게 됩니다. 이 가짜를 끼워 넣으면 실제
// 파일 시스템(진짜 임시 폴더)은 그대로 쓰면서도, 컴퓨터의 진짜 앱
// 데이터 폴더는 건드리지 않는 테스트를 만들 수 있습니다.
//
// local_image_storage_test.dart와 archive_backup_service_test.dart가
// 함께 씁니다 — 둘 다 "앱 데이터 폴더 안의 실제 파일"을 다루는 코드를
// 확인해야 하기 때문입니다.

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// path_provider 대신 정해둔 폴더를 알려주는 가짜입니다.
class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => rootPath;

  @override
  Future<String?> getTemporaryPath() async => rootPath;
}
```

`test/services/local_image_storage_test.dart`에서:
- 위쪽의 `_FakePathProvider` 클래스 정의를 지웁니다.
- `import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';`
  와 `import 'package:plugin_platform_interface/plugin_platform_interface.dart';`
  import 두 줄을 지웁니다(더는 이 파일에서 안 씁니다).
- 대신 `import '../fakes/fake_path_provider.dart';`를 추가합니다.
- `PathProviderPlatform.instance = _FakePathProvider(tempDir.path);`를
  `PathProviderPlatform.instance = FakePathProvider(tempDir.path);`로
  바꿉니다(밑줄 없는 이름으로).

- [ ] **Step 2: 이 리팩터가 기존 테스트를 안 깨는지 확인한다**

Run: `flutter test test/services/local_image_storage_test.dart`
Expected: PASS (기존 그대로, 이름만 옮긴 순수 리팩터입니다)

- [ ] **Step 3: 실패하는 테스트부터 쓴다 (합치기)**

`test/services/archive_backup_service_test.dart`에 이어서 추가합니다.
맨 위 import에 아래를 더합니다:

```dart
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_taxonomy_repository.dart';

import '../fakes/fake_path_provider.dart';
```

(`enums.dart`/`ReferenceType`은 이미 있으면 중복으로 추가하지 않습니다.)

`main()` 맨 위에 추가합니다:

```dart
  TestWidgetsFlutterBinding.ensureInitialized();
```

`setUp` 블록에 사진 폴더용 가짜 경로를 추가로 심습니다(이번 테스트
그룹은 사진 파일도 다루므로):

```dart
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);

    db = AppDatabase.forTesting(
      NativeDatabase(File('${tempDir.path}/live.sqlite')),
    );
    repository = LocalReferenceRepository(db);
    service = ArchiveBackupService(db);
  });
```

새 그룹을 파일 끝(마지막 `}` 앞)에 추가합니다:

```dart
  group('복원(합치기)', () {
    /// 두 번째(백업 쪽) 데이터베이스를 만들어 돌려줍니다. 실제 백업처럼
    /// **지금 켜진 것과는 완전히 다른 파일**입니다.
    Future<AppDatabase> makeBackupDb() async {
      return AppDatabase.forTesting(
        NativeDatabase(File('${tempDir.path}/backup_source.sqlite')),
      );
    }

    test('백업에 있고 지금 없는 레퍼런스는 추가된다', () async {
      await saveImage('내 것');

      final AppDatabase backupDb = await makeBackupDb();
      final DateTime now = DateTime.now().toUtc();
      await LocalReferenceRepository(backupDb).save(
        ReferenceItem(
          id: newId(),
          type: ReferenceType.image,
          title: '백업에서 온 것',
          fileName: 'backup.jpg',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final String backupZipPath = '${tempDir.path}/other.zip';
      await ArchiveBackupService(backupDb).writeBackupZip(backupZipPath);
      await backupDb.close();

      await service.mergeBackupZipBytes(
        await File(backupZipPath).readAsBytes(),
      );

      final List<String> titles = (await repository.getAll())
          .map((ReferenceItem item) => item.title)
          .toList()
        ..sort();
      expect(titles, <String>['내 것', '백업에서 온 것']);
    });

    test('같은 id가 이미 있으면 두 번 늘어나지 않는다 (합치기를 두 번 해도 안전함)', () async {
      await saveImage('내 것');

      final String zipPath = '${tempDir.path}/self_backup.zip';
      await service.writeBackupZip(zipPath);

      // 자기 자신의 백업을 자기 자신에 두 번 합쳐봅니다.
      await service.mergeBackupZipBytes(await File(zipPath).readAsBytes());
      await service.mergeBackupZipBytes(await File(zipPath).readAsBytes());

      expect((await repository.getAll()).length, 1);
    });

    test('백업의 폴더·태그도 함께 합쳐진다', () async {
      final AppDatabase backupDb = await makeBackupDb();
      final LocalTaxonomyRepository backupTaxonomy = LocalTaxonomyRepository(
        backupDb,
      );
      final DateTime now = DateTime.now().toUtc();
      await backupTaxonomy.save(
        TaxonomyItem(
          id: newId(),
          kind: TaxonomyKind.folder,
          name: '백업 폴더',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final String backupZipPath = '${tempDir.path}/other.zip';
      await ArchiveBackupService(backupDb).writeBackupZip(backupZipPath);
      await backupDb.close();

      await service.mergeBackupZipBytes(
        await File(backupZipPath).readAsBytes(),
      );

      final LocalTaxonomyRepository liveTaxonomy = LocalTaxonomyRepository(
        db,
      );
      final List<TaxonomyItem> folders = await liveTaxonomy.getAll(
        TaxonomyKind.folder,
      );
      expect(
        folders.map((TaxonomyItem f) => f.name),
        contains('백업 폴더'),
      );
    });

    test('백업의 무드보드 판과 카드도 함께 합쳐진다', () async {
      final AppDatabase backupDb = await makeBackupDb();
      final LocalBoardRepository backupBoards = LocalBoardRepository(
        backupDb,
      );
      final LocalReferenceRepository backupReferences =
          LocalReferenceRepository(backupDb);

      final DateTime now = DateTime.now().toUtc();
      final ReferenceItem backupRef = ReferenceItem(
        id: newId(),
        type: ReferenceType.image,
        title: '백업 레퍼런스',
        fileName: 'x.jpg',
        createdAt: now,
        updatedAt: now,
      );
      await backupReferences.save(backupRef);
      await backupBoards.saveBoard(
        Board(id: 'board-1', name: '백업 무드보드', createdAt: now, updatedAt: now),
      );
      await backupBoards.addCards(<BoardCard>[
        BoardCard(
          id: newId(),
          boardId: 'board-1',
          referenceId: backupRef.id,
          x: 0,
          y: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final String backupZipPath = '${tempDir.path}/other.zip';
      await ArchiveBackupService(backupDb).writeBackupZip(backupZipPath);
      await backupDb.close();

      await service.mergeBackupZipBytes(
        await File(backupZipPath).readAsBytes(),
      );

      final LocalBoardRepository liveBoards = LocalBoardRepository(db);
      final List<BoardCard> cards = await liveBoards.getCards('board-1');
      expect(cards.single.referenceId, backupRef.id);
    });

    test('백업의 사진 파일도 실제 사진 폴더로 복사된다', () async {
      final AppDatabase backupDb = await makeBackupDb();

      // 백업 쪽 images 폴더에 진짜 파일을 하나 만들어둡니다. writeBackupZip이
      // getApplicationSupportDirectory()로 찾은 폴더에서 읽으므로, 지금
      // 가짜 경로(FakePathProvider)가 가리키는 폴더에 직접 만듭니다.
      //
      // 주의: 백업 쪽과 지금 쪽이 **같은 가짜 경로**를 씁니다(파일
      // 시스템은 하나뿐이므로). 실제로는 서로 다른 컴퓨터의 서로 다른
      // 폴더지만, 이 테스트에서는 "백업에만 있던 파일이 살아있는 쪽에도
      // 생기는지"를 확인하는 것이 핵심이라 문제되지 않습니다 — 시작할
      // 때 살아있는 쪽 images 폴더를 비워두고 시작합니다.
      final Directory imagesDir = Directory('${tempDir.path}/images');
      await imagesDir.create(recursive: true);
      final File backupOnlyImage = File(
        '${imagesDir.path}/backup-only.jpg',
      );
      await backupOnlyImage.writeAsBytes(<int>[1, 2, 3]);

      final String backupZipPath = '${tempDir.path}/other.zip';
      await ArchiveBackupService(backupDb).writeBackupZip(backupZipPath);
      await backupDb.close();

      // 합치기 전에 images 폴더를 비웁니다 — 방금 만든 backup-only.jpg가
      // "이미 살아있는 쪽에 있던 것"이 아니라 "백업에서 온 것"임을
      // 분명히 하려는 것입니다.
      await backupOnlyImage.delete();

      await service.mergeBackupZipBytes(
        await File(backupZipPath).readAsBytes(),
      );

      expect(await backupOnlyImage.exists(), isTrue);
    });
  });
}
```

- [ ] **Step 4: 테스트가 실패하는 것을 확인한다**

Run: `flutter test test/services/archive_backup_service_test.dart`
Expected: FAIL — `mergeBackupZipBytes` 메서드가 아직 없어서 컴파일 오류.

- [ ] **Step 5: `mergeBackupZipBytes`를 구현한다**

`lib/services/archive_backup_service.dart`의 `ArchiveBackupService`
클래스 안, `writeBackupZip` 다음에 추가합니다. 파일 위쪽 import에
`import 'dart:typed_data';`를 추가합니다.

```dart
  /// [zipBytes](백업 zip 파일 내용)를 지금 데이터베이스·사진 폴더에
  /// **합칩니다.** 통째로 바꿔치기가 아닙니다 — 지금 있는 것은 그대로
  /// 두고, 백업에만 있는 것만 추가합니다.
  ///
  /// 합치기가 안전한 이유: 이 프로젝트의 모든 항목은 UUID를 씁니다
  /// (CLAUDE.md 설계 원칙 1). 서로 다른 컴퓨터에서 만든 두 항목의
  /// id가 우연히 겹칠 확률은 사실상 0이라, "id가 없으면 추가"만으로
  /// 충돌 없이 합쳐집니다. 다만 **이름이 같은 항목을 하나로 합쳐주지는
  /// 않습니다** — 서로 다른 컴퓨터에서 각자 만든 "인물" 폴더가 있다면
  /// 합친 뒤 폴더가 두 개로 보입니다. 이번 범위에서는 그대로 둡니다.
  ///
  /// 파일 대화상자를 안 거치는 핵심 로직입니다. 실제로 사용자에게 백업
  /// 파일을 고르게 하는 일은 [restoreFromBackup]이 합니다.
  Future<void> mergeBackupZipBytes(Uint8List zipBytes) async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'reference_archive_restore_',
    );

    try {
      final Archive archive = ZipDecoder().decodeBytes(zipBytes);
      await extractArchiveToDisk(archive, tempDir.path);

      final File backupSqlite = File(
        p.join(tempDir.path, _sqliteEntryName),
      );
      if (!await backupSqlite.exists()) {
        throw const FormatException('백업 zip 안에 데이터베이스 파일이 없습니다.');
      }

      await _mergeDatabaseFrom(backupSqlite);
      await _mergeImagesFrom(
        Directory(p.join(tempDir.path, _imagesFolderName)),
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  /// 백업 데이터베이스 파일을 열어 표마다 "id가 없으면 추가"로 지금
  /// 데이터베이스에 합칩니다.
  ///
  /// 백업 파일을 [AppDatabase]로 열면(NativeDatabase(File(...))),
  /// 이 앱이 이미 갖고 있는 마이그레이션이 자동으로 실행됩니다 — 옛날
  /// 버전으로 만든 백업이어도 최신 구조로 올라온 뒤에 읽힙니다.
  Future<void> _mergeDatabaseFrom(File backupSqliteFile) async {
    final AppDatabase backupDb = AppDatabase.forTesting(
      NativeDatabase(backupSqliteFile),
    );

    try {
      // 부모 표를 먼저 읽어서, 넣는 순서도 부모가 먼저 되게 합니다.
      final List<TaxonomyItemRow> taxonomyRows = await backupDb
          .select(backupDb.taxonomyItems)
          .get();
      final List<ReferenceRow> referenceRows = await backupDb
          .select(backupDb.references)
          .get();
      final List<ReferenceTaxonomyLinkRow> linkRows = await backupDb
          .select(backupDb.referenceTaxonomyLinks)
          .get();
      final List<BoardRow> boardRows = await backupDb
          .select(backupDb.boards)
          .get();
      final List<BoardCardRow> cardRows = await backupDb
          .select(backupDb.boardCards)
          .get();

      // db.batch()는 그 자체로 하나의 트랜잭션입니다. 다섯 표 전부를
      // 한 번에 묶어서, 중간에 실패해도 절반만 합쳐지는 일이 없게 합니다.
      await _database.batch((Batch batch) {
        batch.insertAll(
          _database.taxonomyItems,
          taxonomyRows.map((TaxonomyItemRow row) => row.toCompanion(true)),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          _database.references,
          referenceRows.map((ReferenceRow row) => row.toCompanion(true)),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          _database.referenceTaxonomyLinks,
          linkRows.map(
            (ReferenceTaxonomyLinkRow row) => row.toCompanion(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          _database.boards,
          boardRows.map((BoardRow row) => row.toCompanion(true)),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          _database.boardCards,
          cardRows.map((BoardCardRow row) => row.toCompanion(true)),
          mode: InsertMode.insertOrIgnore,
        );
      });
    } finally {
      await backupDb.close();
    }
  }

  /// 백업의 사진 폴더에서, 지금 사진 폴더에 없는 파일만 복사합니다.
  ///
  /// 파일 이름도 UUID 기반이라(설계 원칙 4) 이름이 겹칠 일이 사실상
  /// 없습니다 — 그래도 이미 있으면 덮어쓰지 않고 건너뜁니다.
  Future<void> _mergeImagesFrom(Directory backupImagesDir) async {
    if (!await backupImagesDir.exists()) {
      return;
    }

    final Directory imagesDir = await _imagesDirectory();
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    await for (final FileSystemEntity entity in backupImagesDir.list()) {
      if (entity is! File) {
        continue;
      }

      final String fileName = p.basename(entity.path);
      final File destination = File(p.join(imagesDir.path, fileName));

      if (!await destination.exists()) {
        await entity.copy(destination.path);
      }
    }
  }
```

- [ ] **Step 6: 테스트가 통과하는지 확인한다**

Run: `flutter test test/services/archive_backup_service_test.dart`
Expected: PASS (기존 2개 + 새 5개 = 7개)

- [ ] **Step 7: `flutter analyze`로 확인한다**

Run: `flutter analyze`
Expected: 이슈 없음.

- [ ] **Step 8: 커밋한다**

```bash
git add lib/services/archive_backup_service.dart test/services/archive_backup_service_test.dart test/fakes/fake_path_provider.dart test/services/local_image_storage_test.dart
git commit -m "Task 2: 백업 합치기(mergeBackupZipBytes)를 구현한다"
```

---

## Task 3: 파일 대화상자를 감싸는 바깥 함수

**Files:**
- Modify: `lib/services/archive_backup_service.dart`

**Interfaces:**
- Produces: `enum BackupOutcome { saved, cancelled, failed }`,
  `enum RestoreOutcome { restored, cancelled, invalidFile, failed }`,
  `Future<BackupOutcome> createBackup()`,
  `Future<RestoreOutcome> restoreFromBackup()` — Task 4(컨트롤러)가
  이 넷을 씁니다.

이 함수들은 진짜 운영체제 파일 대화상자를 열려고 해서 위젯 테스트
환경에서 못 씁니다(board_export_controller.dart와 같은 사정). 그래서
TDD 없이 바로 구현하고, 실제 동작 확인은 Task 7(수동 확인)에서 합니다.

- [ ] **Step 1: import를 추가한다**

`lib/services/archive_backup_service.dart` 맨 위에 추가합니다:

```dart
import 'package:file_picker/file_picker.dart';
```

- [ ] **Step 2: outcome enum 둘을 추가한다**

`ArchiveBackupService` 클래스 **앞**(파일 안, import들 다음)에 추가합니다:

```dart
/// [ArchiveBackupService.createBackup] 결과입니다.
enum BackupOutcome {
  /// 백업 파일을 만들어 저장했습니다.
  saved,

  /// 사용자가 저장 대화상자를 취소했습니다. 실패가 아닙니다.
  cancelled,

  /// 저장하려다 오류가 났습니다.
  failed,
}

/// [ArchiveBackupService.restoreFromBackup] 결과입니다.
enum RestoreOutcome {
  /// 백업 내용을 지금 아카이브에 합쳤습니다.
  restored,

  /// 사용자가 파일 고르기 대화상자를 취소했습니다. 실패가 아닙니다.
  cancelled,

  /// 고른 파일이 이 앱이 만든 백업 zip이 아니거나, 안에 데이터베이스
  /// 파일이 없습니다.
  invalidFile,

  /// 합치다가 오류가 났습니다.
  failed,
}
```

- [ ] **Step 3: `createBackup()`을 추가한다**

`writeBackupZip` 메서드 **앞**에 추가합니다:

```dart
  /// 저장 대화상자를 열어 사용자가 고른 자리에 백업 zip을 만듭니다.
  Future<BackupOutcome> createBackup() async {
    final String? savePath = await FilePicker.saveFile(
      dialogTitle: '아카이브 백업 만들기',
      fileName: _defaultBackupFileName(),
      type: FileType.custom,
      allowedExtensions: <String>['zip'],
    );

    // 취소했으면(null) 조용히 아무 일도 안 합니다. 취소는 실패가 아닙니다.
    if (savePath == null) {
      return BackupOutcome.cancelled;
    }

    try {
      await writeBackupZip(savePath);
      return BackupOutcome.saved;
    } catch (error) {
      return BackupOutcome.failed;
    }
  }

  /// 오늘 날짜가 들어간 기본 백업 파일 이름을 만듭니다.
  /// 예: "레퍼런스아카이브-백업-2026-09-06.zip"
  String _defaultBackupFileName() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '레퍼런스아카이브-백업-$year-$month-$day.zip';
  }
```

- [ ] **Step 4: `restoreFromBackup()`을 추가한다**

`mergeBackupZipBytes` 메서드 **뒤**(`_mergeDatabaseFrom` 앞)에
추가합니다:

```dart
  /// 파일 고르기 대화상자를 열어, 사용자가 고른 백업 zip을 지금
  /// 아카이브에 합칩니다.
  Future<RestoreOutcome> restoreFromBackup() async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['zip'],
      withData: true,
      dialogTitle: '백업 파일 고르기',
    );

    if (picked == null || picked.files.isEmpty) {
      return RestoreOutcome.cancelled;
    }

    final Uint8List? bytes = picked.files.single.bytes;
    if (bytes == null) {
      return RestoreOutcome.failed;
    }

    try {
      await mergeBackupZipBytes(bytes);
      return RestoreOutcome.restored;
    } on FormatException {
      return RestoreOutcome.invalidFile;
    } on ArchiveException {
      // zip 형식 자체가 아닌 파일을 골랐을 때 ZipDecoder가 던집니다.
      return RestoreOutcome.invalidFile;
    } catch (error) {
      return RestoreOutcome.failed;
    }
  }
```

- [ ] **Step 5: `flutter analyze`로 확인한다**

Run: `flutter analyze lib/services/archive_backup_service.dart`
Expected: 이슈 없음.

- [ ] **Step 6: 기존 테스트가 그대로 통과하는지 확인한다**

Run: `flutter test test/services/archive_backup_service_test.dart`
Expected: PASS (7개, 안 바뀜 — 이 Task는 새 공개 함수만 추가했습니다)

- [ ] **Step 7: 커밋한다**

```bash
git add lib/services/archive_backup_service.dart
git commit -m "Task 3: 백업/복원 파일 대화상자(createBackup/restoreFromBackup)를 추가한다"
```

---

## Task 4: `BackupController` (화면 상태)

**Files:**
- Create: `lib/screens/backup_controller.dart`

**Interfaces:**
- Consumes: `ArchiveBackupService`(Task 1~3), `BackupOutcome`,
  `RestoreOutcome`.
- Produces: `class BackupController extends ChangeNotifier`,
  생성자 `BackupController(ArchiveBackupService service)`,
  `bool get isWorking`, `Future<BackupOutcome> createBackup()`,
  `Future<RestoreOutcome> restoreFromBackup()` — Task 5(설정 화면)가
  씁니다.

이 파일도 `board_export_controller.dart`와 같은 이유로 화면 없이는
의미 있게 테스트하기 어렵습니다(진짜 대화상자를 엽니다). `isWorking`
플래그가 제대로 켜지고 꺼지는지만 확인합니다.

- [ ] **Step 1: 구현한다**

`lib/screens/backup_controller.dart` (새 파일):

```dart
// 설정 화면의 "데이터 관리" 구역(백업 만들기/불러오기) 상태를 담습니다.
//
// board_export_controller.dart와 같은 ChangeNotifier 패턴입니다 —
// "지금 하는 중인지" 상태만 여기서 갖고, 실제 파일 작업은
// services/archive_backup_service.dart가 합니다.

import 'package:flutter/foundation.dart';

import '../services/archive_backup_service.dart';

/// 백업 만들기/불러오기의 상태를 담습니다.
class BackupController extends ChangeNotifier {
  BackupController(this._service);

  final ArchiveBackupService _service;

  /// 지금 백업을 만들거나 불러오는 중인지 여부입니다.
  /// 켜져 있는 동안 버튼을 다시 못 누르게 막는 데 씁니다.
  bool get isWorking => _isWorking;
  bool _isWorking = false;

  /// 백업을 만듭니다.
  Future<BackupOutcome> createBackup() async {
    if (_isWorking) {
      return BackupOutcome.cancelled;
    }

    _isWorking = true;
    notifyListeners();

    try {
      return await _service.createBackup();
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  /// 백업 파일을 골라 지금 아카이브에 합칩니다.
  Future<RestoreOutcome> restoreFromBackup() async {
    if (_isWorking) {
      return RestoreOutcome.cancelled;
    }

    _isWorking = true;
    notifyListeners();

    try {
      return await _service.restoreFromBackup();
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 2: `flutter analyze`로 확인한다**

Run: `flutter analyze lib/screens/backup_controller.dart`
Expected: 이슈 없음.

- [ ] **Step 3: 커밋한다**

```bash
git add lib/screens/backup_controller.dart
git commit -m "Task 4: BackupController를 추가한다"
```

---

## Task 5: 설정 화면에 "데이터 관리" 구역 추가

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Test: `test/screens/settings_screen_test.dart` (기존 파일에 추가)

**Interfaces:**
- Consumes: `BackupController`(Task 4), `ArchiveBackupService`,
  `BackupOutcome`, `RestoreOutcome`.
- Produces: `SettingsScreen`의 새 선택적 생성자 필드
  `final ArchiveBackupService? backupService;` (기본값 null) — Task 6
  (main.dart 배선)이 실제 서비스를 넘겨줍니다. **null이면 "데이터
  관리" 구역 자체가 안 보입니다** — `SettingsScreen`을 직접 만드는
  기존 테스트(`settings_screen_test.dart`)가 이 값을 안 넘기므로,
  고치지 않아도 그대로 통과합니다.

- [ ] **Step 1: 생성자에 선택적 필드를 추가한다**

`lib/screens/settings_screen.dart`의 `SettingsScreen` 생성자를 고칩니다:

```dart
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    this.backupService,
  });

  /// 설정을 읽고 쓰는 도구입니다.
  final AppSettings settings;

  /// 아카이브 백업/복원 서비스입니다.
  ///
  /// null이면 "데이터 관리" 구역 자체를 안 보여줍니다. 이 값을 필수로
  /// 만들면 이 화면을 직접 만드는 기존 테스트를 전부 고쳐야 해서
  /// 선택적으로 뒀습니다.
  final ArchiveBackupService? backupService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
```

`import '../services/archive_backup_service.dart';`를 파일 위쪽
import 목록에 추가합니다(`import 'board_window_controller.dart';`
다음 자리, 알파벳 순).

- [ ] **Step 2: 컨트롤러를 만들고 정리한다**

`_SettingsScreenState`에 필드와 `initState`/`dispose`를 추가합니다.
기존 `_boardAlwaysOnTop`/`_boardOpacity` 필드 선언부 아래,
`initState()` 안에 이어서 씁니다:

```dart
  /// 백업/복원 상태입니다. widget.backupService가 null이면 이것도
  /// null입니다 — "데이터 관리" 구역 자체를 안 그리므로 쓸 일이
  /// 없습니다.
  BackupController? _backup;

  @override
  void initState() {
    super.initState();

    final ArchiveBackupService? backupService = widget.backupService;
    if (backupService != null) {
      _backup = BackupController(backupService);
    }

    if (supportsAlwaysOnTopWindow) {
      _loadBoardWindowDefaults();
    }
  }

  @override
  void dispose() {
    _backup?.dispose();
    super.dispose();
  }
```

(이미 있던 `initState`의 `supportsAlwaysOnTopWindow` 부분은 그대로
두고, 그 위에 백업 컨트롤러 만드는 부분만 더합니다. `dispose()`는
이 화면에 처음 생기는 것이라 새로 추가합니다.)

- [ ] **Step 3: 백업/복원 동작 메서드를 추가한다**

`_setBoardOpacity` 메서드 뒤에 추가합니다:

```dart
  /// 백업 파일을 만듭니다.
  Future<void> _createBackup() async {
    final BackupController? backup = _backup;
    if (backup == null) {
      return;
    }

    final BackupOutcome outcome = await backup.createBackup();

    if (!mounted) {
      return;
    }

    final String? message = switch (outcome) {
      BackupOutcome.saved => '백업 파일을 만들었습니다.',
      BackupOutcome.cancelled => null,
      BackupOutcome.failed => '백업을 만들지 못했습니다.',
    };

    if (message != null) {
      _showMessage(message);
    }
  }

  /// 백업 파일을 골라 지금 아카이브에 합칩니다.
  Future<void> _restoreFromBackup() async {
    final BackupController? backup = _backup;
    if (backup == null) {
      return;
    }

    final RestoreOutcome outcome = await backup.restoreFromBackup();

    if (!mounted) {
      return;
    }

    switch (outcome) {
      case RestoreOutcome.restored:
        await _showRestoredDialog();
      case RestoreOutcome.cancelled:
        break;
      case RestoreOutcome.invalidFile:
        _showMessage('올바른 백업 파일이 아닙니다.');
      case RestoreOutcome.failed:
        _showMessage('복원하지 못했습니다.');
    }
  }

  /// 복원이 끝났다고 알리고, 앱을 다시 켜달라고 안내합니다.
  ///
  /// ── 왜 화면을 그냥 새로고침하지 않나 ──
  /// 지금 켜진 화면들(레퍼런스 목록, 사이드바의 파트 목록 등)은 전부
  /// 메모리에 읽어둔 값을 보여주고 있습니다. 방금 데이터베이스에 새로
  /// 합쳐진 내용을 전부 반영하려면 앱 전체를 다시 켜는 것이 가장
  /// 확실하고 단순합니다.
  Future<void> _showRestoredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('복원됐습니다'),
          content: const Text('백업 내용이 지금 아카이브에 합쳐졌습니다.\n앱을 다시 켜야 화면에 반영됩니다.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => exit(0),
              child: const Text('지금 종료'),
            ),
          ],
        );
      },
    );
  }

  /// 화면 아래에 잠깐 뜨는 안내입니다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
```

파일 맨 위에 `import 'dart:io' show exit;`를 추가합니다(다른 import
보다 위, `import 'package:flutter/material.dart';` 앞 — Dart의
`dart:` import는 관례상 맨 위에 둡니다).

- [ ] **Step 4: 화면에 "데이터 관리" 구역을 그린다**

`build()` 메서드의 `ListView` children 목록에서, "무드보드" 구역
바로 뒤·"앱 정보" 구역 바로 앞에 추가합니다:

```dart
              if (supportsAlwaysOnTopWindow) ...<Widget>[
                const SizedBox(height: 28),
                _buildSectionLabel('무드보드', palette),
                _buildBoardWindowDefaults(palette),
              ],

              // widget.backupService가 없으면(null) 이 구역 자체를 안
              // 그립니다 — main.dart에서 아직 안 넘겨준 경우이거나,
              // 이 화면을 테스트가 직접 만든 경우입니다.
              if (_backup != null) ...<Widget>[
                const SizedBox(height: 28),
                _buildSectionLabel('데이터 관리', palette),
                _buildDataManagement(palette),
              ],

              const SizedBox(height: 28),
              _buildSectionLabel('앱 정보', palette),
```

`_buildBoardWindowDefaults` 메서드 뒤에 새 메서드를 추가합니다:

```dart
  /// 백업 만들기/불러오기 버튼입니다.
  Widget _buildDataManagement(AppPalette palette) {
    final BackupController backup = _backup!;

    // ListenableBuilder = 컨트롤러가 바뀌면(작업 중 여부) 이 안만
    // 다시 그려주는 위젯입니다. 눌린 동안 버튼을 다시 못 누르게 막는 데 씁니다.
    return ListenableBuilder(
      listenable: backup,
      builder: (BuildContext context, Widget? child) {
        return _buildPanel(
          palette,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '데이터베이스와 사진을 zip 파일 하나로 백업하거나, '
                  '백업 파일을 지금 아카이브에 합칠 수 있습니다. '
                  '앱 설정(밝기 모드·이름)은 백업에 안 들어갑니다.',
                  style: AppText.cardMemo.copyWith(color: palette.textDim),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: backup.isWorking ? null : _createBackup,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('백업 만들기'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: backup.isWorking ? null : _restoreFromBackup,
                      icon: const Icon(Icons.unarchive_outlined),
                      label: const Text('백업에서 가져오기'),
                    ),
                    if (backup.isWorking) ...<Widget>[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 5: `flutter analyze`로 확인한다**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: 이슈 없음.

- [ ] **Step 6: 기존 테스트가 그대로 통과하는지 확인한다**

Run: `flutter test test/screens/settings_screen_test.dart test/screens/app_shell_test.dart`
Expected: PASS — `backupService`를 안 넘기므로 "데이터 관리" 구역이
안 보여서 기존 기대와 그대로 맞습니다.

- [ ] **Step 7: "데이터 관리" 구역이 보이는지 확인하는 테스트를 추가한다**

`test/screens/settings_screen_test.dart`에 새 테스트를 추가합니다.
맨 위 import에 추가합니다:

```dart
import 'package:reference_archive_app/services/archive_backup_service.dart';
import 'package:drift/native.dart';
import 'package:reference_archive_app/data/app_database.dart';
```

기존 `testWidgets`문 뒤에 추가합니다:

```dart
  testWidgets('backupService를 넘기면 데이터 관리 구역이 보인다', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppSettings settings = AppSettings();
    await settings.load();

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: settings,
          backupService: ArchiveBackupService(db),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('데이터 관리'), findsOneWidget);
    expect(find.text('백업 만들기'), findsOneWidget);
    expect(find.text('백업에서 가져오기'), findsOneWidget);
  });
```

- [ ] **Step 8: 테스트가 통과하는지 확인한다**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS (기존 1개 + 새 1개 = 2개)

- [ ] **Step 9: 전체 테스트를 한 번 더 확인한다**

Run: `flutter test`
Expected: 전부 통과, 회귀 없음.

- [ ] **Step 10: 커밋한다**

```bash
git add lib/screens/settings_screen.dart test/screens/settings_screen_test.dart
git commit -m "Task 5: 설정 화면에 데이터 관리(백업/복원) 구역을 추가한다"
```

---

## Task 6: `main.dart`에 서비스를 배선한다

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/home_screen.dart`

**Interfaces:**
- Consumes: `ArchiveBackupService`(Task 1~3), `SettingsScreen.backupService`
  (Task 5).

`HomeScreen`도 `ReferenceArchiveApp`도 이미 여러 "도구" 객체
(`imageStorage`/`youtubeInfoSource`/`imageSource`)를 이렇게 값으로
받아 넘기고 있으므로, 그 자리에 하나 더 끼워 넣습니다. **선택적으로
둡니다** — `ReferenceArchiveApp`/`HomeScreen`을 직접 만드는 기존
테스트가 9개나 있어서, 필수로 만들면 전부 고쳐야 합니다.

- [ ] **Step 1: `HomeScreen`에 선택적 필드를 추가한다**

`lib/screens/home_screen.dart`의 `HomeScreen` 생성자에 추가합니다:

```dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.taxonomyRepository,
    required this.boardRepository,
    required this.imageStorage,
    required this.imageSource,
    required this.youtubeInfoSource,
    required this.settings,
    this.backupService,
  });

  // ... 기존 필드들 ...

  /// 앱 설정입니다. 사이드바의 사용자 이름과 설정 화면에 씁니다.
  final AppSettings settings;

  /// 아카이브 백업/복원 서비스입니다. 설정 화면에 그대로 넘겨줍니다.
  ///
  /// null이면 설정 화면의 "데이터 관리" 구역이 안 보입니다 — 이
  /// 화면을 직접 만드는 기존 테스트가 여럿이라 선택적으로 뒀습니다.
  final ArchiveBackupService? backupService;
```

`import '../services/archive_backup_service.dart';`를 파일 위쪽
import 목록에 추가합니다.

- [ ] **Step 2: `_openSettings()`에서 그대로 넘겨준다**

`_openSettings()` 메서드를 고칩니다:

```dart
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SettingsScreen(
          settings: widget.settings,
          backupService: widget.backupService,
        ),
      ),
    );
```

- [ ] **Step 3: `ReferenceArchiveApp`에 선택적 필드를 추가한다**

`lib/main.dart`의 `ReferenceArchiveApp` 생성자에 추가합니다:

```dart
class ReferenceArchiveApp extends StatelessWidget {
  const ReferenceArchiveApp({
    super.key,
    required this.referenceRepository,
    required this.taxonomyRepository,
    required this.boardRepository,
    required this.imageStorage,
    required this.imageSource,
    required this.youtubeInfoSource,
    required this.settings,
    this.backupService,
  });

  // ... 기존 필드들 ...

  /// 앱 설정입니다. 사이드바의 사용자 이름과 설정 화면에 씁니다.
  final AppSettings settings;

  /// 아카이브 백업/복원 서비스입니다. HomeScreen에 그대로 넘겨줍니다.
  final ArchiveBackupService? backupService;
```

`build()` 안의 `HomeScreen(...)` 호출에 추가합니다:

```dart
          home: HomeScreen(
            repository: referenceRepository,
            taxonomyRepository: taxonomyRepository,
            boardRepository: boardRepository,
            imageStorage: imageStorage,
            imageSource: imageSource,
            youtubeInfoSource: youtubeInfoSource,
            settings: settings,
            backupService: backupService,
          ),
```

`import 'services/archive_backup_service.dart';`를 `lib/main.dart`
위쪽 import 목록에 추가합니다(알파벳 순 — `'screens/board_popup_app.dart'`
와 `'screens/board_popup_controller.dart'` 사이가 아니라, `services/`
그룹 안 알파벳 순서에 맞게 둡니다).

- [ ] **Step 4: `_runMainWindow()`에서 실제 서비스를 만들어 넘긴다**

`lib/main.dart`의 `_runMainWindow()` 함수를 고칩니다:

```dart
Future<void> _runMainWindow() async {
  final AppDatabase database = AppDatabase();

  // 저장해둔 설정(밝기 모드, 사용자 이름)을 먼저 읽습니다.
  // 화면을 띄운 뒤에 읽으면 밝은 화면이 잠깐 번쩍였다가 어두워집니다.
  final AppSettings settings = AppSettings();
  await settings.load();

  if (supportsBoardPopupWindow) {
    BoardWindowSync.ensureInitialized();
    await _installMainWindowCloseGuard();
  }

  runApp(
    ReferenceArchiveApp(
      referenceRepository: LocalReferenceRepository(database),
      boardRepository: LocalBoardRepository(database),
      taxonomyRepository: LocalTaxonomyRepository(database),
      imageStorage: LocalImageStorage(),
      imageSource: NetworkImageSource(),
      settings: settings,
      youtubeInfoSource: NetworkYoutubeInfoSource(),
      backupService: ArchiveBackupService(database),
    ),
  );
}
```

- [ ] **Step 5: `flutter analyze`로 확인한다**

Run: `flutter analyze`
Expected: 이슈 없음.

- [ ] **Step 6: 전체 테스트를 확인한다**

Run: `flutter test`
Expected: 전부 통과, 회귀 없음(9개 테스트 파일이 `backupService`를
안 넘기지만 선택적 필드라 그대로 컴파일되고 통과합니다).

- [ ] **Step 7: 커밋한다**

```bash
git add lib/main.dart lib/screens/home_screen.dart
git commit -m "Task 6: main.dart에서 ArchiveBackupService를 만들어 설정 화면까지 배선한다"
```

---

## Task 7: 실제로 앱을 띄워 확인한다 (수동 확인)

파일 대화상자·실제 sqlite 파일 전체 크기·"복원 후 앱을 다시 켜기"는
위젯 테스트로 확인할 수 없는 부류입니다(이 프로젝트의 다른 파일
저장/열기, 창 관련 기능들과 같은 사정). `flutter run -d windows`로
직접 켜서 아래를 확인합니다. 코드 변경은 없습니다 — 문제가 발견되면
해당 Task로 돌아가 고칩니다.

**Files:** 없음 (확인 전용)

- [ ] **Step 1: 빌드 확인**

Run: `flutter analyze`(전체), `flutter test`(전체), `flutter build windows`
Expected: 전부 통과·성공.

- [ ] **Step 2: 백업이 실제로 만들어지는지 확인**

`flutter run -d windows`로 앱을 켜고:
1. 설정 화면 → "데이터 관리" 구역이 보이는지 확인합니다.
2. "백업 만들기"를 눌러 원하는 자리에 저장합니다.
3. 만들어진 zip 파일을 탐색기에서 열어(zip은 그냥 열립니다)
   `reference_archive.sqlite`와 `images/` 폴더가 들어있는지 확인합니다.

- [ ] **Step 3: 복원(합치기)이 실제로 되는지 확인**

1. 레퍼런스를 하나 더 추가하거나 지워서, 방금 만든 백업과 지금
   아카이브의 내용을 다르게 만듭니다.
2. "백업에서 가져오기"로 방금 만든 zip을 고릅니다.
3. "복원됐습니다" 안내가 뜨는지 확인합니다.
4. **"지금 종료"**를 눌러 앱을 끕니다.
5. 앱을 다시 켜서, 백업에 있던 레퍼런스가 지금 목록에 합쳐져 있는지
   확인합니다(중복 없이).

- [ ] **Step 4: 관계없는 파일을 골랐을 때 확인**

"백업에서 가져오기"로 zip이 아니거나 이 앱이 만들지 않은 zip을
골랐을 때 "올바른 백업 파일이 아닙니다" 안내가 뜨고 앱이 안 죽는지
확인합니다.

- [ ] **Step 5: 결과를 문서화할 준비**

문제 없이 확인됐다면, 다음 단계(CLAUDE.md/update.md 정리, PR)로
넘어갑니다. 이 계획 문서에는 별도 커밋할 코드 변경이 없습니다.
