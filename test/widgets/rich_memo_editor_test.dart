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

  testWidgets(
    '다시 만들어지면 그 시점의 initialMemo로 새로 채워진다',
    (WidgetTester tester) async {
      // RichMemoEditorState는 initState에서 딱 한 번만 initialMemo를 읽어
      // 문서를 채웁니다(위 pumpEditor의 안내대로, 편집기 자체는 "언제
      // 저장할지"를 모릅니다). 이 테스트는 그 지점을 직접 확인합니다 —
      // 첫 번째로 만들어진 편집기를 완전히 없앤 뒤, 다른 initialMemo로
      // 새로 만들면 새 값이 나와야 합니다(첫 번째 값이 남아있으면 안 됨).
      //
      // reference_detail_screen.dart가 initialMemo로 widget.item.memo(원본)가
      // 아니라 _memoJson(최신 값)을 넘겨야 하는 이유가 바로 이 동작 때문입니다
      // — 편집기는 "다시 만들어질 때 무엇을 받는지"밖에 모르므로, 최신 값을
      // 넘기는 책임은 전적으로 이 위젯을 담는 화면 쪽에 있습니다.
      final String deltaA = memoFromDocument(
        Document.fromDelta(Delta()..insert('첫 번째 메모\n')),
      );
      final String deltaB = memoFromDocument(
        Document.fromDelta(Delta()..insert('두 번째 메모\n')),
      );

      await pumpEditor(tester, initialMemo: deltaA, onChanged: (_) {});
      expect(controllerOf(tester).document.toPlainText().trim(), '첫 번째 메모');

      // 완전히 다른 위젯 트리로 바꿔서 이전 RichMemoEditorState를 확실히
      // 없앱니다(dispose). ListView 밖으로 스크롤돼 없어지는 상황을
      // 그대로 재현하기보다, "없어졌다가 다시 만들어지는" 결과 자체를
      // 직접 만들어내는 쪽이 훨씬 더 안정적으로 확인할 수 있습니다.
      await tester.pumpWidget(const SizedBox.shrink());

      await pumpEditor(tester, initialMemo: deltaB, onChanged: (_) {});
      expect(controllerOf(tester).document.toPlainText().trim(), '두 번째 메모');
    },
  );

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
