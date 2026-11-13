import 'package:cdu_campus_navigation/config/app_info.dart';
import 'package:cdu_campus_navigation/screens/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('About shows app, developer, disclaimer and copyright', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

    expect(find.text(AppInfo.appName), findsOneWidget);
    expect(find.text(AppInfo.developerName), findsOneWidget);
    expect(find.text('Student ID: ${AppInfo.studentId}'), findsOneWidget);
    expect(find.text(AppInfo.email), findsOneWidget);

    await tester.scrollUntilVisible(find.text(AppInfo.copyright), 300);
    expect(find.text(AppInfo.copyright), findsOneWidget);
    expect(find.textContaining('not an official app'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
  });

  test('copyright line has the year and developer name', () {
    expect(AppInfo.copyright, contains('${AppInfo.copyrightYear}'));
    expect(AppInfo.copyright, contains(AppInfo.developerName));
  });
}
