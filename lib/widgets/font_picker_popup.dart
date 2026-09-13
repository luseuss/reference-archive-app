// 무드보드 텍스트 카드의 "글꼴 고르기" 전용 팝업입니다.
//
// ── 왜 flutter_quill 기본 드롭다운을 안 쓰나 ──
// flutter_quill이 기본 제공하는 글꼴 선택 드롭다운은 한 줄짜리 목록이라
// 이 컴퓨터에 글꼴이 수십~수백 개 설치돼 있으면 이름만 쭉 나열되어
// 찾기 어렵고, 실제로 그 글꼴이 어떻게 생겼는지 미리 볼 방법도
// 없습니다. 이 파일은 그 대신 (1) 한국어/영어/일본어/중국어/특수문자
// 다섯 구역으로 나누고 (2) 각 줄을 그 글꼴로 직접 렌더링해 미리보기를
// 보여주는 작은 팝업을 직접 만듭니다.
//
// ── 왜 showMenu가 아니라 OverlayEntry를 직접 쓰나 ──
// showMenu(context_menu.dart가 씀)는 항목 하나를 고르면 메뉴가 곧바로
// 닫힙니다. 여기서는 "여러 글꼴을 눌러보며 미리보기를 비교"하는
// 용도가 아니라 "하나 고르면 바로 반영되고 닫힌다"가 맞는 동작이라
// 사실 showMenu와 비슷하지만, 커스텀 스크롤 목록(구역 나누기)을
// PopupMenuItem 하나에 욱여넣는 것보다 직접 Overlay를 다루는 편이
// 읽기 쉬워서 이렇게 했습니다.

import 'package:flutter/material.dart';

import '../services/system_fonts.dart';
import '../theme/app_palette.dart';

/// 팝업 안에서 다룰 글꼴 한 줄입니다.
class _FontEntry {
  const _FontEntry({
    required this.group,
    required this.label,
    required this.familyName,
    this.systemFont,
  });

  /// 어느 구역(예: "기본 글꼴", "한국어")에 속하는지입니다.
  final String group;

  /// 화면에 보여줄 이름입니다.
  final String label;

  /// 실제 `TextStyle(fontFamily: ...)`에 넣을 이름입니다.
  final String familyName;

  /// 번들 글꼴(Pretendard·Gowun Batang)이면 null입니다 — 이미 앱에
  /// 담겨 있어 따로 읽어올 파일이 없습니다.
  final SystemFontInfo? systemFont;
}

/// 구역별로 미리 보여줄 견본 글자입니다. 그 구역의 문자를 실제로 써야
/// "이 글꼴이 이 문자를 어떻게 그리는지"가 드러납니다 — 한국어 글꼴
/// 줄에 로마자 견본을 보여주면 다 똑같아 보여서 비교가 안 됩니다.
const Map<String, String> _previewSamples = <String, String>{
  '기본 글꼴': '가나 Ab',
  '한국어': '가나갈갯',
  '영어': 'Aa Bb Cc',
  '일본어': 'あいうえお',
  '중국어': '汉字预览',
  '특수문자': '★●◆',
};

/// 팝업에 항상 먼저 보여줄 이 앱의 번들 글꼴입니다. 컴퓨터마다 설치된
/// 글꼴이 달라도 이 둘은 어디서나 똑같이 보입니다(pubspec.yaml에
/// 담아뒀기 때문).
const List<_FontEntry> _bundledFontEntries = <_FontEntry>[
  _FontEntry(group: '기본 글꼴', label: '기본(Pretendard)', familyName: 'Pretendard'),
  _FontEntry(
    group: '기본 글꼴',
    label: '세리프(Gowun Batang)',
    familyName: 'Gowun Batang',
  ),
];

/// 구역이 화면에 나오는 순서입니다. 이 순서에 없는 구역은 안 나옵니다
/// (지금은 [FontScriptCategory]가 전부 여기 들어있어 그럴 일이
/// 없습니다).
const List<String> _groupOrder = <String>[
  '기본 글꼴',
  '한국어',
  '영어',
  '일본어',
  '중국어',
  '특수문자',
];

