import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_info.dart';
import '../widgets/colours.dart';

/// About: what the app is, who made it, where the data comes from, and copyright.
/// All personal details come from lib/config/app_info.dart.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // App header
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: cduNavy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.directions_walk, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 14),
                Text(AppInfo.appName,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Version ${AppInfo.version}', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(AppInfo.tagline,
                    textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _Section(
            title: 'About this app',
            child: Text(AppInfo.description, style: theme.textTheme.bodyMedium),
          ),

          _Section(
            title: 'Developer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: cduNavy,
                      child: Text(_initials(AppInfo.developerName),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppInfo.developerName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            [AppInfo.developerRole, AppInfo.course, AppInfo.university]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (AppInfo.studentId.isNotEmpty)
                            Text('Student ID: ${AppInfo.studentId}',
                                style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                if (AppInfo.email.isNotEmpty)
                  _CopyRow(icon: Icons.email_outlined, text: AppInfo.email),
                if (AppInfo.website.isNotEmpty)
                  _CopyRow(icon: Icons.link, text: AppInfo.website),
              ],
            ),
          ),

          _Section(
            title: 'Map data and credits',
            child: Column(
              children: const [
                _Credit(
                  title: 'CDU Casuarina Campus Map (August 2024)',
                  detail: 'Building names, precinct colours and place names. '
                      '© Charles Darwin University.',
                ),
                _Credit(
                  title: 'OpenStreetMap',
                  detail: 'Building shapes and walking paths. '
                      '© OpenStreetMap contributors, Open Database Licence (ODbL).',
                ),
                _Credit(
                  title: 'OpenFreeMap',
                  detail: 'Street map tiles, based on OpenStreetMap data.',
                ),
                _Credit(
                  title: 'MapLibre',
                  detail: 'Open-source map display.',
                ),
              ],
            ),
          ),

          _Section(
            title: 'Privacy',
            child: Text(AppInfo.privacy, style: theme.textTheme.bodyMedium),
          ),

          _Section(
            title: 'Disclaimer',
            child: Text(AppInfo.disclaimer, style: theme.textTheme.bodyMedium),
          ),

          Card(
            margin: const EdgeInsets.only(top: 4),
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open-source licences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppInfo.appName,
                applicationVersion: AppInfo.version,
                applicationLegalese: AppInfo.copyright,
              ),
            ),
          ),

          const SizedBox(height: 28),
          Center(
            child: Text(
              AppInfo.copyright,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cduNavy,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline, size: 18, color: cduNavy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A contact line; tap to copy it.
class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Copied')));
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cduNavy),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
            const Icon(Icons.copy, size: 16, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
