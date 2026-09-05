// 목록 화면 전체를 "끌어다 놓을 수 있는 영역"으로 감싸는 곳입니다.
//
// home_screen.dart에서 뺐습니다(CLAUDE.md "밀린 정리거리" 참고). "지금
// 끌고 있는 중인지" 상태와 그 상태에 따라 안내를 덧그리는 일이 함께
// 다녀야 하는데, 그 상태(`_isDragging`)를 쓰는 곳이 이 위젯 하나뿐이라
// StatefulWidget으로 통째로 옮겨서 home_screen.dart가 그 상태를 몰라도
// 되게 했습니다.

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../services/dropped_item_reader.dart';

/// 화면 전체를 감싸 파일을 끌어다 놓을 수 있게 합니다.
///
/// 끄는 중일 때는 테두리와 안내를 덧그려서 "여기 놓으면 된다"를 알려줍니다.
/// 아무 표시가 없으면 사용자는 놓아도 되는지 알 수 없습니다.
class HomeDropArea extends StatefulWidget {
  const HomeDropArea({super.key, required this.onDrop, required this.child});

  /// 파일을 놓았을 때 실행할 동작입니다.
  final Future<void> Function(PerformDropEvent event) onDrop;

  /// 감쌀 내용입니다.
  final Widget child;

  @override
  State<HomeDropArea> createState() => _HomeDropAreaState();
}

class _HomeDropAreaState extends State<HomeDropArea> {
  /// 지금 무언가를 창 위로 끌고 있는 중인지 여부입니다.
  /// 켜져 있으면 "여기 놓으세요" 안내를 덧그립니다.
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return DropRegion(
      // 받을 수 있다고 알릴 형식들입니다. 여기 없는 형식은 아예 안 들어옵니다.
      // (앞서 쓰던 desktop_drop은 파일 형식만 받아서 브라우저 드래그가 막혔습니다)
      // 목록 자체는 dropped_item_reader.dart에 있습니다. 받는 쪽과 읽는 쪽이
      // 따로 놀면 "받아는 놓고 읽지 못하는" 형식이 생기기 때문입니다.
      formats: dropRegionFormats,

      // 끌고 지나가는 동안 "복사할 수 있다"고 알려줍니다.
      // none을 돌려주면 커서에 금지 표시가 뜨고 놓을 수 없습니다.
      onDropOver: (DropOverEvent event) => DropOperation.copy,

      onDropEnter: (DropEvent event) {
        setState(() => _isDragging = true);
      },
      onDropLeave: (DropEvent event) {
        setState(() => _isDragging = false);
      },
      onPerformDrop: (PerformDropEvent event) async {
        setState(() => _isDragging = false);
        await widget.onDrop(event);
      },
      child: Stack(
        children: <Widget>[
          widget.child,

          // 끄는 중에만 위에 덧그립니다.
          if (_isDragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  // 반투명이라 아래 목록이 비쳐 보입니다.
                  color: colors.primary.withValues(alpha: 0.12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.file_download_outlined,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '여기에 놓으면 레퍼런스로 추가됩니다',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
