// 이 컴퓨터에 설치된 글꼴 목록을 찾아오고, 고른 글꼴을 실제로 쓸 수
// 있게 등록하는 도구입니다. 무드보드 텍스트 카드의 "글꼴 바꾸기"에 씁니다.
//
// ── 왜 "이름만 안다"고 끝나지 않는가 ──
// Flutter는 앱에 미리 담아둔 글꼴(이 앱의 경우 Pretendard, Gowun Batang)
// 말고는 기본적으로 아무 글꼴도 모릅니다. 컴퓨터에 어떤 글꼴이 설치돼
// 있는지 알아내는 것과, 그 글꼴을 실제로 화면에 쓸 수 있게 만드는 것은
// **서로 다른 두 단계**입니다.
//
//   1. 목록 찾기 — 이 파일 안에서 레지스트리를 직접 읽습니다.
//   2. 실제로 쓰기 — 사용자가 하나를 고르면, 그 글꼴 파일을 디스크에서
//      읽어 `dart:ui`의 FontLoader로 등록합니다. 등록해야 비로소
//      `TextStyle(fontFamily: ...)`에 그 이름을 쓸 수 있습니다.
//
// ── 왜 Windows만 되나 ──
// "설치된 글꼴 목록"을 알아내는 방법이 운영체제마다 완전히 다릅니다
// (Windows는 레지스트리, macOS는 CoreText, Linux는 fontconfig). 이
// 프로젝트는 지금 Windows에서만 개발·확인되고 있어서(CLAUDE.md의
// "새 컴퓨터에서 처음 시작할 때" 참고), 이번엔 Windows만 만들었습니다.
// 다른 운영체제에서는 [loadInstalledFontFamilies]가 빈 목록을
// 돌려줘서, 화면에는 앱에 담아둔 글꼴만 보입니다 — 오류가 나지 않고
// 조용히 줄어들 뿐입니다.
//
// ── 레지스트리로 알아내는 이유 (GDI 대신) ──
// 설치된 글꼴 "이름"만 구하려면 Windows GDI의 EnumFontFamiliesEx로도
// 되지만, 그러면 **파일 경로**를 또 따로 찾아야 합니다. 반면
// `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`
// 레지스트리 키는 "표시 이름 → 파일 이름"을 통째로 담고 있어서, 한 번
// 읽는 것으로 목록과 경로를 동시에 구할 수 있습니다.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:win32_registry/win32_registry.dart';

/// 설치된 글꼴 하나입니다.
class SystemFontInfo {
  const SystemFontInfo({required this.familyName, required this.filePath});

  /// 화면에 보여줄 이름이자, 등록한 뒤 `TextStyle(fontFamily: ...)`에 쓸 이름입니다.
  final String familyName;

  /// 글꼴 파일의 전체 경로입니다.
  final String filePath;
}

const String _fontsRegistryPath =
    r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';

