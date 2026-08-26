// 검색 입력창입니다.
//
// 원래 필터 줄 안에 있었는데, 의뢰인이 정해준 화면 구조에서 **검색은 위쪽(④)**,
// **폴더·카테고리 고르기는 그 아래(⑤)** 로 자리가 갈렸습니다. 그래서 따로 뺐습니다.
//
// 이 위젯은 검색을 직접 하지 않습니다. 글자가 바뀌면 알려주기만 하고,
// 실제로 목록을 다시 불러오는 일은 화면(home_screen.dart)이 합니다.

import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';

/// 제목·메모에서 찾는 검색창입니다.
class ReferenceSearchField extends StatelessWidget {
  const ReferenceSearchField({
    super.key,
    required this.controller,
    required this.hasText,
    required this.onClear,
  });

  /// 입력창의 글자를 다루는 도구입니다.
  ///
  /// 이 위젯이 직접 만들지 않고 화면에서 받아옵니다.
  /// 목록을 다시 그릴 때마다 새로 만들면 입력하던 글자가 사라지기 때문입니다.
  final TextEditingController controller;

  /// 지금 검색어가 들어있는지 여부입니다. 지우기 버튼을 보일지 정합니다.
  final bool hasText;

  /// 지우기 버튼을 눌렀을 때 실행할 동작입니다.
  final VoidCallback onClear;

  /// 검색창의 생김새를 만들어 돌려줍니다.
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: '제목이나 메모에서 찾기',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,

        // 기존 웹앱의 검색창은 완전히 둥근 모양입니다.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputCornerRadius),
        ),

        // 글자를 입력했을 때만 지우기 버튼을 보여줍니다.
        // 항상 있으면 누를 것이 없는데도 자리를 차지합니다.
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: '검색어 지우기',
                onPressed: onClear,
              )
            : null,
      ),
    );
  }
}
