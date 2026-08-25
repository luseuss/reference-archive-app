// 목록에 보이는 레퍼런스 카드 한 장입니다.
//
// 화면(screens/) 파일이 너무 길어지지 않도록 카드 한 장의 생김새는 여기로 뺐습니다.
// 나중에 카드에 즐겨찾기 별표나 태그 표시를 붙일 때도 이 파일만 보면 됩니다.

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/reference_item.dart';

/// 레퍼런스 한 건을 보여주는 카드입니다.
class ReferenceCard extends StatelessWidget {
  const ReferenceCard({
    super.key,
    required this.item,
    required this.imagePath,
    required this.onDelete,
  });

  /// 보여줄 레퍼런스
  final ReferenceItem item;

  /// 이미지 파일의 전체 경로입니다.
  ///
  /// 데이터베이스에는 파일 이름만 들어있어서, 화면에 띄우려면 실제 경로가 필요합니다.
  /// 경로를 아직 못 구했으면 null입니다.
  final String? imagePath;

  /// 삭제 버튼을 눌렀을 때 실행할 동작입니다.
  ///
  /// 카드가 직접 지우지 않고 "눌렸다"고 알리기만 합니다.
  /// 실제로 지우는 일은 화면(home_screen.dart)이 합니다.
  /// 카드는 생김새만 책임지게 두는 편이 나중에 고치기 쉽습니다.
  final VoidCallback onDelete;

  /// 카드의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 카드의 그림 부분입니다. 남는 공간을 전부 차지하도록 Expanded로 감쌉니다.
          Expanded(child: _buildThumbnail(colors)),

          // 카드 아래쪽 제목과 삭제 버튼입니다.
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.title.isEmpty ? '(제목 없음)' : item.title,
                    // 제목이 길면 카드를 밀어내지 않고 ...으로 줄입니다.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                  iconSize: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 카드의 그림 부분을 만듭니다.
  Widget _buildThumbnail(ColorScheme colors) {
    // 유튜브는 3단계에서 붙입니다. 지금은 자리만 표시해둡니다.
    if (item.type == ReferenceType.youtube) {
      return _buildPlaceholder(colors, Icons.play_circle_outline);
    }

    // 경로를 아직 못 구했거나 파일 이름이 없으면 자리표시자를 보여줍니다.
    if (imagePath == null) {
      return _buildPlaceholder(colors, Icons.image_outlined);
    }

    return Image.file(
      File(imagePath!),
      fit: BoxFit.cover,

      // 파일이 지워졌거나 깨졌을 때 앱이 죽지 않도록 대비합니다.
      // 이게 없으면 파일 하나가 잘못돼도 목록 전체가 빨간 오류 화면이 됩니다.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return _buildPlaceholder(colors, Icons.broken_image_outlined);
      },
    );
  }

  /// 그림을 못 보여줄 때 대신 띄우는 회색 상자입니다.
  Widget _buildPlaceholder(ColorScheme colors, IconData icon) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 40, color: colors.onSurfaceVariant),
      ),
    );
  }
}
