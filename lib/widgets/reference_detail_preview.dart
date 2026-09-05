// 레퍼런스 편집 화면 위쪽의 미리보기입니다. 유튜브면 그 위에 재생 버튼이
// 얹힙니다.
//
// reference_detail_screen.dart에서 뺐습니다(CLAUDE.md "밀린 정리거리"
// 참고). 상태 없이 값만 받아 그리는 조각이라, reference_card_thumbnail.dart를
// 뺀 것과 같은 이유로 그대로 옮길 수 있었습니다.

import 'dart:io';

import 'package:flutter/material.dart';

/// 편집 화면 위쪽의 큰 미리보기입니다.
class ReferenceDetailPreview extends StatelessWidget {
  const ReferenceDetailPreview({
    super.key,
    required this.imagePath,
    required this.isYoutube,
    required this.onPlay,
  });

  /// 이미지 파일의 전체 경로입니다. 아직 못 구했으면 null입니다.
  final String? imagePath;

  /// 유튜브 레퍼런스인지 여부입니다. 참이면 재생 버튼이 얹힙니다.
  final bool isYoutube;

  /// 재생 버튼을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    Widget content;
    if (imagePath == null) {
      // 이미지는 파일이 아직 없는 경우이고,
      // 유튜브는 썸네일을 못 받아온 경우입니다. (인터넷이 없었거나 비공개 영상)
      content = Icon(
        isYoutube ? Icons.play_circle_outline : Icons.image_outlined,
        size: 48,
        color: colors.onSurfaceVariant,
      );
    } else {
      content = Image.file(
        File(imagePath!),
        fit: BoxFit.contain,
        // 파일이 지워졌거나 깨졌을 때 화면 전체가 오류로 덮이지 않게 합니다.
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: colors.onSurfaceVariant,
          );
        },
      );
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: isYoutube
          // 유튜브는 미리보기 위에 재생 버튼을 겹쳐서, 눌러 바로 볼 수 있게 합니다.
          ? Stack(
              children: <Widget>[
                Positioned.fill(child: Center(child: content)),
                Positioned.fill(
                  child: Material(
                    // 투명한 Material 위에 InkWell을 두면 누를 때 물결이 나옵니다.
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPlay,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 72,
                          // 썸네일이 밝든 어둡든 보이도록 흰색에 그림자를 줍니다.
                          color: Colors.white.withValues(alpha: 0.92),
                          shadows: const <Shadow>[
                            Shadow(color: Colors.black54, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(child: content),
    );
  }
}
