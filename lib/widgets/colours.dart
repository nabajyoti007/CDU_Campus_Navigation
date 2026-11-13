import 'package:flutter/material.dart';

const Color cduNavy = Color(0xFF211858);
const Color routeBlue = Color(0xFF1A56C7);

Color hexColour(String hex) =>
    Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));

/// Black or white text, whichever reads better on [hex].
Color onColour(String hex) =>
    hexColour(hex).computeLuminance() > 0.45 ? cduNavy : Colors.white;

String formatDistance(double metres) => metres < 1000
    ? '${(metres / 5).round() * 5} m'
    : '${(metres / 1000).toStringAsFixed(1)} km';

String formatDuration(Duration d) {
  final m = (d.inSeconds / 60).ceil();
  return m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';
}
