import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
          if (draft.courses.isNotEmpty) ...[
            PhaseSelector(
              key: const ValueKey('addition-phase-selector'),
              courses: draft.courses,
              courseId: draft.activeCourseId,
              label: l.addItemsToPhase,
              onChanged: busy || controller.saving
                  ? null
                  : controller.selectCourse,
            ),
            const SizedBox(height: 12),
          ],
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

/// The number is only a destination label. Dividers remain unnamed on tickets.
class PhaseSelector extends StatelessWidget {
  const PhaseSelector({
    super.key,
    required this.courses,
    required this.courseId,
    required this.label,
    this.onChanged,
  });
  final List<OrderCourse> courses;
  final String? courseId;
  final String label;
  final void Function(String?)? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final ids = <String?>[null, ...courses.map((course) => course.id)];
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: InputDecoration(enabled: onChanged != null),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: ValueKey('phase-selection-$courseId'),
                value: ids.indexOf(courseId).toString(),
                isExpanded: true,
                isDense: true,
                itemHeight: null,
                items: [
                  for (var i = 0; i < ids.length; i++)
                    DropdownMenuItem(
                      value: '$i',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            i > 0 && !courses[i - 1].isDivider
                                ? courses[i - 1].name
                                : courses.any((course) => course.isDivider)
                                ? l.orderPhase(numbers.format(i + 1))
                                : l.ungrouped,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                ],
                onChanged: onChanged == null
                    ? null
                    : (value) {
                        if (value != null) onChanged!(ids[int.parse(value)]);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
