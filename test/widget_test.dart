import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:momentum/main.dart';
import 'package:momentum/services/hive_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    tempDir = await Directory.systemTemp.createTemp('momentum_widget_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('renders the app shell', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(hiveService: HiveService.instance));
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
    expect(find.byType(MainScreen), findsOneWidget);
  });
}
