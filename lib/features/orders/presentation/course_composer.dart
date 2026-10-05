import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';

class CourseComposer extends StatelessWidget {
  const CourseComposer({
    super.key,
    required this.controller,
    this.busy = false,
  });

  final OrderWorkspaceController controller;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final draft = controller.activeDraft!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(
                'active-course-${draft.id}-${draft.activeCourseId}',
              ),
              initialValue: draft.activeCourseId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.course),
              items: courseChoices(context, draft.courses),
              onChanged: busy || controller.saving
                  ? null
                  : controller.selectCourse,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('add-course'),
                  onPressed:
                      busy ||
                          controller.saving ||
                          draft.courses.length >= OrderCourse.maxCount
                      ? null
                      : () => _editCourse(context, controller),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.addCourse),
                ),
                TextButton.icon(
                  key: const ValueKey('manage-courses'),
                  onPressed: busy || controller.saving || draft.courses.isEmpty
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _CoursesDialog(controller: controller),
                        ),
                  icon: const Icon(Icons.view_list_rounded),
                  label: Text(l.manageCourses),
                ),
              ],
            ),
            if (draft.courses.length >= OrderCourse.maxCount)
              Text(l.courseLimit),
          ],
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> courseChoices(
  BuildContext context,
  List<OrderCourse> courses,
) => [
  DropdownMenuItem(
    value: null,
    child: Text(AppLocalizations.of(context).ungrouped),
  ),
  for (final course in courses)
    DropdownMenuItem(
      value: course.id,
      child: Text(course.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
];

Future<void> _editCourse(
  BuildContext context,
  OrderWorkspaceController controller, [
  OrderCourse? course,
]) => showDialog<void>(
  context: context,
  builder: (_) => _CourseEditDialog(controller: controller, course: course),
);

class _CourseEditDialog extends StatefulWidget {
  const _CourseEditDialog({required this.controller, this.course});
  final OrderWorkspaceController controller;
  final OrderCourse? course;

  @override
  State<_CourseEditDialog> createState() => _CourseEditDialogState();
}

class _CourseEditDialogState extends State<_CourseEditDialog> {
  late final _input = TextEditingController(text: widget.course?.name ?? '');
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.course == null ? l.addCourse : l.editCourse),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: TextFormField(
            key: const ValueKey('course-name-input'),
            controller: _input,
            autofocus: true,
            maxLength: OrderCourse.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.courseName,
              hintText: l.courseNameHint,
            ),
            validator: (value) {
              final name = (value ?? '').trim();
              final courses = widget.controller.activeDraft!.courses;
              if (widget.course == null &&
                  courses.length >= OrderCourse.maxCount) {
                return l.courseLimit;
              }
              if (name.isEmpty ||
                  name.length > OrderCourse.maxNameLength ||
                  RegExp(r'[\x00-\x1f\x7f]').hasMatch(name) ||
                  courses.any(
                    (course) =>
                        course.id != widget.course?.id &&
                        course.name.toLowerCase() == name.toLowerCase(),
                  )) {
                return l.courseNameInvalid;
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('save-course'),
          onPressed: () {
            if (_form.currentState!.validate() &&
                widget.controller.saveCourse(
                  _input.text,
                  id: widget.course?.id,
                )) {
              Navigator.pop(context);
            }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _CoursesDialog extends StatelessWidget {
  const _CoursesDialog({required this.controller});
  final OrderWorkspaceController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final courses = controller.activeDraft?.courses ?? const <OrderCourse>[];
      return AlertDialog(
        title: Text(l.manageCourses),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < courses.length; index++) ...[
                  Text(
                    courses[index].name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    children: [
                      IconButton(
                        key: ValueKey('course-up-${courses[index].id}'),
                        onPressed: controller.editingOrder != null || index == 0
                            ? null
                            : () =>
                                  controller.moveCourse(courses[index].id, -1),
                        tooltip: l.courseMoveUp,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                      IconButton(
                        key: ValueKey('course-down-${courses[index].id}'),
                        onPressed:
                            controller.editingOrder != null ||
                                index == courses.length - 1
                            ? null
                            : () => controller.moveCourse(courses[index].id, 1),
                        tooltip: l.courseMoveDown,
                        icon: const Icon(Icons.arrow_downward_rounded),
                      ),
                      IconButton(
                        onPressed:
                            controller.editingOrder?.courses.any(
                                  (course) => course.id == courses[index].id,
                                ) ==
                                true
                            ? null
                            : () => _editCourse(
                                context,
                                controller,
                                courses[index],
                              ),
                        tooltip: l.editCourse,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        key: ValueKey('remove-course-${courses[index].id}'),
                        onPressed:
                            controller.editingOrder?.courses.any(
                                  (course) => course.id == courses[index].id,
                                ) ==
                                true
                            ? null
                            : () => _remove(context, courses[index]),
                        tooltip: l.removeCourse,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      );
    },
  );

  Future<void> _remove(BuildContext context, OrderCourse course) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(course.name),
        content: Text(l.removeCourseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove-course'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.removeCourse),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.removeCourse(course.id);
  }
}

class CourseHeading extends StatelessWidget {
  const CourseHeading({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
