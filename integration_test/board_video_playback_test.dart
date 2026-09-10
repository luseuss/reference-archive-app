// 무드보드 안에서 유튜브 영상을 그 자리에서 재생하는 기능(PR #57)이
// 실제로 앱을 죽이지 않는지 확인하는 통합 테스트입니다.
//
// ── 왜 따로 있는가 ──
// integration_test/youtube_player_test.dart 맨 위 설명과 같은 이유입니다.
// `test/` 폴더의 일반 테스트에서는 웹뷰가 아예 안 켜져서 "재생 버튼을
// 누르면 크래시로 앱이 통째로 꺼진다"는 실제 보고를 재현할 수 없습니다.
//
//   flutter test integration_test/board_video_playback_test.dart -d windows

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reference_archive_app/data/app_database.dart';
import 'package:reference_archive_app/models/board.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/reference_item.dart';
import 'package:reference_archive_app/repositories/local_board_repository.dart';
import 'package:reference_archive_app/repositories/local_reference_repository.dart';
import 'package:reference_archive_app/screens/board_screen.dart';
import 'package:reference_archive_app/utils/id_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fakes/fake_image_source.dart';
import '../test/fakes/fake_image_storage.dart';
import '../test/fakes/fake_youtube_info_source.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 실제로 존재하는 영상 번호입니다. youtube_player_test.dart와 같은 것을 씁니다.
  const String videoId = 'dQw4w9WgXcQ';

  testWidgets('실제 BoardScreen에서 유튜브 카드 재생 버튼을 누르면 앱이 살아있다', (
    WidgetTester tester,
  ) async {
    // ── 이 테스트가 재현하려는 것 ──
    // 사용자 보고: "무드보드 내에 있는 유튜브영상을 실행시키면 크래시 나면서
    // 앱이 꺼져". 단독 BoardCardView 테스트(board_video_playback_test.dart의
    // 앞선 버전)는 통과했으므로, 이번엔 board_screen_test.dart와 똑같은
        // 방식으로 **진짜 BoardScreen**(판 화면 전체 — 캔버스·줌·컨트롤러
    // 전부 포함)을 실제로 열어서 확인합니다.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final LocalBoardRepository boardRepository = LocalBoardRepository(db);
    final LocalReferenceRepository referenceRepository =
        LocalReferenceRepository(db);

    final DateTime now = DateTime.now().toUtc();
    final Board board = Board(
      id: newId(),
      name: '테스트 판',
      createdAt: now,
      updatedAt: now,
    );
    await boardRepository.saveBoard(board);

    final ReferenceItem item = ReferenceItem(
      id: newId(),
      type: ReferenceType.youtube,
      title: '테스트 영상',
      youtubeVideoId: videoId,
      createdAt: now,
      updatedAt: now,
    );
    await referenceRepository.save(item);

    final BoardCard card = BoardCard(
      id: newId(),
      boardId: board.id,
      referenceId: item.id,
      x: 100,
      y: 100,
      width: 320,
      createdAt: now,
      updatedAt: now,
    );
    await boardRepository.addCards(<BoardCard>[card]);

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BoardScreen(
          board: board,
          boardRepository: boardRepository,
          referenceRepository: referenceRepository,
          imageStorage: FakeImageStorage(),
          imageSource: FakeImageSource(),
          youtubeInfoSource: FakeYoutubeInfoSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 재생 버튼을 실제로 누릅니다.
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_circle_fill));
    await tester.pumpAndSettle();

    // 재생기가 뜰 시간을 줍니다.
    await tester.pump(const Duration(seconds: 3));

    // 여기까지 왔으면(테스트가 계속 진행됐으면) 앱이 안 죽은 것입니다.
    expect(find.byType(BoardScreen), findsOneWidget);
  });
}