/// 이 컴퓨터에 설치된 글꼴 목록을 찾아옵니다. Windows가 아니면 빈
/// 목록입니다.
///
/// ── 이름을 다듬는 이유 ──
/// 레지스트리의 표시 이름은 "맑은 고딕 (TrueType)"처럼 글꼴 종류가
/// 괄호로 붙어 있습니다. 사용자에게는 "맑은 고딕"만 보여주면 되고,
/// 실제 글꼴 등록에도 괄호 없는 이름을 씁니다.
///
/// ── .fon 파일을 거르는 이유 ──
/// .fon은 옛날 비트맵 글꼴 형식이라 FontLoader로 못 읽습니다. 실제로
/// 쓸 수 있는 .ttf·.ttc·.otf만 남깁니다.
List<SystemFontInfo> loadInstalledFontFamilies() {
  if (!Platform.isWindows) {
    return const <SystemFontInfo>[];
  }

  try {
    final RegistryKey key = Registry.openPath(
      RegistryHive.localMachine,
      path: _fontsRegistryPath,
    );

    final String fontsDir = '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\Fonts';
    final List<SystemFontInfo> fonts = <SystemFontInfo>[];

    for (final RegistryValue value in key.values) {
      if (value is! StringValue) {
        continue;
      }

      final String fileName = value.value;
      final String lower = fileName.toLowerCase();
      if (!lower.endsWith('.ttf') &&
          !lower.endsWith('.ttc') &&
          !lower.endsWith('.otf')) {
        continue;
      }

      // 값이 파일 이름만 있으면(대부분의 경우) C:\Windows\Fonts 안에
      // 있는 것이고, 이미 전체 경로면(일부 사용자 설치 글꼴) 그대로 씁니다.
      final String filePath = fileName.contains(r'\')
          ? fileName
          : '$fontsDir\\$fileName';

      // "이름 (TrueType)"처럼 괄호로 붙은 종류 표시를 뗍니다.
      final String displayName = value.name
          .replaceAll(RegExp(r'\s*\((TrueType|OpenType)\)\s*$'), '')
          .trim();

      if (displayName.isEmpty) {
        continue;
      }

      fonts.add(SystemFontInfo(familyName: displayName, filePath: filePath));
    }

    key.close();

    fonts.sort(
      (SystemFontInfo a, SystemFontInfo b) =>
          a.familyName.compareTo(b.familyName),
    );
    return fonts;
  } catch (error) {
    // 레지스트리를 못 읽어도 앱은 켜져야 합니다. 글꼴 목록이 하나
    // 부족한 것뿐이니, 여기서 죽이면 안 됩니다.
    debugPrint('[글꼴] 설치된 글꼴 목록을 못 읽었습니다: $error');
    return const <SystemFontInfo>[];
  }
}

/// 글꼴을 고르는 화면에서 나눠 보여줄 다섯 구역입니다.
///
/// 폰트 파일 자체가 "어떤 문자를 지원하는지"를 정확히 알아내려면 글꼴
/// 안의 문자표(cmap)까지 읽어야 해서 훨씬 복잡해집니다. 대신 이 앱은
/// **글꼴 이름에 어떤 문자가 쓰였는지**로 대충 가릅니다 — Windows에
/// 설치되는 한국어 글꼴은 실제로 "케리스 케듀체", "나눔고딕"처럼
/// 이름 자체가 한글인 경우가 흔해서, 이 정도 어림짐작으로도 사용자가
/// 찾는 데 충분합니다. (Pretendard처럼 로마자 이름을 쓰는 한국어
/// 글꼴은 "영어" 구역에 들어가는 것이 이 방식의 알려진 한계입니다.)
enum FontScriptCategory {
  korean('한국어'),
  english('영어'),
  japanese('일본어'),
  chinese('중국어'),
  symbol('특수문자');

  const FontScriptCategory(this.label);

  /// 화면에 보여줄 구역 이름입니다.
  final String label;
}

/// 특수문자·기호 전용으로 흔히 쓰이는 글꼴 이름 조각입니다. 어느
/// 언어권에도 안 속하는 별도 구역으로 뺍니다.
const List<String> _symbolFontNameHints = <String>[
  'wingdings',
  'webdings',
  'symbol',
  'marlett',
  'dingbats',
  'mt extra',
  'segoe mdl2',
  'segoe fluent icons',
  'holomdl2',
];

final RegExp _hangulPattern = RegExp(r'[가-힣ᄀ-ᇿ㄰-㆏]');
final RegExp _kanaPattern = RegExp(r'[぀-ゟ゠-ヿ]');
final RegExp _cjkIdeographPattern = RegExp(r'[一-鿿]');

/// 글꼴 이름을 보고 다섯 구역([FontScriptCategory]) 중 하나로 가릅니다.
///
/// 순서가 중요합니다 — 특수문자 이름표부터 확인해서 "Segoe MDL2
/// Assets"처럼 로마자로만 된 아이콘 글꼴이 엉뚱하게 "영어" 구역으로
/// 새지 않게 하고, 그다음 한글 → 가나(히라가나·가타카나) → 한자
/// 순서로 봐서 일본어 글꼴 이름에 한자가 섞여 있어도(예: "游明朝")
/// 가나가 있으면 일본어로 먼저 잡히게 합니다.
FontScriptCategory categorizeFontFamily(String familyName) {
  final String lower = familyName.toLowerCase();
  for (final String hint in _symbolFontNameHints) {
    if (lower.contains(hint)) {
      return FontScriptCategory.symbol;
    }
  }

  if (_hangulPattern.hasMatch(familyName)) {
    return FontScriptCategory.korean;
  }
  if (_kanaPattern.hasMatch(familyName)) {
    return FontScriptCategory.japanese;
  }
  if (_cjkIdeographPattern.hasMatch(familyName)) {
    return FontScriptCategory.chinese;
  }
  return FontScriptCategory.english;
}

/// 이미 등록해서 다시 등록할 필요가 없는 글꼴 이름들입니다.
///
/// FontLoader.load()를 같은 이름으로 두 번 부르면 오류가 나지는
/// 않지만 쓸데없이 파일을 또 읽습니다. 한 번 등록한 이름은 기억해둡니다.
final Set<String> _loadedFontFamilies = <String>{};

/// [font]를 실제로 읽어서 Flutter에 등록합니다. 이미 등록했으면
/// 아무 일도 안 합니다.
///
/// 등록이 끝나야 `TextStyle(fontFamily: font.familyName)`이 그 모양대로
/// 보입니다. 파일을 못 읽으면(글꼴이 지워졌거나 권한 문제) 조용히
/// 넘어갑니다 — 이 컴퓨터에 그 글꼴이 없으면 앱 기본 글꼴로 보이는
/// 것으로 충분합니다.
Future<void> ensureSystemFontLoaded(SystemFontInfo font) async {
  if (_loadedFontFamilies.contains(font.familyName)) {
    return;
  }

  try {
    final Uint8List bytes = await File(font.filePath).readAsBytes();
    final FontLoader loader = FontLoader(font.familyName);
    loader.addFont(
      Future<ByteData>.value(ByteData.view(bytes.buffer)),
    );
    await loader.load();
    _loadedFontFamilies.add(font.familyName);
  } catch (error) {
    debugPrint('[글꼴] "${font.familyName}" 글꼴을 못 읽었습니다: $error');
  }
}
