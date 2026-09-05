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

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;

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