/// [anchorGlobalPosition](화면 기준 좌표) 근처에 작은 글꼴 선택 팝업을
/// 띄웁니다. 하나를 고르면 [onSelected]를 부르고 팝업을 닫습니다.
/// 팝업 바깥을 누르면 아무것도 안 고르고 그냥 닫힙니다.
void showFontPickerPopup({
  required BuildContext context,
  required Offset anchorGlobalPosition,
  required List<SystemFontInfo> systemFonts,
  required String? currentFamily,
  required ValueChanged<String> onSelected,
}) {
  final OverlayState overlay = Overlay.of(context);
  final RenderBox overlayBox = overlay.context.findRenderObject()! as RenderBox;
  final Size overlaySize = overlayBox.size;

  const double panelWidth = 220;
  const double panelMaxHeight = 320;

  // 화면 오른쪽·아래로 넘치지 않게 자리를 당겨줍니다. 왼쪽 위(0, 0)
  // 아래로는 안 내려가게 clamp의 최솟값을 0으로 둡니다.
  final double left = anchorGlobalPosition.dx.clamp(
    0.0,
    (overlaySize.width - panelWidth).clamp(0.0, double.infinity),
  );
  final double top = anchorGlobalPosition.dy.clamp(
    0.0,
    (overlaySize.height - panelMaxHeight).clamp(0.0, double.infinity),
  );

  late final OverlayEntry entry;

  void close() {
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (BuildContext overlayContext) {
      return Stack(
        children: <Widget>[
          // 팝업 바깥 아무 데나 누르면 닫히는 투명한 배경입니다.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: _FontPickerPanel(
              systemFonts: systemFonts,
              currentFamily: currentFamily,
              onSelected: (String family) {
                onSelected(family);
                close();
              },
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry);
}

/// 실제 팝업 몸통입니다. 시스템 글꼴은 처음엔 아직 안 읽혀 있어서,
/// 줄마다([_FontRow]) 화면에 나타나는 순간 파일을 읽어와 등록하고
/// 다시 그립니다.
class _FontPickerPanel extends StatelessWidget {
  const _FontPickerPanel({
    required this.systemFonts,
    required this.currentFamily,
    required this.onSelected,
  });

  final List<SystemFontInfo> systemFonts;
  final String? currentFamily;
  final ValueChanged<String> onSelected;

  /// 번들 글꼴 + 설치된 글꼴을 구역별로 나눠 한 줄 목록으로 폅니다.
  List<_FontEntry> _buildEntries() {
    final List<_FontEntry> entries = <_FontEntry>[..._bundledFontEntries];
    for (final SystemFontInfo font in systemFonts) {
      final FontScriptCategory category = categorizeFontFamily(
        font.familyName,
      );
      entries.add(
        _FontEntry(
          group: category.label,
          label: font.familyName,
          familyName: font.familyName,
          systemFont: font,
        ),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<_FontEntry> entries = _buildEntries();

    final Map<String, List<_FontEntry>> byGroup = <String, List<_FontEntry>>{};
    for (final _FontEntry entry in entries) {
      byGroup.putIfAbsent(entry.group, () => <_FontEntry>[]).add(entry);
    }

    final List<Widget> children = <Widget>[];
    for (final String group in _groupOrder) {
      final List<_FontEntry>? items = byGroup[group];
      if (items == null || items.isEmpty) {
        continue;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            group,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: palette.textDim,
            ),
          ),
        ),
      );
      for (final _FontEntry entry in items) {
        children.add(
          _FontRow(
            entry: entry,
            isSelected: entry.familyName == currentFamily,
            onTap: () => onSelected(entry.familyName),
          ),
        );
      }
    }

    // 작은 팝업이라는 요청대로, 폭 220 · 높이 최대 320으로 못 박습니다.
    // 항목이 넘치면 안에서 스크롤됩니다.
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: palette.surface,
      child: Container(
        width: 220,
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: children,
        ),
      ),
    );
  }
}

/// 글꼴 목록의 한 줄입니다. 시스템 글꼴이면 화면에 나타나는 순간
/// [ensureSystemFontLoaded]로 실제 파일을 읽어와 등록하고, 다 되면
/// 그 글꼴 그대로 다시 그립니다 — 등록되기 전까지는 앱 기본 글꼴로
/// 잠깐 보입니다.
class _FontRow extends StatefulWidget {
  const _FontRow({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final _FontEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_FontRow> createState() => _FontRowState();
}

class _FontRowState extends State<_FontRow> {
  /// 번들 글꼴은 이미 앱에 담겨 있어 처음부터 참입니다. 시스템 글꼴은
  /// 파일을 다 읽어야 참이 됩니다.
  late bool _loaded = widget.entry.systemFont == null;

  @override
  void initState() {
    super.initState();
    final SystemFontInfo? font = widget.entry.systemFont;
    if (font != null) {
      ensureSystemFontLoaded(font).then((_) {
        if (mounted) {
          setState(() => _loaded = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String? previewFamily = _loaded ? widget.entry.familyName : null;
    final String preview = _previewSamples[widget.entry.group] ?? 'Aa 가나';

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: widget.isSelected
            ? palette.accent.withValues(alpha: 0.12)
            : null,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                widget.entry.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: previewFamily,
                  fontSize: 13,
                  color: palette.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              preview,
              style: TextStyle(
                fontFamily: previewFamily,
                fontSize: 13,
                color: palette.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
