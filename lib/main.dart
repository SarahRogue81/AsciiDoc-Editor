import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'controllers/document_controller.dart';
import 'services/saf_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'ui/screens/workspace_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final settingsService = SettingsService();
  await settingsService.load();

  final documentController = DocumentController(
    platformService: SafPlatformService(),
  );
  unawaited(documentController.initialize());

  runApp(
    AsciiDocEditorApp(
      documentController: documentController,
      settingsService: settingsService,
    ),
  );
}

class AsciiDocEditorApp extends StatelessWidget {
  const AsciiDocEditorApp({
    super.key,
    required this.documentController,
    required this.settingsService,
  });

  final DocumentController documentController;
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            return MaterialApp(
              title: 'AsciiDoc Editor',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(dynamicSeed: lightDynamic?.primary),
              darkTheme: AppTheme.dark(dynamicSeed: darkDynamic?.primary),
              themeMode: settingsService.themeMode,
              home: WorkspaceScreen(
                documentController: documentController,
                settingsService: settingsService,
              ),
            );
          },
        );
      },
    );
  }
}
