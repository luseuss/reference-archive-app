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

// ── 무드보드(4단계) ──

/// 무드보드 판의 가로 크기입니다.
///
/// ── 왜 크기를 정해두나 (끝없는 판이 더 자유롭지 않나) ──
/// 끝이 없는 판은 스크롤에도 끝이 없습니다. 카드를 한참 오른쪽으로 옮겨두면
/// **다시 찾아갈 방법이 없습니다.** 크기가 정해져 있으면 판 전체를 화면에
/// 통째로 맞춰 보여줄 수 있어서, 올려둔 카드는 반드시 어딘가 보입니다.
///
/// ── 왜 이 숫자인가 ──
/// 판은 **화면 크기에 맞춰 줄여서** 보여줍니다(widgets/board_canvas.dart).
/// 그래서 판이 너무 크면 카드가 깨알같이 작아집니다. 1920×1200은 넉넉한
/// 모니터 한 화면쯤이라, 30장 남짓을 늘어놓아도 알아볼 만한 크기로 남습니다.
/// 2단계에서 줌을 붙이면 그때는 크게 확대해서 볼 수 있게 됩니다.
const double boardWidth = 1920;

/// 무드보드 판의 세로 크기입니다.
const double boardHeight = 1200;

/// 판에 새로 올린 카드들을 늘어놓을 때 쓰는 간격입니다.
const double boardPlacementSpacing = 20;

/// 판에 새로 올린 카드가 시작하는 자리입니다. 판의 왼쪽 위 모서리에서 띄웁니다.
const double boardPlacementMargin = 40;

/// 판을 확대할 수 있는 최대 배율입니다.
///
/// 더 키울 수도 있지만, 원본보다 3배 넘게 늘리면 그림이 뭉개져서
/// 확대한 보람이 없습니다.
const double maxBoardScale = 3.0;

/// 확대·축소 버튼을 한 번 누를 때 바뀌는 비율입니다.
///
/// 1.25 = 한 번에 25%씩. 2배씩 뛰면 원하는 크기를 지나쳐서 왔다 갔다 하게 되고,
/// 1.1처럼 잘면 여러 번 눌러야 합니다.
const double boardZoomStep = 1.25;
