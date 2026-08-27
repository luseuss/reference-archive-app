// 무드보드 목록 화면입니다. 판을 만들고, 열고, 이름을 바꾸고, 지웁니다.
//
// ── 왜 목록 화면이 따로 있나 (바로 판을 열면 안 되나) ──
// 무드보드는 여러 개를 만들어 쓰는 물건입니다. "겨울 무드", "3화 배경 톤"처럼
// 목적마다 판을 나눠 만들게 됩니다. 그래서 먼저 어느 판을 볼지 고르는 자리가 필요합니다.
//
// 판 안에서 실제로 카드를 늘어놓는 일은 board_screen.dart가 합니다.

import 'package:flutter/material.dart';

import '../models/board.dart';
import '../repositories/board_repository.dart';
import '../repositories/reference_repository.dart';
import '../services/image_storage.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/date_format.dart';
import '../utils/id_generator.dart';
import '../widgets/board_name_dialog.dart';
import '../widgets/empty_state_message.dart';
import 'board_screen.dart';

/// 무드보드 목록 화면입니다.
class BoardListScreen extends StatefulWidget {
  const BoardListScreen({
    super.key,
    required this.boardRepository,
    required this.referenceRepository,
    required this.imageStorage,
  });

  /// 무드보드를 읽고 쓰는 통로입니다.
  final BoardRepository boardRepository;

  /// 레퍼런스를 읽는 통로입니다. 판을 열 때 그대로 넘겨줍니다.
  final ReferenceRepository referenceRepository;

  /// 이미지 파일 경로를 알려주는 도구입니다. 판을 열 때 그대로 넘겨줍니다.
  final ImageStorage imageStorage;

  @override
  State<BoardListScreen> createState() => _BoardListScreenState();
}

class _BoardListScreenState extends State<BoardListScreen> {
  /// 지금 보여주고 있는 무드보드 목록입니다.
  List<Board> _boards = <Board>[];

  /// 판 번호 → 그 판에 올라간 카드 장수
  Map<String, int> _cardCounts = <String, int>{};

  /// 아직 목록을 읽어오는 중인지 여부입니다.
  bool _isLoading = true;

  /// 화면이 만들어질 때 목록을 읽어옵니다.
  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  /// 무드보드 목록과 카드 장수를 읽어옵니다.
  Future<void> _loadBoards() async {
    final List<Board> boards = await widget.boardRepository.getAllBoards();
    final Map<String, int> counts = await widget.boardRepository
        .countCardsByBoard();

    // 읽어오는 사이에 사용자가 화면을 떠났을 수 있습니다.
    if (!mounted) {
      return;
    }

    setState(() {
      _boards = boards;
      _cardCounts = counts;
      _isLoading = false;
    });
  }

