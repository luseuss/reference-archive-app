// 화면 왼쪽에 붙는 사이드바입니다.
//
// 의뢰인이 정해준 목업의 ①②③에 해당합니다.
//
//   ① 위   — 사용자 (지금은 이름만. 로그인 기능은 아직 없습니다)
//   ② 가운데 — 파트 목록 (디자인/파티클 등 큰 갈래로 레퍼런스 나눠 보기)
//   ③ 아래  — 설정 · 로그인/로그아웃
//
// ── 색이 본문과 다릅니다 ──
// 목업에서 사이드바만 짙은 색입니다. 본문은 밝은데 사이드바는 어둡게 두면
// "여기는 성격이 다른 영역"이라는 것이 한눈에 보입니다.
// 그래서 밝은 모드에서도 사이드바는 어두운 색을 씁니다.

import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// 사이드바의 너비입니다. (기존 웹앱의 `flex: 0 0 176px`보다 조금 넓게)
const double sidebarWidth = 232;

/// 사이드바를 항상 펼쳐둘 최소 창 너비입니다.
///
/// 이보다 좁으면 사이드바가 목록을 너무 많이 잡아먹습니다. 그래서 폰이나
/// 좁은 창에서는 평소엔 숨겨두고 메뉴 버튼으로 꺼내 씁니다.
const double sidebarBreakpoint = 900;

/// 화면 왼쪽 사이드바입니다.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.userName,
    required this.onOpenSettings,
    required this.onLogInOut,
  });

  /// ①에 보여줄 사용자 이름입니다.
  final String userName;

  /// 설정을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onOpenSettings;

  /// 로그인/로그아웃을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onLogInOut;

  /// 사이드바의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    // 사이드바는 밝은 모드에서도 어두운 색을 씁니다.
    // 그래서 지금 모드와 상관없이 어두운 모드 색을 가져다 씁니다.
    const AppPalette dark = AppPalette.dark;

    return Container(
      width: sidebarWidth,
      color: dark.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildUserBlock(dark),

              const SizedBox(height: 20),

              // ② 파트 목록입니다. Expanded로 감싸 남는 공간을 다 차지하게 하면,
              // ③(설정)이 언제나 맨 아래에 붙습니다.
              Expanded(child: _buildPartList(dark)),

              const SizedBox(height: 12),
              _buildBottomBlock(dark),
            ],
          ),
        ),
      ),
    );
  }

  /// ① 사용자 부분입니다.
  Widget _buildUserBlock(AppPalette dark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(color: dark.border),
      ),
      child: Row(
        children: <Widget>[
          // 사진이 없으므로 이름 첫 글자로 대신합니다.
          CircleAvatar(
            radius: 18,
            backgroundColor: dark.accentSoft,
            child: Text(
              _initial(),
              style: TextStyle(
                color: dark.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  // 로그인 기능이 없다는 것을 숨기지 않고 그대로 적습니다.
                  // 가짜 계정 아이디를 지어내면 나중에 진짜 로그인을 붙일 때
                  // 사용자가 혼란스러워집니다.
                  '로그인 안 함',
                  style: AppText.meta.copyWith(color: dark.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ② 파트 목록입니다.
  ///
  /// **아직 파트 기능이 없어서 "전체"만 있습니다.** 파트를 저장하려면
  /// 데이터베이스 구조를 바꿔야 해서(마이그레이션) 다음 작업으로 미뤘습니다.
  /// 지금은 모든 레퍼런스가 한곳에 있으므로 "전체"만 있는 것이 사실 그대로입니다.
  Widget _buildPartList(AppPalette dark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: dark.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(color: dark.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildNavItem(
            dark,
            icon: Icons.photo_library_outlined,
            label: '전체 레퍼런스',
            isSelected: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  /// ③ 아래쪽 설정·로그인 부분입니다.
  Widget _buildBottomBlock(AppPalette dark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: dark.surface,
        borderRadius: BorderRadius.circular(appCornerRadius),
        border: Border.all(color: dark.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildNavItem(
            dark,
            icon: Icons.settings_outlined,
            label: '설정',
            isSelected: false,
            onTap: onOpenSettings,
          ),
          _buildNavItem(
            dark,
            icon: Icons.login_outlined,
            label: '로그인',
            isSelected: false,
            onTap: onLogInOut,
          ),
        ],
      ),
    );
  }

  /// 사이드바 안의 누를 수 있는 줄 하나를 만듭니다.
  ///
  /// ②와 ③이 같은 모양이라 하나로 만들어 돌려씁니다.
  Widget _buildNavItem(
    AppPalette dark, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // 고른 항목은 배경을 밝게 깔아 구분합니다.
    final Color foreground = isSelected ? dark.accent : dark.textDim;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(inputCornerRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? dark.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(inputCornerRadius),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.folderChip.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 이름의 첫 글자를 돌려줍니다. 아바타 자리에 씁니다.
  String _initial() {
    final String trimmed = userName.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1);
  }
}
