import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/campus_repository.dart';
import '../models/destination.dart';
import '../models/place_category.dart';
import '../services/walk_graph.dart';
import 'building_card.dart';
import 'colours.dart';

/// Row of buttons under the search bar: Toilets, Food, Library, Parking ...
class QuickFindChips extends StatelessWidget {
  const QuickFindChips({super.key, required this.onCategory});

  final ValueChanged<PlaceCategory> onCategory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final id in PlaceCategory.quickFind)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(PlaceCategory.of(id)),
            ),
        ],
      ),
    );
  }

  Widget _chip(PlaceCategory c) => ActionChip(
    avatar: Icon(c.icon, size: 18, color: c.colour),
    label: Text(c.label),
    backgroundColor: Colors.white,
    elevation: 3,
    shadowColor: Colors.black38,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    onPressed: () => onCategory(c),
  );
}

/// Bottom sheet listing every place of one kind, nearest first.
/// Returns the chosen place as a Destination.
Future<Destination?> showPlaceList(
  BuildContext context, {
  required CampusRepository campus,
  required PlaceCategory category,
  LatLng? from,
}) {
  final places = campus.placesOf(category.id, from: from);
  return showModalBottomSheet<Destination>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              from == null
                  ? category.label
                  : '${category.label} – nearest first',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (places.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                category.id == 'bookshop'
                    ? 'The bookshop is not on the CDU map yet.'
                    : 'None on the CDU map.',
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.only(bottom: webCreditGap),
              itemCount: places.length,
              itemBuilder: (context, i) {
                final d = campus.destinationForPlace(places[i]);
                final metres = from == null
                    ? null
                    : LocalProjection.toMetres(from)
                          .distanceTo(LocalProjection.toMetres(d.point));
                return ListTile(
                  leading: DestinationBadge(destination: d),
                  title: Text(d.title),
                  subtitle: d.subtitle.isEmpty ? null : Text(d.subtitle),
                  trailing: metres == null
                      ? null
                      : Text(
                          formatDistance(metres),
                          style: const TextStyle(
                            color: routeBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  onTap: () => Navigator.pop(context, d),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