  /// 새 무드보드를 만듭니다. 만들고 나면 **바로 그 판을 엽니다.**
  ///
  /// 만들자마자 목록으로 돌아오면 방금 만든 것을 또 눌러야 합니다.
  /// 만드는 사람은 이미 그 판에서 작업할 생각이므로 곧장 데려다줍니다.
  Future<void> _createBoard() async {
    final String? name = await showBoardNameDialog(
      context: context,
      title: '새 무드보드 만들기',
      confirmLabel: '만들기',
    );

    if (name == null || !mounted) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final Board board = Board(
      id: newId(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await widget.boardRepository.saveBoard(board);

    if (!mounted) {
      return;
    }

    await _openBoard(board);
  }

  /// 무드보드를 엽니다. 돌아오면 목록을 다시 읽습니다.
  ///
  /// 다시 읽는 이유: 판에서 카드를 올리거나 내렸으면 목록에 보이는 장수가
  /// 달라져 있습니다. 안 읽으면 예전 숫자가 그대로 남아 틀린 정보가 됩니다.
  Future<void> _openBoard(Board board) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BoardScreen(
          board: board,
          boardRepository: widget.boardRepository,
          referenceRepository: widget.referenceRepository,
          imageStorage: widget.imageStorage,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadBoards();
  }

  /// 무드보드 이름을 바꿉니다.
  Future<void> _renameBoard(Board board) async {
    final String? name = await showBoardNameDialog(
      context: context,
      title: '무드보드 이름 바꾸기',
      confirmLabel: '바꾸기',
      initialName: board.name,
    );

    if (name == null || !mounted) {
      return;
    }

    await widget.boardRepository.saveBoard(board.copyWith(name: name));

    if (!mounted) {
      return;
    }
    await _loadBoards();
  }

  /// 무드보드를 지웁니다. 지우기 전에 확인을 받습니다.
  Future<void> _deleteBoard(Board board) async {
    final bool confirmed = await _confirmDelete(board);

    if (!confirmed || !mounted) {
      return;
    }

    await widget.boardRepository.deleteBoard(board.id);

    if (!mounted) {
      return;
    }
    await _loadBoards();
  }

  /// 정말 지울지 물어봅니다. 지운다고 하면 true입니다.
  ///
  /// **"사진은 지워지지 않는다"를 분명히 적어줍니다.** 이 말이 없으면 판을
  /// 지우면 안에 있던 사진까지 사라지는 줄 알고 못 지웁니다.
  Future<bool> _confirmDelete(Board board) async {
    final int count = _cardCounts[board.id] ?? 0;

    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('"${board.name}"을(를) 지울까요?'),
          content: Text(
            count == 0
                ? '이 무드보드를 지웁니다.'
                : '판에 올려둔 카드 $count장의 배치가 함께 사라집니다.\n'
                      '레퍼런스 자체는 목록에 그대로 남습니다.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('지우기'),
            ),
          ],
        );
      },
    );

    // 바깥을 눌러 닫으면 null이 옵니다. 그때는 안 지운 것으로 봅니다.
    return answer ?? false;
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('무드보드')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBoard,
        icon: const Icon(Icons.add),
        label: const Text('새 무드보드'),
      ),

      body: _buildBody(),
    );
  }

  /// 화면 가운데 내용을 만듭니다. 상황에 따라 셋 중 하나입니다.
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_boards.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      // 아래쪽 여백을 크게 준 이유: 안 그러면 마지막 줄이
      // 오른쪽 아래 떠 있는 버튼에 가려집니다.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _boards.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildBoardTile(_boards[index]);
      },
    );
  }

  /// 아직 무드보드가 하나도 없을 때의 안내입니다.
  Widget _buildEmptyState() {
    // 버튼을 안 붙인 이유: 오른쪽 아래에 "새 무드보드" 버튼이 이미 떠 있습니다.
    // 같은 버튼이 두 개 보이면 어느 쪽을 눌러야 하나 잠깐 멈칫하게 됩니다.
    return const EmptyStateMessage(
      icon: Icons.dashboard_customize_outlined,
      title: '아직 만든 무드보드가 없습니다',
      body: '무드보드는 레퍼런스를 원하는 자리에 늘어놓고\n분위기를 잡아보는 판입니다.',
    );
  }

  /// 목록의 무드보드 한 줄을 만듭니다.
  Widget _buildBoardTile(Board board) {
    final AppPalette palette = AppPalette.of(context);
    final int count = _cardCounts[board.id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openBoard(board),
        leading: const Icon(Icons.dashboard_outlined),
        title: Text(board.name),
        subtitle: Text(
          '카드 $count장 · ${formatCardDate(board.updatedAt)} 수정',
          style: AppText.meta.copyWith(color: palette.textDim),
        ),

        // 이름 바꾸기와 지우기는 자주 쓰지 않아서 메뉴 안에 넣습니다.
        // 줄마다 버튼을 두 개씩 늘어놓으면 정작 중요한 "열기"가 묻힙니다.
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            if (value == 'rename') {
              _renameBoard(board);
            } else if (value == 'delete') {
              _deleteBoard(board);
            }
          },
          itemBuilder: (BuildContext context) {
            return const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'rename', child: Text('이름 바꾸기')),
              PopupMenuItem<String>(value: 'delete', child: Text('지우기')),
            ];
          },
        ),
      ),
    );
  }
}
