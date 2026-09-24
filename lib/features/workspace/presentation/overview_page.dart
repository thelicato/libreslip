import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.onSelect});
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeCard(onPersonalise: () => onSelect(4)),
        const SizedBox(height: 32),
        Text(l.workspaceTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          l.workspaceSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 3 : 1;
            final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                _WorkspaceCard(
                  width: width,
                  icon: Icons.note_add_outlined,
                  title: l.compose,
                  body: l.composeCardBody,
                  onTap: () => onSelect(2),
                ),
                _WorkspaceCard(
                  width: width,
                  icon: Icons.grid_view_rounded,
                  title: l.items,
                  body: l.itemsCardBody,
                  onTap: () => onSelect(1),
                ),
                _WorkspaceCard(
                  width: width,
                  icon: Icons.receipt_long_outlined,
                  title: l.tickets,
                  body: l.ticketsCardBody,
                  onTap: () => onSelect(3),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onPersonalise});
  final VoidCallback onPersonalise;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        color: AppTheme.ink,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showArtwork =
                constraints.maxWidth >= 650 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.6;
            return Stack(
              children: [
                if (showArtwork)
                  const Positioned(
                    right: -12,
                    top: 0,
                    bottom: 0,
                    width: 280,
                    child: ExcludeSemantics(
                      child: CustomPaint(painter: _TicketArtwork()),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(constraints.maxWidth > 500 ? 36 : 26),
                  child: SizedBox(
                    width: showArtwork
                        ? constraints.maxWidth - 330
                        : double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.heroEyebrow,
                          style: const TextStyle(
                            color: AppTheme.lime,
                            fontSize: 10,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          l.heroTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: constraints.maxWidth > 900 ? 44 : 34,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.heroBody,
                          style: const TextStyle(
                            color: Color(0xFFD1DFD9),
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 26),
                        FilledButton(
                          key: const ValueKey('personalise'),
                          onPressed: onPersonalise,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.lime,
                            foregroundColor: AppTheme.ink,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  l.personaliseWorkspace,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 19,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative ticket artwork, not a saved or printed order.
class _TicketArtwork extends CustomPainter {
  const _TicketArtwork();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.12);
    final outline = Paint()
      ..color = const Color(0xFF31564A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset.zero, 128, outline);
    canvas.drawCircle(Offset.zero, 104, outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-78, -95, 165, 206),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFF102F29),
    );
    final slip = Path()
      ..moveTo(-82, -110)
      ..lineTo(68, -110)
      ..lineTo(68, 102);
    for (var x = 68.0; x > -82; x -= 25) {
      slip
        ..lineTo(x - 12.5, 92)
        ..lineTo(x - 25, 102);
    }
    slip
      ..lineTo(-82, -110)
      ..close();
    canvas.drawPath(slip, Paint()..color = const Color(0xFFF7F7EE));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-58, -82, 78, 13),
        const Radius.circular(4),
      ),
      Paint()..color = AppTheme.ink,
    );
    for (var row = 0; row < 3; row++) {
      final y = -30.0 + row * 31;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-58, y, 12, 12),
          const Radius.circular(3),
        ),
        Paint()..color = AppTheme.teal,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-34, y + 2, row == 1 ? 54 : 72, 8),
          const Radius.circular(4),
        ),
        Paint()..color = AppTheme.ink.withValues(alpha: 0.28),
      );
    }
    canvas.drawCircle(const Offset(64, 83), 32, Paint()..color = AppTheme.lime);
    final arrow = Path()
      ..moveTo(51, 83)
      ..lineTo(77, 83)
      ..moveTo(66, 72)
      ..lineTo(77, 83)
      ..lineTo(66, 94);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = AppTheme.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(90, -97), 7, Paint()..color = AppTheme.lime);
    canvas.drawCircle(
      const Offset(-105, 77),
      4,
      Paint()..color = const Color(0xFFBCD7CA),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketArtwork oldDelegate) => false;
}
