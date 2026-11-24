import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../models/place_category.dart';
import 'colours.dart';

/// Shown when a building or place is tapped: name, details and Directions.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.destination,
    required this.onDirections,
    required this.onClose,
  });

  final Destination destination;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DestinationBadge(destination: destination, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.subtitle,
                      style: theme.textTheme.bodyMedium,
                    ),
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
    );
  }
}

/// Square with the building number in its precinct colour, or the place's icon.
class DestinationBadge extends StatelessWidget {
  const DestinationBadge({
    super.key,
    required this.destination,
    this.size = 40,
  });

  final Destination destination;
  final double size;

  @override
  Widget build(BuildContext context) {
    final place = destination.place;
    if (place != null) {
      final c = PlaceCategory.of(place.category);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.colour,
          shape: c.round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: c.round ? null : BorderRadius.circular(size * 0.25),
        ),
        child: Icon(c.icon, color: Colors.white, size: size * 0.58),
      );
    }
    final b = destination.building!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hexColour(b.colourHex),
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Text(
        b.hasLabel ? b.label.split(' ').last : '?',
        style: TextStyle(
          color: onColour(b.colourHex),
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Rounded white bottom sheet used by all panels.
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
