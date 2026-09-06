// 휴지통 화면입니다. 지운 레퍼런스를 되살리거나 영영 지웁니다.
//
// ── 왜 필요한가 ──
// 이 앱은 레퍼런스를 지워도 **진짜로 지우지 않습니다**(deletedAt에 시각만
// 찍는 소프트 삭제 — CLAUDE.md 설계 원칙 5). 그런데 그렇게 지워둔 것을
// 다시 볼 방법이 여태 없어서, 실수로 지우면 사실상 되찾을 수 없었습니다.
// 데이터는 사진 파일까지 그대로 남아 있었으므로, 이 화면 하나로 되살리기가
// 그대로 됩니다.
//
// ── 되살리기는 왜 안 물어보나 ──
// 되돌리기 쉬운 일에 매번 확인을 받으면 사용자는 확인 창을 안 읽고 누르는
// 버릇이 들고, 정작 위험한 확인(영영 지우기)도 그냥 넘기게 됩니다.
// board_interaction_controller.dart가 카드를 내릴 때 쓴 기준과 같습니다.
//
// 실제 동작(읽어오기·되살리기·영영 지우기)은 trash_controller.dart가 합니다.
// 이 파일은 화면을 조립하고 확인 대화상자를 띄우는 일만 합니다.

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/reference_item.dart';
import '../repositories/reference_repository.dart';
import '../services/image_storage.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';
import '../utils/date_format.dart';
import '../widgets/empty_state_message.dart';
import 'trash_controller.dart';

/// 지운 레퍼런스를 되살리거나 영영 지우는 화면입니다.
class TrashScreen extends StatefulWidget {
  const TrashScreen({
    super.key,
    required this.repository,
    required this.imageStorage,
  });

  /// 레퍼런스를 읽고 쓰는 통로입니다.
  final ReferenceRepository repository;

  /// 영영 지울 때 사진 파일을 지우는 데 씁니다.
  final ImageStorage imageStorage;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final TrashController _trash;

  @override
  void initState() {
    super.initState();

    _trash = TrashController(
      repository: widget.repository,
      imageStorage: widget.imageStorage,
    );
    _trash.load();
  }

  @override
  void dispose() {
    _trash.dispose();
    super.dispose();
  }

  /// 지운 레퍼런스 하나를 되살립니다. 확인은 받지 않습니다(파일 위 설명 참고).
  Future<void> _restore(ReferenceItem item) async {
    await _trash.restore(item);

    if (!mounted) {
      return;
    }
    _showMessage('"${_titleOf(item)}"을(를) 되살렸습니다.');
  }

  /// 레퍼런스 하나를 영영 지웁니다. 되돌릴 수 없어서 먼저 확인을 받습니다.
  Future<void> _purge(ReferenceItem item) async {
    final bool confirmed = await _confirm(
      title: '"${_titleOf(item)}"을(를) 영영 지울까요?',
      body: '사진 파일까지 완전히 사라집니다. 되돌릴 수 없습니다.',
      confirmLabel: '영영 지우기',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _trash.purge(item);

    if (!mounted) {
      return;
    }
    _showMessage('영영 지웠습니다.');
  }

  /// 휴지통을 통째로 비웁니다. 되돌릴 수 없어서 먼저 확인을 받습니다.
  Future<void> _purgeAll() async {
    final int count = _trash.items.length;

    final bool confirmed = await _confirm(
      title: '휴지통을 비울까요?',
      body: '$count개가 사진 파일까지 완전히 사라집니다. 되돌릴 수 없습니다.',
      confirmLabel: '비우기',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _trash.purgeAll();

    if (!mounted) {
      return;
    }
    _showMessage('휴지통을 비웠습니다.');
  }

  /// 되돌릴 수 없는 일을 하기 전에 물어봅니다. 하겠다고 하면 true입니다.
  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    // 바깥을 눌러 닫으면 null이 옵니다. 그때는 안 하는 것으로 봅니다.
    return answer ?? false;
  }

  /// 화면 아래에 잠깐 뜨는 안내입니다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 제목이 비어 있는 레퍼런스도 있어서, 그때 보여줄 대체 글자를 정합니다.
  String _titleOf(ReferenceItem item) {
    return item.title.isEmpty ? '(제목 없음)' : item.title;
  }

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // ListenableBuilder = 컨트롤러가 바뀌면 이 안을 다시 그려주는 위젯입니다.
    return ListenableBuilder(
      listenable: _trash,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('휴지통'),
            actions: <Widget>[
              // 비어 있을 때는 눌러도 뜻이 없어서 막아둡니다.
              TextButton(
                onPressed: _trash.isEmpty ? null : _purgeAll,
                child: const Text('휴지통 비우기'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  /// 화면 가운데 내용을 만듭니다. 상황에 따라 셋 중 하나입니다.
  Widget _buildBody() {
    if (_trash.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trash.isEmpty) {
      return const EmptyStateMessage(
        icon: Icons.delete_outline,
        title: '휴지통이 비어 있습니다',
        body: '레퍼런스를 지우면 여기로 옵니다.\n영영 지우기 전까지는 언제든 되살릴 수 있습니다.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(screenPaddingHorizontal),
      itemCount: _trash.items.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildRow(_trash.items[index]);
      },
    );
  }

  /// 휴지통의 한 줄을 만듭니다.
  Widget _buildRow(ReferenceItem item) {
    final AppPalette palette = AppPalette.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: _buildThumbnail(item, palette),
        title: Text(_titleOf(item)),
        subtitle: Text(
          // 언제 지웠는지를 보여줍니다. "내가 방금 지운 그것"을 찾는 데
          // 가장 도움이 되는 정보라 날짜를 답니다.
          '${formatCardDate(item.updatedAt)} 지움',
          style: AppText.meta.copyWith(color: palette.textDim),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: () => _restore(item),
              child: const Text('되살리기'),
            ),
            IconButton(
              onPressed: () => _purge(item),
              icon: const Icon(Icons.delete_forever_outlined),
              tooltip: '영영 지우기',
            ),
          ],
        ),
      ),
    );
  }

  /// 줄 왼쪽에 보여줄 작은 그림입니다. 경로가 없거나 파일이 사라졌으면
  /// 자리표시자를 보여줍니다.
  Widget _buildThumbnail(ReferenceItem item, AppPalette palette) {
    final String? path = _trash.imagePaths[item.id];

    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(appCornerRadius),
        child: path == null
            ? _buildPlaceholder(palette)
            : Image.file(
                File(path),
                fit: BoxFit.cover,

                // 파일이 어떤 이유로든 없으면 앱이 죽지 않고 자리표시자를
                // 보여줍니다. 휴지통에는 오래된 것이 들어있기 마련이라
                // 파일이 먼저 사라진 경우를 대비해둡니다.
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                      return _buildPlaceholder(palette);
                    },
              ),
      ),
    );
  }

  /// 그림을 못 보여줄 때 대신 놓는 회색 네모입니다.
  Widget _buildPlaceholder(AppPalette palette) {
    return ColoredBox(
      color: palette.background,
      child: Icon(Icons.image_outlined, color: palette.textDim, size: 20),
    );
  }
}
