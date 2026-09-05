// 레퍼런스 편집 화면의 분류 항목(파트·폴더·카테고리·태그·프로젝트)
// 고르는 칸들을 나란히 늘어놓는 곳입니다.
//
// reference_detail_screen.dart에서 뺐습니다(CLAUDE.md "밀린 정리거리"
// 참고). 다섯 칸이 전부 reference_taxonomy_edit_controller.dart의
// ReferenceTaxonomyEditController를 그대로 받아쓰는 반복된 모양이라,
// 그 반복 자체를 한 위젯으로 묶었습니다.

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/taxonomy_item.dart';
import '../repositories/taxonomy_repository.dart';
import '../screens/reference_taxonomy_edit_controller.dart';
import 'taxonomy_multi_field.dart';
import 'taxonomy_single_field.dart';

/// 파트·폴더·카테고리·태그·프로젝트를 고르는 칸 다섯 개를 세로로
/// 늘어놓습니다.
class ReferenceDetailTaxonomyFields extends StatelessWidget {
  const ReferenceDetailTaxonomyFields({
    super.key,
    required this.controller,
    required this.repository,
  });

  /// "지금 무엇을 골랐는지"와 목록을 담고 있는 컨트롤러입니다.
  final ReferenceTaxonomyEditController controller;

  /// 새 분류 항목을 만들 때 쓰는 통로입니다.
  final TaxonomyRepository repository;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 파트를 맨 위에 둡니다. 폴더·카테고리보다 큰 갈래라서
        // 위에서 아래로 좁혀지는 순서가 자연스럽습니다.
        TaxonomySingleField(
          kind: TaxonomyKind.part,
          options: controller.options[TaxonomyKind.part] ?? <TaxonomyItem>[],
          selectedId: controller.partId,
          repository: repository,
          onChanged: controller.setPart,
          onCreated: (TaxonomyItem created) =>
              controller.handleCreated(repository, TaxonomyKind.part, created),
        ),
        const SizedBox(height: 16),

        TaxonomySingleField(
          kind: TaxonomyKind.folder,
          options: controller.options[TaxonomyKind.folder] ?? <TaxonomyItem>[],
          selectedId: controller.folderId,
          repository: repository,
          onChanged: controller.setFolder,
          onCreated: (TaxonomyItem created) => controller.handleCreated(
            repository,
            TaxonomyKind.folder,
            created,
          ),
        ),
        const SizedBox(height: 16),

        TaxonomySingleField(
          kind: TaxonomyKind.category,
          options:
              controller.options[TaxonomyKind.category] ?? <TaxonomyItem>[],
          selectedId: controller.categoryId,
          repository: repository,
          onChanged: controller.setCategory,
          onCreated: (TaxonomyItem created) => controller.handleCreated(
            repository,
            TaxonomyKind.category,
            created,
          ),
        ),
        const SizedBox(height: 24),

        TaxonomyMultiField(
          kind: TaxonomyKind.tag,
          options: controller.options[TaxonomyKind.tag] ?? <TaxonomyItem>[],
          selectedIds: controller.tagIds,
          repository: repository,
          onChanged: controller.setTags,
          onCreated: (TaxonomyItem created) =>
              controller.handleCreated(repository, TaxonomyKind.tag, created),
        ),
        const SizedBox(height: 24),

        TaxonomyMultiField(
          kind: TaxonomyKind.project,
          options:
              controller.options[TaxonomyKind.project] ?? <TaxonomyItem>[],
          selectedIds: controller.projectIds,
          repository: repository,
          onChanged: controller.setProjects,
          onCreated: (TaxonomyItem created) => controller.handleCreated(
            repository,
            TaxonomyKind.project,
            created,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
