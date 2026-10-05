import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/order_models.dart';

String formatPrice(
  BuildContext context,
  ProductPrice price, {
  int quantity = 1,
}) => formatPriceAmount(context, price.minorUnits * quantity, price.currency);

String formatPriceAmount(
  BuildContext context,
  int minorUnits,
  String currency,
) {
  final formatted = NumberFormat.currency(
    locale: Localizations.localeOf(context).toLanguageTag(),
    name: currency,
    symbol: currency,
    decimalDigits: 2,
  ).format(minorUnits / 100);
  return formatted.startsWith(currency)
      ? formatted.replaceFirst(currency, '$currency\u00a0')
      : formatted;
}

class OrderEstimate extends StatelessWidget {
  const OrderEstimate({super.key, required this.lines});
  final List<TicketLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final estimate = OrderPriceEstimate.fromLines(lines);
    final totals = estimate.totals;
    final missing = estimate.unpricedQuantity;
    return Card(
      key: const ValueKey('order-estimate'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              missing == 0 ? l.estimatedOrderTotal : l.pricedItemsSubtotal,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final currency in totals.keys.toList()..sort())
              Text(
                formatPriceAmount(context, totals[currency]!, currency),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            if (missing > 0) Text(l.priceMissingCount(missing)),
            if (totals.length > 1) Text(l.priceCurrenciesSeparate),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.itemPrices),
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(line.quantity)} × ${line.name}',
                        ),
                        Text(
                          line.price == null
                              ? l.noPrice
                              : l.priceLineEstimate(
                                  formatPrice(context, line.price!),
                                  formatPrice(
                                    context,
                                    line.price!,
                                    quantity: line.quantity,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
