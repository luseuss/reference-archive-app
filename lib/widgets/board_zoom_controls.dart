// 판 오른쪽 아래에 떠 있는 확대·축소 버튼 묶음입니다.
//
// ── 왜 화면 위에 떠 있나 (위쪽 막대에 두지 않고) ──
// 확대·축소는 판을 보면서 계속 누르게 되는 버튼입니다. 위쪽 막대까지 마우스를
// 올렸다 내렸다 하면 보던 자리를 자꾸 놓칩니다. 그림 편집 프로그램들이 대체로
// 이 자리에 두는 것도 같은 이유입니다.
//
// ── 이 파일은 배율을 기억하지 않습니다 ──
// 지금 몇 배인지는 board_viewport.dart가 알고 있고, 여기는 받아서 보여주기만 합니다.
// 버튼도 직접 확대하지 않고 "눌렸다"고 알리기만 합니다.

import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_text.dart';

/// 확대·축소 버튼 묶음입니다.
class BoardZoomControls extends StatelessWidget {
  const BoardZoomControls({
    super.key,
    required this.scale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetToFit,
  });

  /// 지금 배율입니다. 1이면 원래 크기입니다.
  final double scale;

  /// 확대 버튼을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onZoomIn;

  /// 축소 버튼을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onZoomOut;

  /// "판 전체 보기"를 눌렀을 때 실행할 동작입니다.
  final VoidCallback onResetToFit;

  /// 버튼 묶음의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    // Material로 감싸면 그림자가 지고 버튼의 물결 효과가 나옵니다.
    // 판 위에 얹히는 것이라 바탕이 뚜렷해야 카드와 섞이지 않습니다.
    return Material(
      color: colors.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(buttonCornerRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove),
              tooltip: '축소',
            ),

            // 지금 몇 배인지 보여줍니다. 없으면 "얼마나 확대했더라?"를
            // 알 방법이 없어서, 원래 크기로 돌아왔는지도 알 수 없습니다.
            //
            // 너비를 고정한 이유: 숫자 자릿수가 바뀔 때마다 옆 버튼이
            // 밀려서, 연달아 누르면 커서 밑에서 버튼이 도망갑니다.
            SizedBox(
              width: 52,
              child: Text(
                '${(scale * 100).round()}%',
                textAlign: TextAlign.center,
                style: AppText.meta.copyWith(color: colors.onSurface),
              ),
            ),

            IconButton(
              onPressed: onZoomIn,
              icon: const Icon(Icons.add),
              tooltip: '확대',
            ),

            // 세로 실선 하나로 "성격이 다른 버튼"임을 나눠줍니다.
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: colors.outlineVariant,
            ),

            IconButton(
              onPressed: onResetToFit,
              icon: const Icon(Icons.fit_screen_outlined),
              tooltip: '판 전체 보기',
            ),
          ],
        ),
      ),
    );
  }
}
