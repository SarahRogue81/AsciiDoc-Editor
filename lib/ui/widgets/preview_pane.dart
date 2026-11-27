import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PreviewPane extends StatefulWidget {
  const PreviewPane({
    super.key,
    required this.source,
    required this.brightness,
  });

  final String source;
  final Brightness brightness;

  @override
  State<PreviewPane> createState() => PreviewPaneState();
}

class PreviewPaneState extends State<PreviewPane> {
  WebViewController? _controller;
  bool _pageReady = false;
  Timer? _renderDebounce;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    if (WebViewPlatform.instance == null) {
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _pageReady = true;
            _syncTheme(widget.brightness);
            _renderNow(widget.source);
          },
        ),
      );

    _controller = controller;
    unawaited(controller.loadFlutterAsset('assets/preview/index.html'));
  }

  @override
  void didUpdateWidget(covariant PreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness) {
      _syncTheme(widget.brightness);
    }
    if (oldWidget.source != widget.source) {
      _scheduleRender(widget.source);
    }
  }

  void _scheduleRender(String source) {
    _renderDebounce?.cancel();
    _renderDebounce = Timer(const Duration(milliseconds: 220), () {
      _renderNow(source);
    });
  }

  void _syncTheme(Brightness brightness) {
    final controller = _controller;
    if (!_pageReady || controller == null) return;
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    unawaited(controller.runJavaScript("window.setTheme('$mode');"));
  }

  void _renderNow(String source) {
    final controller = _controller;
    if (!_pageReady || controller == null) return;
    final encoded = base64Encode(utf8.encode(source));
    unawaited(controller.runJavaScript("window.renderAsciiDoc('$encoded');"));
  }

  Future<String> getExportHtml() async {
    final controller = _controller;
    if (_pageReady && controller != null) {
      // Ensure the latest source is rendered before exporting.
      final encoded = base64Encode(utf8.encode(widget.source));
      await controller.runJavaScript("window.renderAsciiDoc('$encoded');");
      final raw = await controller.runJavaScriptReturningResult(
        'window.getExportHtml()',
      );
      final decoded = _decodeJsStringResult(raw);
      if (decoded.isNotEmpty) {
        return decoded;
      }
    }
    return _buildFallbackExportHtml(widget.source);
  }

  String _decodeJsStringResult(Object raw) {
    if (raw is String) {
      if (raw.startsWith('"') && raw.endsWith('"')) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is String) return parsed;
        } catch (_) {
          // Fall through to raw value.
        }
      }
      return raw;
    }
    return raw.toString();
  }

  String _buildFallbackExportHtml(String source) {
    final escaped = const HtmlEscape().convert(source);
    return '''
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="asciidoctor.css">
  <link rel="stylesheet" href="preview_theme.css">
</head>
<body class="article print-export">
  <div id="content" class="preview-root"><pre>$escaped</pre></div>
</body>
</html>
''';
  }

  @override
  void dispose() {
    _renderDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = _controller;

    return Container(
      key: const ValueKey<String>('asciidoc_preview_pane'),
      color: colorScheme.surface,
      child: controller != null
          ? WebViewWidget(controller: controller)
          : Center(
              child: Text(
                'AsciiDoc Preview',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
    );
  }
}
