import 'package:flutter/material.dart';

import '../data/campus_repository.dart';
import '../models/destination.dart';
import 'building_card.dart';

/// Full-screen search over buildings and places:
/// "Red 6", "library", "toilet", "coffee", "theatre", "bus" ...
class CampusSearchDelegate extends SearchDelegate<Destination?> {
  CampusSearchDelegate(
    this.campus, {
    String label = 'Search buildings and places',
  }) : super(searchFieldLabel: label);

  final CampusRepository campus;

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final results = campus.searchAll(query);
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nothing with that name on the CDU map. Try a building '
          '(e.g. "Red 6") or a place (e.g. "toilets", "library", "food").',
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final d = results[i];
        return ListTile(
          leading: DestinationBadge(destination: d),
          title: Text(d.title),
          subtitle: d.subtitle.isEmpty ? null : Text(d.subtitle),
          onTap: () => close(context, d),
        );
      },
    );
  }
}
