import 'package:flutter/material.dart';

/// How each kind of place looks on the map and in lists.
///
/// Facilities (toilets, food, ATM ...) use the PDF map's style: white symbol on
/// a blue square. Named destinations (library, theatre, gallery ...) get their
/// own colours so they stand out.
class PlaceCategory {
  const PlaceCategory(
    this.id,
    this.label,
    this.icon,
    this.colour, {
    this.round = false,
    this.major = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color colour;

  /// Round marker (named destinations) instead of the PDF's square.
  final bool round;

  /// Named destinations shown with their name from further out.
  final bool major;

  static const _pdfBlue = Color(0xFF0062A0);

  static const all = <PlaceCategory>[
    PlaceCategory(
      'library',
      'Library',
      Icons.local_library,
      Color(0xFF7A1E3A),
      round: true,
      major: true,
    ),
    PlaceCategory(
      'venue',
      'Theatre & venue',
      Icons.theater_comedy,
      Color(0xFF211858),
      round: true,
      major: true,
    ),
    PlaceCategory(
      'gallery',
      'Gallery',
      Icons.palette,
      Color(0xFF00796B),
      round: true,
      major: true,
    ),
    PlaceCategory(
      'services',
      'Student services',
      Icons.support_agent,
      Color(0xFF5E35B1),
      round: true,
      major: true,
    ),
    PlaceCategory(
      'bookshop',
      'Bookshop',
      Icons.menu_book,
      Color(0xFF8D4E2A),
      round: true,
      major: true,
    ),
    PlaceCategory(
      'outdoor',
      'Garden & outdoor',
      Icons.park,
      Color(0xFF2E7D32),
      round: true,
      major: true,
    ),
    PlaceCategory('food', 'Food & café', Icons.restaurant, Color(0xFFE65100)),
    PlaceCategory('toilets', 'Toilets', Icons.wc, _pdfBlue),
    PlaceCategory(
      'parents',
      'Parents & carers room',
      Icons.baby_changing_station,
      _pdfBlue,
    ),
    PlaceCategory('info', 'Information', Icons.info, _pdfBlue),
    PlaceCategory('atm', 'ATM', Icons.atm, _pdfBlue),
    PlaceCategory('post', 'Post office', Icons.mail, _pdfBlue),
    PlaceCategory('security', 'Security', Icons.local_police, _pdfBlue),
    PlaceCategory('bus', 'Bus stop', Icons.directions_bus, _pdfBlue),
    PlaceCategory('taxi', 'Taxi drop-off', Icons.local_taxi, _pdfBlue),
    PlaceCategory('parking', 'Car park', Icons.local_parking, _pdfBlue),
  ];

  static final Map<String, PlaceCategory> byId = {for (final c in all) c.id: c};

  static PlaceCategory of(String id) => byId[id] ?? byId['info']!;

  /// Quick-find buttons under the search bar, in this order.
  static const quickFind = [
    'toilets',
    'food',
    'library',
    'venue',
    'outdoor',
    'parking',
    'bus',
    'atm',
    'services',
    'gallery',
  ];
}
