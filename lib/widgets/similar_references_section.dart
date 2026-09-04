// 레퍼런스 상세 화면 아래쪽에 붙는 "비슷한 레퍼런스" 묶음입니다.
//
// 태그·분류·사진 생김새가 닮은 다른 레퍼런스를 보여줘서, 있는 줄도 몰랐던
// 연관 자료를 다시 찾게 도와줍니다. **무엇을 "비슷하다"고 볼지 계산하는 일**은
// lib/utils/similarity.dart에 있고, 이 위젯은 그 결과를 늘어놓아 보여주기만
// 합니다 — 카드가 판을 모르듯, 이 섹션도 유사도 점수를 어떻게 매기는지 모릅니다.
//
// 기존 웹앱의 "비슷한 레퍼런스" 미리보기 섹션과 같은 문턱값·개수를 씁니다
// (reference-archive 저장소의 `renderPreviewSimilar`/`PREVIEW_SIMILAR_THRESHOLD`).

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/reference_item.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// 이 문턱보다 낮은 유사도는 "우연히 태그 하나 겹친" 수준이라, 추천으로
/// 보여줄 만큼 의미 있지 않다고 봅니다. (기존 웹앱과 같은 값)
const double similarReferencesThreshold = 0.12;

/// 이 섹션에 한 번에 보여줄 최대 개수입니다. (기존 웹앱과 같은 값)
const int similarReferencesLimit = 6;

/// 비슷한 레퍼런스들을 작은 그림 묶음으로 보여줍니다.
class SimilarReferencesSection extends StatelessWidget {
  const SimilarReferencesSection({
    super.key,
    required this.items,
    required this.imagePaths,
    required this.onTap,
  });

  /// 보여줄 비슷한 레퍼런스들입니다.
  ///
  /// 유사도 내림차순으로 이미 정렬되어 있어야 합니다 — `similarItems`
  /// (lib/utils/similarity.dart)가 그렇게 돌려줍니다. 여기서는 다시
  /// 정렬하지 않고 받은 순서 그대로 보여줍니다.
  final List<ReferenceItem> items;

  /// 레퍼런스 번호로 이미지 파일의 전체 경로를 찾는 표입니다. (id → 경로)
  final Map<String, String?> imagePaths;

  /// 카드를 눌렀을 때 실행할 동작입니다. 그 레퍼런스의 상세 화면을 여는 데 씁니다.
  final ValueChanged<ReferenceItem> onTap;

  /// 섹션의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 다른 항목들과 같은 라벨 스타일을 씁니다("메모" 라벨과 동일).
        Text('비슷한 레퍼런스', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),

        if (items.isEmpty)
          Text(
            '비슷한 레퍼런스가 없어요',
            style: AppText.meta.copyWith(color: palette.textDim),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ReferenceItem item in items) _buildTile(context, item),
            ],
          ),
      ],
    );
  }

  /// 한 장의 작은 카드를 만듭니다. 그림 + 제목 한 줄입니다.
  Widget _buildTile(BuildContext context, ReferenceItem item) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = AppPalette.of(context);
    final String? path = imagePaths[item.id];

    return InkWell(
      onTap: () => onTap(item),
      borderRadius: BorderRadius.circular(inputCornerRadius),
      child: SizedBox(
        // 기존 웹앱의 `minmax(88px, 1fr)` 격자 칸과 같은 너비입니다.
        width: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              // 고르는 화면(pick_references_dialog.dart)과 같은 이유로,
              // 여기서는 원본 비율이 아니라 정사각형으로 **잘라서** 채웁니다.
              // 훑어보기 좋은 목록이 목적이라, 칸 크기가 들쭉날쭉하면 안 됩니다.
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(inputCornerRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: path == null
                    ? Icon(
                        Icons.image_outlined,
                        color: colors.onSurfaceVariant,
                      )
                    : Image.file(
                        File(path),
                        fit: BoxFit.cover,

                        // 파일이 지워졌거나 깨졌을 때 화면 전체가 오류로
                        // 덮이지 않게 막습니다.
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stack,
                            ) {
                              return Icon(
                                Icons.broken_image_outlined,
                                color: colors.onSurfaceVariant,
                              );
                            },
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.title.isEmpty ? '(제목 없음)' : item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.meta.copyWith(color: palette.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
