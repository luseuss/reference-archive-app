// 한글 조사(을/를, 이/가, 은/는)를 앞 글자에 맞게 골라주는 도구입니다.
//
// ── 왜 필요한가 ──
// "폴더를 지웁니다"는 맞지만 "프로젝트을 지웁니다"는 틀립니다.
// 앞 글자에 받침이 있느냐 없느냐에 따라 조사가 달라지기 때문입니다.
//
//   받침 있음: 을 / 이 / 은   (예: 앨범을, 앨범이, 앨범은)
//   받침 없음: 를 / 가 / 는   (예: 폴더를, 폴더가, 폴더는)
//
// 문구를 "폴더을(를) 지웁니다"처럼 쓰면 읽기 불편하고, 그렇다고 종류마다
// 문구를 따로 적으면 종류가 늘 때마다 빠뜨리게 됩니다. 그래서 자동으로 고릅니다.

/// 한글 글자에 받침이 있는지 확인합니다.
///
/// 한글 글자는 유니코드에서 '가'(0xAC00)부터 '힣'(0xD7A3)까지 규칙적으로 늘어서
/// 있습니다. 한 글자마다 받침 28가지가 순서대로 들어있어서, 28로 나눈 나머지가
/// 0이면 받침이 없는 글자입니다.
///
/// 한글이 아닌 글자(영어·숫자 등)는 받침이 없는 것으로 봅니다.
/// 완벽하지는 않지만("1을"이 맞는 경우도 있음) 분류 이름은 거의 한글이라
/// 이 정도면 충분합니다.
bool _hasFinalConsonant(String word) {
  if (word.isEmpty) {
    return false;
  }

  final int code = word.codeUnitAt(word.length - 1);

  // 한글 글자 범위 밖이면 받침 없음으로 취급합니다.
  if (code < 0xAC00 || code > 0xD7A3) {
    return false;
  }

  return (code - 0xAC00) % 28 != 0;
}

/// 목적격 조사를 붙여 돌려줍니다. ("폴더" → "폴더를", "앨범" → "앨범을")
String withObjectParticle(String word) {
  return _hasFinalConsonant(word) ? '$word을' : '$word를';
}

/// 주격 조사를 붙여 돌려줍니다. ("폴더" → "폴더가", "앨범" → "앨범이")
String withSubjectParticle(String word) {
  return _hasFinalConsonant(word) ? '$word이' : '$word가';
}

/// 보조사를 붙여 돌려줍니다. ("폴더" → "폴더는", "앨범" → "앨범은")
String withTopicParticle(String word) {
  return _hasFinalConsonant(word) ? '$word은' : '$word는';
}
