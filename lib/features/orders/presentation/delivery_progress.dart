import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/course_groups.dart';
import 'course_composer.dart';

class DeliveryProgressLine {
  const DeliveryProgressLine({
    required this.id,
    required this.name,
    required this.quantity,
    required this.delivered,
    this.note = '',
    this.courseId,
    this.isAddition = false,
  });
  final String id;
  final String name;
  final int quantity;
  final int delivered;
  final String note;
  final String? courseId;
  final bool isAddition;
}

/// Keeps delivery controls and course separation consistent on both devices.
class DeliveryProgress extends StatelessWidget {
  const DeliveryProgress({
    super.key,
    required this.lines,
    required this.courses,
    this.onChanged,
    this.busy = false,
    this.showHelp = true,
    this.completeWholeSteps = false,
    this.onStepChanged,
  });
  final List<DeliveryProgressLine> lines;
  final List<OrderCourse> courses;
  final void Function(String lineId, int quantity, int expectedQuantity)?
  onChanged;
  final bool busy;
  final bool showHelp;
  final bool completeWholeSteps;
  final void Function(String? courseId, bool delivered)? onStepChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHelp) ...[
          Text(l.deliveryProgress, style: theme.textTheme.titleMedium),
          Text(l.deliveryProgressLocal),
          const SizedBox(height: 12),
        ],
        for (final section in courseSections(
          courses,
          lines,
          (line) => line.courseId,
        )) ...[
          if (courses.isNotEmpty)
            CourseHeading(course: section.course, courses: courses),
          if (completeWholeSteps)
            _StepProgress(
              section: section,
              numbers: numbers,
              busy: busy,
              onChanged: onStepChanged,
            )
          else
            for (final completed in [false, true])
              if (section.lines.any(
                (line) => (line.delivered == line.quantity) == completed,
              )) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    completed ? l.deliveredItems : l.outstandingItems,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: completed
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final line in section.lines.where(
                  (line) => (line.delivered == line.quantity) == completed,
                ))
                  Padding(
                    key: ValueKey('delivery-line-${line.id}'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: completed
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${numbers.format(line.quantity)} × ${line.name}',
                              style: theme.textTheme.titleMedium,
                            ),
                            if (line.note.isNotEmpty) Text(line.note),
                            if (line.isAddition)
                              Text(
                                l.latestAdditions,
                                style: theme.textTheme.labelMedium,
                              ),
                            Text(
                              l.deliveryQuantity(
                                numbers.format(line.delivered),
                                numbers.format(line.quantity - line.delivered),
                              ),
                            ),
                            if (onChanged != null)
                              Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  IconButton(
                                    key: ValueKey('undo-delivery-${line.id}'),
                                    tooltip: l.undoOneDelivery(line.name),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: busy || line.delivered == 0
                                        ? null
                                        : () => onChanged!(
                                            line.id,
                                            line.delivered - 1,
                                            line.delivered,
                                          ),
                                    icon: const Icon(Icons.remove_rounded),
                                  ),
                                  IconButton(
                                    key: ValueKey('deliver-one-${line.id}'),
                                    tooltip: l.deliverOne(line.name),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: busy || completed
                                        ? null
                                        : () => onChanged!(
                                            line.id,
                                            line.delivered + 1,
                                            line.delivered,
                                          ),
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                    ),
                                    key: ValueKey('deliver-all-${line.id}'),
                                    onPressed: busy
                                        ? null
                                        : () => onChanged!(
                                            line.id,
                                            completed ? 0 : line.quantity,
                                            line.delivered,
                                          ),
                                    child: Text(
                                      completed
                                          ? l.undoLineDelivery
                                          : l.deliverWholeLine,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
        ],
      ],
    );
  }
}

/// A compact list with one action that completes the entire section.
class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.section,
    required this.numbers,
    required this.busy,
    this.onChanged,
  });
  final CourseSection<DeliveryProgressLine> section;
  final NumberFormat numbers;
  final bool busy;
  final void Function(String? courseId, bool delivered)? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final delivered = section.lines.fold(
      0,
      (sum, line) => sum + line.delivered,
    );
    final quantity = section.lines.fold(0, (sum, line) => sum + line.quantity);
    final complete = delivered == quantity;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: complete
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in section.lines)
                Padding(
                  key: ValueKey('delivery-line-${line.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${numbers.format(line.quantity)} × ${line.name}',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (line.note.isNotEmpty) Text(line.note),
                      if (line.isAddition)
                        Text(
                          l.latestAdditions,
                          style: theme.textTheme.labelMedium,
                        ),
                    ],
                  ),
                ),
              Text(
                complete ? l.deliveredItems : l.outstandingItems,
                style: theme.textTheme.labelLarge,
              ),
              if (delivered > 0 && !complete)
                Text(
                  l.deliveryQuantity(
                    numbers.format(delivered),
                    numbers.format(quantity - delivered),
                  ),
                ),
              if (onChanged != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: ValueKey(
                    'complete-step-${section.course?.id ?? 'ungrouped'}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: busy
                      ? null
                      : () => onChanged!(section.course?.id, !complete),
                  icon: Icon(
                    complete ? Icons.undo_rounded : Icons.done_all_rounded,
                  ),
                  label: Text(complete ? l.undoStepDelivery : l.completeStep),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
