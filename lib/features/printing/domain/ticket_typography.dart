import 'package:flutter/foundation.dart';

@immutable
class TicketTypography {
  const TicketTypography({
    this.heading = defaultHeading,
    this.details = defaultDetails,
    this.items = defaultItems,
    this.notes = defaultNotes,
    this.footer = defaultFooter,
  });

  static const defaultHeading = 14;
  static const defaultDetails = 8;
  static const defaultItems = 8;
  static const defaultNotes = 7;
  static const defaultFooter = 8;

  static const minHeading = 10;
  static const maxHeading = 24;
  static const minDetails = 6;
  static const maxDetails = 14;
  static const minItems = 7;
  static const maxItems = 18;
  static const minNotes = 6;
  static const maxNotes = 14;
  static const minFooter = 6;
  static const maxFooter = 14;

  static const previewScale = 1.8;

  final int heading;
  final int details;
  final int items;
  final int notes;
  final int footer;

  bool get isValid =>
      _within(heading, minHeading, maxHeading) &&
      _within(details, minDetails, maxDetails) &&
      _within(items, minItems, maxItems) &&
      _within(notes, minNotes, maxNotes) &&
      _within(footer, minFooter, maxFooter);

  TicketTypography copyWith({
    int? heading,
    int? details,
    int? items,
    int? notes,
    int? footer,
  }) => TicketTypography(
    heading: heading ?? this.heading,
    details: details ?? this.details,
    items: items ?? this.items,
    notes: notes ?? this.notes,
    footer: footer ?? this.footer,
  );

  Map<String, Object?> toJson() => {
    'heading': heading,
    'details': details,
    'items': items,
    'notes': notes,
    'footer': footer,
  };

  factory TicketTypography.fromJson(Map<String, dynamic> json) {
    final typography = TicketTypography(
      heading: _integer(json['heading']),
      details: _integer(json['details']),
      items: _integer(json['items']),
      notes: _integer(json['notes']),
      footer: _integer(json['footer']),
    );
    if (!typography.isValid) {
      throw const FormatException('Invalid ticket typography');
    }
    return typography;
  }

  static int _integer(Object? value) {
    if (value is! int) throw const FormatException('Invalid font size');
    return value;
  }

  static bool _within(int value, int minimum, int maximum) =>
      value >= minimum && value <= maximum;
}
