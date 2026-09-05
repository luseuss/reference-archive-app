// 무드보드를 팝업 창(별도 OS 창)으로 띄울 때, 그 창 전체를 채우는
// 진입점입니다. lib/main.dart가 "이 창은 팝업이다"라고 판단하면
// 이 위젯을 띄웁니다.
//
// ── 왜 이 화면이 따로 필요한가 ──
// board_screen.dart는 "판 하나"를 보여줄 뿐, 어느 판을 보여줄지는
// 밖에서 정해줘야 합니다. 이 화면은 처음 뜰 때 받은 판 번호로 시작해서,
// "다른 판을 보여줘"라는 신호(BoardWindowSync)를 받으면 판 번호를
// 바꿔 BoardScreen을 새로 만듭니다.
//
// ── 데이터베이스를 또 엽니다 ──
// 팝업 창은 메인 창과 다른 Flutter 엔진이라 메모리를 안 나눕니다.
// 그래서 AppDatabase()를 하나 더 엽니다 — 파일 경로가 같으므로
// (data/app_database.dart의 _openConnection 참고) 메인 창과 같은
// 데이터를 봅니다. 2026-08-31 스파이크에서 이미 확인된 방식입니다.
//
// ── 창을 닫을 때 메인 창에 알립니다 (2026-09-05 버그 수정) ──
// 이 창을 OS 창 닫기(X 버튼)로 닫으면, 메인 창의 BoardPopupController가
// 들고 있는 참조가 죽은 채로 남아 "열고 닫기를 반복하면 무드보드가 아예
// 안 켜지는" 버그가 됩니다. 그래서 메인 창의 닫기 가드
// (lib/main.dart의 _MainWindowCloseGuard)와 같은 방식으로, 닫기를
// 가로채서 메인 창에 먼저 알리고 나서 진짜로 닫습니다.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:window_manager/window_manager.dart';

import '../data/app_database.dart';
import '../models/board.dart';
import '../repositories/local_board_repository.dart';
import '../repositories/local_reference_repository.dart';
import '../services/board_window_sync.dart';
import '../services/local_image_storage.dart';
import '../theme/app_theme.dart';
import 'board_popup_controller.dart';
import 'board_screen.dart';

/// 팝업 창 전체를 채우는 앱입니다.
///
/// [initialBoardId]는 창을 만들 때 받은 판 번호입니다
/// (board_popup_controller.dart의 WindowConfiguration.arguments).
class BoardPopupApp extends StatefulWidget {
  const BoardPopupApp({super.key, required this.initialBoardId});

  final String initialBoardId;

  @override
  State<BoardPopupApp> createState() => _BoardPopupAppState();
}

class _BoardPopupAppState extends State<BoardPopupApp> {
  /// 팝업 창 전용 데이터베이스 연결입니다. 메인 창과 파일은 같지만
  /// 연결(연결 객체) 자체는 다릅니다.
  final AppDatabase _database = AppDatabase();

  /// 지금 보여주고 있는 판 번호입니다. 메인 창이 "다른 판을 보여줘"라고
  /// 알려오면 바뀝니다.
  late String _boardId;

  /// 지금 보여줄 판입니다. 판 번호가 바뀔 때마다 다시 읽어옵니다.
  Board? _board;

  late final LocalBoardRepository _boardRepository;
  late final LocalReferenceRepository _referenceRepository;

  @override
  void initState() {
    super.initState();

    _boardId = widget.initialBoardId;
    _boardRepository = LocalBoardRepository(_database);
    _referenceRepository = LocalReferenceRepository(_database);

    // 메인 창이 "닫아라"고 요청하면 스스로 닫히도록 준비합니다
    // (board_popup_controller.dart의 requestClose/registerPopupWindowCloseHandler
    // 설명 참고).
    registerPopupWindowCloseHandler();

    // 이 창을 사용자가 직접(OS 닫기 버튼으로) 닫을 때도 메인 창에
    // 알리도록 준비합니다. 위 registerPopupWindowCloseHandler는 "메인
    // 창이 먼저 요청한" 경우만 다룹니다 — 이건 그 반대(팝업이 스스로
    // 닫히는) 경우입니다.
    _installPopupCloseGuard();

    // 메인 창이 "이 판을 보여줘"라고 신호를 보내면 판 번호를 바꿉니다.
    // 이 리스너는 팝업 창이 떠 있는 동안 계속 살아 있습니다(끄지
    // 않습니다) — board_screen.dart의 cardsChanged 리스너와 달리,
    // 이 창의 "바깥 껍데기"가 하나뿐이라 여러 화면이 번갈아 꽂았다
    // 뺄 필요가 없습니다.
    BoardWindowSync.setShowBoardListener((String boardId) {
      setState(() {
        _boardId = boardId;
        _board = null; // 새로 읽어올 때까지 로딩 표시로 되돌립니다.
      });
      _loadBoard();
    });

    _loadBoard();
  }

  /// 이 창을 OS 창 닫기(X 버튼)로 닫으면 메인 창에 먼저 알리도록
  /// 준비합니다. lib/main.dart의 _installMainWindowCloseGuard와 같은
  /// 방식(setPreventClose로 가로채고, 알린 뒤에 진짜로 닫기)입니다.
  Future<void> _installPopupCloseGuard() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(_PopupCloseGuard());
  }

  /// 지금 판 번호(_boardId)에 해당하는 판을 읽어옵니다.
  Future<void> _loadBoard() async {
    final Board? board = await _boardRepository.getBoardById(_boardId);

    if (!mounted) {
      return;
    }

    setState(() {
      _board = board;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '레퍼런스 아카이브 — 무드보드',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('ko'), Locale('en')],
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: _board == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : BoardScreen(
              // key를 판 번호로 두면, 판이 바뀔 때 BoardScreen이
              // 완전히 새로 만들어집니다(이전 판의 카드·선택 상태가
              // 안 남습니다).
              key: ValueKey<String>(_board!.id),
              board: _board!,
              boardRepository: _boardRepository,
              referenceRepository: _referenceRepository,
              imageStorage: LocalImageStorage(),
              canPopOut: false,
            ),
    );
  }
}

/// 팝업 창(무드보드)이 스스로 닫힐 때, 닫히기 전에 메인 창에 알립니다.
///
/// lib/main.dart의 _MainWindowCloseGuard와 짝을 이룹니다 — 그쪽은
/// "메인 창을 닫으면 팝업도 정리"를, 이쪽은 그 반대(팝업을 닫으면
/// 메인 창이 알게)를 맡습니다.
class _PopupCloseGuard extends WindowListener {
  @override
  void onWindowClose() async {
    try {
      await BoardWindowSync.notifyPopupClosed();
    } catch (error) {
      // 메인 창에 못 알려도 이 창은 닫혀야 합니다. 대신
      // board_popup_controller.dart의 showBoard()에 있는 두 번째
      // 안전장치(죽은 창을 실제로 불러보다 실패하면 그때 정리)가
      // 뒤늦게라도 참조를 지워줍니다.
      debugPrint('[무드보드 팝업 창] 메인 창에 닫힘을 알리지 못했습니다: $error');
    }

    // setPreventClose로 걸어둔 것을 풀어야 진짜로 닫힙니다. 다시
    // 걸 필요는 없습니다 — 이 창은 곧 사라집니다.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
