/// Optional estimates use integer minor units; they do not record payments.
class ProductPrice {
  const ProductPrice({required this.minorUnits, required this.currency});
  static const currencies = ['EUR', 'GBP', 'USD'];
  static const maximumMinorUnits = 99999999;
  final int minorUnits;
  final String currency;
  bool get isValid =>
      minorUnits >= 0 &&
      minorUnits <= maximumMinorUnits &&
      currencies.contains(currency);

  static ProductPrice? fromColumns(Object? amount, Object? currency) {
    if (amount == null && currency == null) return null;
    if (amount is! int || currency is! String) {
      throw const FormatException('Invalid product price');
    }
    final price = ProductPrice(minorUnits: amount, currency: currency);
    if (!price.isValid) throw const FormatException('Invalid product price');
    return price;
  }

  /// No grouping or exponent notation. A blank value means no price.
  static ProductPrice? parse(String input, String currency) {
    final value = input.trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^\d{1,6}(?:[.,]\d{1,2})?$').hasMatch(value)) {
      throw const FormatException('Invalid product price');
    }
    final parts = value.split(RegExp('[.,]'));
    final amount =
        int.parse(parts.first) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
    return fromColumns(amount, currency);
  }

  @override
  bool operator ==(Object other) =>
      other is ProductPrice &&
      minorUnits == other.minorUnits &&
      currency == other.currency;
  @override
  int get hashCode => Object.hash(minorUnits, currency);
}
