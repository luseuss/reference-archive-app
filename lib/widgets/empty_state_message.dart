// 화면에 보여줄 것이 하나도 없을 때 가운데에 띄우는 안내입니다.
//
// ── 빈 화면을 그냥 두면 안 되는 이유 ──
// 아무것도 없는 흰 화면은 "아직 안 만든 것"인지 "고장난 것"인지 구분이 안 됩니다.
// 무엇이 없는지, 그래서 무엇을 하면 되는지를 적어주면 그 자리에서 다음 행동으로
// 이어집니다.
//
// ── 왜 따로 빼뒀나 ──
// 무드보드 목록·판·레퍼런스 목록이 전부 같은 모양(아이콘 → 제목 → 설명 → 버튼)의
// 안내를 씁니다. 화면마다 따로 적어두면 나중에 "안내 글씨를 좀 더 옅게" 같은
// 요청이 왔을 때 어디를 다 고쳐야 하는지 알 수 없게 됩니다.

import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// 보여줄 것이 없을 때의 안내입니다.
class EmptyStateMessage extends StatelessWidget {
  const EmptyStateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  /// 위에 띄울 그림 표시입니다.
  final IconData icon;

  /// 굵은 한 줄. **무엇이 없는지**를 적습니다.
  final String title;

  /// 그 아래 설명. **그래서 무엇을 하면 되는지**를 적습니다.
  final String body;

  /// 아래에 붙일 버튼입니다. 없으면 null입니다.
  ///
  /// 안내만으로 충분할 때도 있고(예: 사이드바에 이미 만들기 버튼이 보일 때),
  /// 바로 누를 수 있는 버튼이 있는 편이 나을 때도 있습니다.
  final Widget? action;

  /// 안내의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(screenPaddingHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 아이콘까지 강조색이면 시선을 너무 끕니다. 안내는 거들 뿐이라
            // 옅게 두고, 눌러야 할 버튼만 또렷하게 남깁니다.
            Icon(icon, size: 64, color: palette.textDim),

            const SizedBox(height: 24),
            Text(
              title,
              style: AppText.emptyTitle.copyWith(color: palette.text),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 6),
            Text(
              body,
              style: AppText.emptyBody.copyWith(color: palette.textDim),
              textAlign: TextAlign.center,
            ),

            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
