import 'package:asciidoc_editor/controllers/document_controller.dart';
import 'package:asciidoc_editor/main.dart';
import 'package:asciidoc_editor/services/settings_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_controller_test.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget buildApp({
    required Size size,
    required DocumentController controller,
    required SettingsService settings,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: AsciiDocEditorApp(
        documentController: controller,
        settingsService: settings,
      ),
    );
  }

  testWidgets('Googlebook (1280x800) shows editor left, preview right, and no Preview button',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = FakePlatformDocumentService();
    final controller = DocumentController(platformService: service);
    final settings = SettingsService();
    addTearDown(() {
      controller.dispose();
      service.dispose();
      settings.dispose();
    });

    await tester.pumpWidget(
      buildApp(size: const Size(1280, 800), controller: controller, settings: settings),
    );

    final editorFinder = find.byKey(const ValueKey<String>('asciidoc_editor_field'));
    final previewFinder = find.byKey(const ValueKey<String>('asciidoc_preview_pane'));
    final previewButtonFinder = find.byKey(const ValueKey<String>('preview_toggle_button'));

    expect(editorFinder, findsOneWidget);
    expect(previewFinder, findsOneWidget);
    expect(previewButtonFinder, findsNothing);

    final editorRect = tester.getRect(editorFinder);
    final previewRect = tester.getRect(previewFinder);
    expect(editorRect.left, lessThan(previewRect.left));
  });

  testWidgets('Phone (412x915) shows Preview button and toggles between editor and preview',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = FakePlatformDocumentService();
    final controller = DocumentController(platformService: service);
    final settings = SettingsService();
    addTearDown(() {
      controller.dispose();
      service.dispose();
      settings.dispose();
    });

    await tester.pumpWidget(
      buildApp(size: const Size(412, 915), controller: controller, settings: settings),
    );

    final previewButtonFinder = find.byKey(const ValueKey<String>('preview_toggle_button'));
    expect(previewButtonFinder, findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(previewButtonFinder);
    await tester.pump();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('Dark mode persists via SettingsService', (tester) async {
    final settings = SettingsService();
    addTearDown(settings.dispose);

    await settings.load();
    expect(settings.themeMode, ThemeMode.system);

    await settings.setThemeMode(ThemeMode.dark);
    expect(settings.themeMode, ThemeMode.dark);

    final reloaded = SettingsService();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.themeMode, ThemeMode.dark);
  });
}
