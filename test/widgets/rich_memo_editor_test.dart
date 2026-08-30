// RichMemoEditor(리치텍스트 메모 편집기)가 값을 제대로 보여주고,
// 바뀐 내용을 알려주는지 확인하는 테스트입니다.
//
// ── 이 테스트가 확인하지 못하는 것 ──
// 서식 버튼(굵게, 색 고르기 등)을 실제로 눌러서 서식이 먹는지는 여기서
// 확인하지 않습니다. flutter_quill 내부의 그림(버튼 배치, 색상 선택기 등)을
// 다시 그려보는 셈이라 위젯 테스트로 잡기보다 앱을 켜서 눈으로 보는 편이
// 낫습니다. 대신 "값을 넣으면 보이는지"와 "내용이 바뀌면 알려주는지"는
// 확실히 잡아둡니다.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/utils/rich_text_memo.dart';
import 'package:reference_archive_app/widgets/rich_memo_editor.dart';

void main() {
  /// 화면에 지금 떠 있는 QuillEditor의 컨트롤러를 찾아줍니다.
  ///
  /// 편집기 안의 실제 내용을 확인하려면 화면에 그려진 글자를 찾기보다
  /// 컨트롤러가 들고 있는 문서를 직접 보는 편이 안정적입니다.
  QuillController controllerOf(WidgetTester tester) {
    return tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? initialMemo,
    required ValueChanged<String> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[
          Locale('en'),
        ],
        home: Scaffold(
          body: RichMemoEditor(
            initialMemo: initialMemo,
            onChanged: onChanged,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('초기 메모가 편집기에 그대로 채워진다', (WidgetTester tester) async {
    final String delta = memoFromDocument(
      Document.fromDelta(Delta()..insert('안녕하세요\n')),
    );

    await pumpEditor(tester, initialMemo: delta, onChanged: (_) {});

    expect(controllerOf(tester).document.toPlainText().trim(), '안녕하세요');
  });

  testWidgets('초기 메모가 없으면 빈 문서로 시작한다', (WidgetTester tester) async {
    await pumpEditor(tester, initialMemo: null, onChanged: (_) {});

    expect(controllerOf(tester).document.toPlainText().trim(), '');
  });

  testWidgets('내용을 바꾸면 onChanged로 새 값이 전달된다', (WidgetTester tester) async {
    String? latest;

    await pumpEditor(
      tester,
      initialMemo: null,
      onChanged: (String value) => latest = value,
    );

    controllerOf(
      tester,
    ).replaceText(0, 0, '새 메모', const TextSelection.collapsed(offset: 4));
    await tester.pump();

    expect(latest, isNotNull);
    expect(plainTextFromMemo(latest), '새 메모');
  });
}
