import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../services/campus_router.dart';
import 'building_card.dart';
import 'colours.dart';

/// Route options to a building, Google-Maps style: pick one, then Start.
class RoutePanel extends StatelessWidget {
  const RoutePanel({
    super.key,
    required this.destination,
    required this.fromLabel,
    required this.routes,
    required this.selected,
    required this.error,
    required this.canStart,
    required this.startHint,
    required this.onSelect,
    required this.onChangeStart,
    required this.onStart,
    required this.onClose,
  });

  final Destination destination;
  final String fromLabel;
  final List<WalkRoute> routes;
  final int selected;
  final String? error;
  final bool canStart;
  final String? startHint;
  final ValueChanged<int> onSelect;
  final VoidCallback onChangeStart;
  final VoidCallback onStart;
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
            children: [
              const Icon(Icons.directions_walk, color: routeBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Walk to ${destination.title}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
          InkWell(
            onTap: onChangeStart,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.trip_origin, size: 18, color: routeBlue),
                  const SizedBox(width: 8),
                  Text('From: ', style: theme.textTheme.bodyMedium),
                  Flexible(
                    child: Text(
                      fromLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            )
          else if (routes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (var i = 0; i < routes.length; i++)
              _RouteTile(
                route: routes[i],
                recommended: i == 0,
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
          if (routes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Route ends at the path nearest the building. Entrances are not confirmed yet.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: canStart ? onStart : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: routeBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Start'),
                ),
                const SizedBox(width: 12),
                if (!canStart && startHint != null)
                  Expanded(
                    child: Text(startHint!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.route,
    required this.recommended,
    required this.selected,
    required this.onTap,
  });

  final WalkRoute route;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 8),
      child: Material(
        color: selected
            ? const Color(0xFFE8F0FE)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? routeBlue : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(
                  formatDuration(route.duration),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: selected ? routeBlue : null,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatDistance(route.distance),
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                if (recommended)
                  Text(
                    'Recommended',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: routeBlue,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
