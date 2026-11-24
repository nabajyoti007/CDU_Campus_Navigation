import 'package:flutter/material.dart';

import '../models/destination.dart';
import 'building_card.dart';
import 'colours.dart';

/// Shown while walking: time and distance left, or "You have arrived".
class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.destination,
    required this.remainingMetres,
    required this.arrived,
    required this.rerouting,
    required this.onEnd,
  });

  final Destination destination;
  final double remainingMetres;
  final bool arrived;
  final bool rerouting;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = Duration(seconds: (remainingMetres / 1.25).round());

    return BottomPanel(
      child: Row(
        children: [
          Icon(
            arrived ? Icons.flag : Icons.directions_walk,
            color: arrived ? Colors.green.shade700 : routeBlue,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (arrived) ...[
                  Text(
                    'You have arrived',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('${destination.title} is right next to you.'),
                ] else ...[
                  Text(
                    '${formatDuration(minutes)} · ${formatDistance(remainingMetres)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: routeBlue,
                    ),
                  ),
                  Text(
                    rerouting
                        ? 'Finding a new route…'
                        : 'Walking to ${destination.title}',
                  ),
                ],
              ],
            ),
          ),
          FilledButton(
            onPressed: onEnd,
            style: FilledButton.styleFrom(
              backgroundColor: arrived
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
            child: Text(arrived ? 'Done' : 'End'),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
