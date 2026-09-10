// pick_taxonomy_dialog.dart의 들여쓰기(depthById) 옵션을 확인하는 테스트입니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_archive_app/models/enums.dart';
import 'package:reference_archive_app/models/taxonomy_item.dart';
import 'package:reference_archive_app/widgets/pick_taxonomy_dialog.dart';

void main() {
  TaxonomyItem folder(String id, String name) {
    final DateTime now = DateTime.utc(2026, 1, 1);
    return TaxonomyItem(
      id: id,
      kind: TaxonomyKind.folder,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('depthById 없이도 그대로 고를 수 있다(기존 동작 유지)', (WidgetTester tester) async {
    late Future<PickedTaxonomy?> result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return ElevatedButton(
            onPressed: () {
              result = showPickTaxonomyDialog(
                context: context,
                kind: TaxonomyKind.folder,
                items: <TaxonomyItem>[folder('a', '인물')],
                title: '폴더 고르기',
              );
            },
            child: const Text('열기'),
          );
        },
      ),
    ));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('인물'));
    await tester.pumpAndSettle();

    final PickedTaxonomy? picked = await result;
    expect(picked?.item?.id, 'a');
  });

  testWidgets('depthById를 넘기면 들여써서 보이지만 그대로 고를 수 있다', (WidgetTester tester) async {
    late Future<PickedTaxonomy?> result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return ElevatedButton(
            onPressed: () {
              result = showPickTaxonomyDialog(
                context: context,
                kind: TaxonomyKind.folder,
                items: <TaxonomyItem>[folder('a', '인물'), folder('b', '얼굴')],
                depthById: const <String, int>{'b': 1},
                title: '폴더 고르기',
              );
            },
            child: const Text('열기'),
          );
        },
      ),
    ));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('얼굴'));
    await tester.pumpAndSettle();

    final PickedTaxonomy? picked = await result;
    expect(picked?.item?.id, 'b');
  });
}
