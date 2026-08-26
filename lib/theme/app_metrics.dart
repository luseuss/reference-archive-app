// 앱에서 쓰는 크기 값들을 한곳에 모아둔 파일입니다.
// 모서리 둥글기, 여백, 간격처럼 **숫자로 된 생김새**가 여기 있습니다.
//
// ── 왜 모아두나 ──
// 이 숫자들을 화면마다 흩어 적으면, 나중에 "버튼 모서리를 조금 더 둥글게"
// 같은 요청이 왔을 때 **어디를 다 고쳐야 하는지 알 수 없게** 됩니다.
// 몇 군데 고치고 몇 군데는 놓쳐서 화면마다 미묘하게 다른 상태가 됩니다.
//
// 값들은 기존 웹앱(`app.html`)의 CSS에서 그대로 가져왔습니다.
// 색은 app_palette.dart, 글자는 app_text.dart에 따로 있습니다.

/// 카드·대화상자의 모서리 둥글기입니다. (웹앱의 `--radius: 14px`)
const double appCornerRadius = 14;

/// 버튼의 모서리 둥글기입니다. (웹앱의 `button { border-radius: 9px }`)
const double buttonCornerRadius = 9;

/// 입력창과 드롭다운의 모서리 둥글기입니다.
const double inputCornerRadius = 10;

/// 태그처럼 작은 표시의 모서리 둥글기입니다.
const double tagCornerRadius = 6;

// 완전히 둥근 알약 모양(웹앱의 border-radius: 99px)에는 숫자를 쓰지 않습니다.
// Flutter에는 StadiumBorder()가 있어서 높이에 맞춰 알아서 둥글게 해줍니다.
// 큰 숫자를 넣는 웹 방식보다 정확하고, 글자 크기가 바뀌어도 따라옵니다.

/// 버튼 안쪽 여백입니다. (웹앱의 `padding: 9px 14px`)
const double buttonPaddingHorizontal = 14;
const double buttonPaddingVertical = 9;

/// 입력창 안쪽 여백입니다. (웹앱의 `padding: 10px 14px`)
const double inputPaddingHorizontal = 14;
const double inputPaddingVertical = 10;

/// 칩(알약 모양 필터 버튼) 안쪽 여백입니다.
const double chipPaddingHorizontal = 12;
const double chipPaddingVertical = 5;

/// 화면 가장자리 여백입니다. (웹앱의 `.layout { padding: 20px 24px }`)
const double screenPaddingHorizontal = 24;
const double screenPaddingVertical = 20;

/// 격자 칸 하나의 최대 너비입니다.
///
/// 기존 웹앱은 1240px 화면에서 4칸이었습니다. 이 값이면 얼추 같아집니다.
const double gridMaxCrossAxisExtent = 300;

/// 격자 칸 사이의 간격입니다. (웹앱의 `column-gap: 16px`)
const double gridSpacing = 16;
