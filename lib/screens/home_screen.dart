// 앱을 켰을 때 가장 먼저 보이는 화면입니다.
//
// 1단계(뼈대와 저장)에서는 아직 레퍼런스 목록이 없기 때문에,
// 지금은 "앱이 정상적으로 실행됐다"는 것만 확인시켜주는 안내 화면입니다.
// 레퍼런스 목록이 만들어지면 이 화면의 body 부분을 목록 위젯으로 바꾸게 됩니다.

import 'package:flutter/material.dart';

/// 앱의 첫 화면입니다.
///
/// StatelessWidget = 스스로 바뀌는 값이 없는 화면입니다.
/// 나중에 목록/검색처럼 "변하는 값"이 생기면 StatefulWidget으로 바꾸거나
/// 상태 관리 도구를 붙이게 됩니다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// 화면의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // Theme.of(context)로 main.dart에서 정한 테마 색을 꺼내 씁니다.
    // 이렇게 하면 밝은 모드/어두운 모드에서 색이 알아서 바뀝니다.
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textStyles = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('레퍼런스 아카이브'),
        backgroundColor: colors.surfaceContainerHighest,
      ),
      body: Center(
        // Padding으로 좌우 여백을 줘서 좁은 화면(폰)에서 글자가 가장자리에 붙지 않게 합니다.
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: colors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '레퍼런스 아카이브',
                style: textStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '1단계: 뼈대와 저장 준비 중입니다.\n'
                '곧 이 화면에 저장한 레퍼런스 목록이 표시됩니다.',
                style: textStyles.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
