// 날짜를 화면에 보여줄 글자로 바꾸는 파일입니다.
//
// ── 왜 따로 있는가 ──
// 이 앱은 시각을 **언제나 UTC로 저장**합니다. 나중에 여러 기기에서 쓸 때
// "어느 쪽이 최신인가"를 판단하려면 기준이 하나여야 하기 때문입니다.
// (CLAUDE.md 설계 원칙 2)
//
// 대신 **보여줄 때는 반드시 현지 시각으로 바꿔야** 합니다. 안 바꾸면
// 한국에서는 9시간 어긋난 날짜가 보이고, 밤에 넣은 것은 하루 전으로 보입니다.
// 그 변환을 빠뜨리기 쉬워서 여기 한 곳에 모아뒀습니다.

/// 카드에 보여줄 날짜 글자를 만듭니다. (예: `2026. 08. 27.`)
///
/// 기존 웹앱이 쓰던 한국식 표기와 같은 모양입니다.
/// [utcTime]은 저장된 그대로(UTC) 넘기면 됩니다. 현지 시각 변환은 여기서 합니다.
String formatCardDate(DateTime utcTime) {
  final DateTime local = utcTime.toLocal();

  // padLeft(2, '0') = 한 자리 수 앞에 0을 붙입니다. (8월 → 08)
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');

  return '${local.year}. $month. $day.';
}
