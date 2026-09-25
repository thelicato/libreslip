import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';

class AppVersionFooter extends StatefulWidget {
  const AppVersionFooter({super.key});

  @override
  State<AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<AppVersionFooter> {
  late final Future<String> _version = rootBundle
      .loadString('VERSION')
      .then((value) => value.trim());

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _version,
    builder: (context, snapshot) {
      final version = snapshot.data;
      if (version == null || version.isEmpty) return const SizedBox.shrink();
      final label = AppLocalizations.of(context).appVersion(version);
      return Semantics(
        label: label,
        excludeSemantics: true,
        child: Text(
          label,
          key: const ValueKey('app-version'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    },
  );
}
