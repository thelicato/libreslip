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
    final last = draft.courses.lastOrNull;
    final removable =
        last?.isDivider == true &&
        !(controller.editingOrder?.courses.any(
              (course) => course.id == last!.id,
            ) ??
            false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('add-divider'),
                onPressed: busy || !controller.canAddDivider
                    ? null
                    : controller.addDivider,
                icon: const Icon(Icons.horizontal_rule_rounded),
                label: Text(l.addDivider),
              ),
              if (removable)
                TextButton.icon(
                  key: const ValueKey('remove-divider'),
                  onPressed: busy || controller.saving
                      ? null
                      : () => controller.removeDivider(last!.id),
                  icon: const Icon(Icons.undo_rounded),
                  label: Text(l.removeDivider),
                ),
            ],
          ),
          if (draft.courses.length >= OrderCourse.maxCount) Text(l.courseLimit),
        ],
      ),
    );
  }
}

/// One visual language for composition, history and both preparation boards.
class CourseHeading extends StatelessWidget {
  const CourseHeading({super.key, required this.course, required this.courses});
  final OrderCourse? course;
  final List<OrderCourse> courses;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (course == null && courses.any((course) => course.isDivider)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final divider = course?.isDivider == true;
    return Semantics(
      label: divider ? l.orderDivider : null,
      header: true,
      child: Padding(
        key: divider ? ValueKey('order-divider-${course!.id}') : null,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1.5,
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            if (divider)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    course?.name ?? l.ungrouped,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            Expanded(
              child: Container(
                height: 1.5,
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
