import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../orders/presentation/order_estimate.dart';
import '../domain/ticket_document.dart';

TicketPriceLabels ticketPriceLabels(BuildContext context) {
  final l = AppLocalizations.of(context);
  return TicketPriceLabels(
    total: l.ticketPriceTotal,
    additionsTotal: l.ticketAdditionsTotal,
    subtotal: l.pricedItemsSubtotal,
    noPrice: l.noPrice,
    missingPrices: l.ticketMissingPrices,
    separateCurrencies: l.priceCurrenciesSeparate,
    formatLine: (price, quantity) =>
        formatPrice(context, price, quantity: quantity),
    formatAmount: (amount, currency) =>
        formatPriceAmount(context, amount, currency),
  );
}
