import 'package:flutter/material.dart';

import '../data/campus_repository.dart';
import '../models/campus_building.dart';
import 'colours.dart';

/// Full-screen building search ("Red 6", "library", "blue 2", ...).
class CampusSearchDelegate extends SearchDelegate<CampusBuilding?> {
  CampusSearchDelegate(this.campus) : super(searchFieldLabel: 'Search CDU buildings');

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
    final results = campus.search(query);
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No building with that name on the CDU map.'),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final b = results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: hexColour(b.colourHex),
            child: Text(
              b.label.split(' ').last,
              style: TextStyle(
                color: onColour(b.colourHex),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          title: Text(b.label),
          subtitle: b.aliases.isEmpty && !b.underConstruction
              ? Text('${b.precinct} precinct')
              : Text([
                  ...b.aliases,
                  if (b.underConstruction) 'Under construction',
                ].join(' · ')),
          onTap: () => close(context, b),
        );
      },
    );
  }
}
