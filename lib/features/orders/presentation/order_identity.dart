import 'package:flutter/material.dart';

/// Gives an optional title prominence while retaining the ticket number.
class OrderIdentity extends StatelessWidget {
  const OrderIdentity({
    super.key,
    required this.reference,
    required this.numberLabel,
  });

  final String reference;
  final String numberLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            reference.isEmpty ? numberLabel : reference,
            style: theme.textTheme.titleLarge,
          ),
        ),
        if (reference.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            numberLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
