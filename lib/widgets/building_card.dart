import 'package:flutter/material.dart';

import '../models/campus_building.dart';
import 'colours.dart';

/// Shown when a building is tapped: name, precinct and a Directions button.
class BuildingCard extends StatelessWidget {
  const BuildingCard({
    super.key,
    required this.building,
    required this.onDirections,
    required this.onClose,
  });

  final CampusBuilding building;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      ...building.aliases,
      if (building.precinct.isNotEmpty) '${building.precinct} precinct',
      if (building.underConstruction) 'Under construction (Aug 2024 map)',
      if (!building.hasLabel) 'No number on the CDU map',
    ];

    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hexColour(building.colourHex),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  building.hasLabel ? building.label.split(' ').last : '?',
                  style: TextStyle(
                    color: onColour(building.colourHex),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(building.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(details.join(' · '), style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onDirections,
                style: FilledButton.styleFrom(
                  backgroundColor: routeBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                icon: const Icon(Icons.directions_walk),
                label: const Text('Directions'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rounded white bottom sheet used by all panels.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => BottomPanel(child: child);
}

class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      shadowColor: Colors.black45,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
