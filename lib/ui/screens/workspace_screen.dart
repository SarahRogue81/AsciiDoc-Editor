import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../controllers/document_controller.dart';
import '../../models/document_state.dart';
import '../../services/settings_service.dart';
import '../adaptive/layout_breakpoints.dart';
import '../widgets/editor_pane.dart';
import '../widgets/preview_pane.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.documentController,
    required this.settingsService,
  });

  final DocumentController documentController;
  final SettingsService settingsService;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with WidgetsBindingObserver {
  final GlobalKey<PreviewPaneState> _previewKey = GlobalKey<PreviewPaneState>();
  final FocusNode _editorFocusNode = FocusNode();

  bool _showMobilePreview = false;
  double _splitRatio = 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(widget.documentController.flushAutoSave());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!widget.documentController.needsSavePromptBeforeReplacing) {
      return true;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: Text(
          '"${widget.documentController.state.displayName}" has not been saved yet. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (choice == 'discard') return true;
    if (choice == 'save') {
      return widget.documentController.save();
    }
    return false;
  }

  Future<void> _handleNew() async {
    if (!await _confirmDiscardIfNeeded()) return;
    widget.documentController.newDocument();
    if (_showMobilePreview) {
      setState(() => _showMobilePreview = false);
    }
  }

  Future<void> _handleOpen() async {
    if (!await _confirmDiscardIfNeeded()) return;
    await widget.documentController.openDocument();
  }

  Future<void> _handleSave() async {
    await widget.documentController.save();
  }

  Future<void> _handleSaveAs() async {
    await widget.documentController.saveAs();
  }

  Future<void> _handleExportPdf() async {
    try {
      final previewState = _previewKey.currentState;
      final html = previewState != null
          ? await previewState.getExportHtml()
          : '';
      if (html.isEmpty) return;
      await widget.documentController.exportPdf(html);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  Future<void> _showThemePicker() async {
    final current = widget.settingsService.themeMode;
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Appearance'),
        children: [
          _themeOption(context, ThemeMode.system, 'System default', current),
          _themeOption(context, ThemeMode.light, 'Light', current),
          _themeOption(context, ThemeMode.dark, 'Dark', current),
        ],
      ),
    );
    if (selected != null) {
      await widget.settingsService.setThemeMode(selected);
    }
  }

  Widget _themeOption(
    BuildContext context,
    ThemeMode mode,
    String label,
    ThemeMode current,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(mode),
      child: Row(
        children: [
          Icon(
            current == mode
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  String _statusLabel(DocumentState doc) {
    if (doc.isReadOnly) return 'Read-only (Save As to edit)';
    return switch (doc.saveStatus) {
      SaveStatus.idle => doc.hasBackingFile ? 'Saved' : 'New document',
      SaveStatus.unsaved => doc.hasBackingFile ? 'Unsaved…' : 'Unsaved draft',
      SaveStatus.saving => 'Saving…',
      SaveStatus.saved => 'Saved',
      SaveStatus.error => doc.errorMessage ?? 'Save error',
    };
  }

  @override
  Widget build(BuildContext context) {
    final layout = AdaptiveLayoutInfo.fromMediaQuery(MediaQuery.of(context));
    final brightness = Theme.of(context).brightness;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            unawaited(_handleNew()),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            unawaited(_handleOpen()),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            unawaited(_handleSave()),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            unawaited(_handleExportPdf()),
      },
      child: ListenableBuilder(
        listenable: widget.documentController,
        builder: (context, _) {
          final doc = widget.documentController.state;
          final editor = EditorPane(
            controller: widget.documentController.textController,
            undoController: widget.documentController.undoController,
            sizeClass: layout.sizeClass,
            focusNode: _editorFocusNode,
          );
          final preview = PreviewPane(
            key: _previewKey,
            source: doc.content,
            brightness: brightness,
          );

          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doc.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _statusLabel(doc),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: doc.saveStatus == SaveStatus.error
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              actions: [
                if (layout.showPreviewButton)
                  IconButton(
                    key: const ValueKey<String>('preview_toggle_button'),
                    tooltip: _showMobilePreview ? 'Edit' : 'Preview',
                    icon: Icon(
                      _showMobilePreview
                          ? Icons.edit_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() => _showMobilePreview = !_showMobilePreview);
                    },
                  ),
                IconButton(
                  tooltip: 'Open (Ctrl+O)',
                  icon: const Icon(Icons.folder_open_outlined),
                  onPressed: _handleOpen,
                ),
                IconButton(
                  tooltip: 'New (Ctrl+N)',
                  icon: const Icon(Icons.note_add_outlined),
                  onPressed: _handleNew,
                ),
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  onSelected: (value) {
                    switch (value) {
                      case 'save':
                        unawaited(_handleSave());
                      case 'save_as':
                        unawaited(_handleSaveAs());
                      case 'export_pdf':
                        unawaited(_handleExportPdf());
                      case 'theme':
                        unawaited(_showThemePicker());
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'save',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.save_outlined),
                        title: Text('Save'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'save_as',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.save_as_outlined),
                        title: Text('Save As…'),
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'export_pdf',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.picture_as_pdf_outlined),
                        title: Text('Export to PDF'),
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'theme',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.brightness_6_outlined),
                        title: Text('Theme'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: layout.isSplitLayout
                  ? _buildSplitBody(layout, editor, preview)
                  : IndexedStack(
                      index: _showMobilePreview ? 1 : 0,
                      children: [editor, preview],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSplitBody(
    AdaptiveLayoutInfo layout,
    Widget editor,
    Widget preview,
  ) {
    final hinge = layout.verticalHingeBounds;
    if (hinge != null) {
      return Row(
        children: [
          SizedBox(width: hinge.left, child: editor),
          SizedBox(width: hinge.width),
          Expanded(child: preview),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const dividerWidth = 8.0;
        final availableWidth = (totalWidth - dividerWidth).clamp(0.0, double.infinity);
        final leftWidth = availableWidth * _splitRatio;

        return Row(
          children: [
            SizedBox(width: leftWidth, child: editor),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  if (availableWidth <= 0) return;
                  setState(() {
                    _splitRatio = ((leftWidth + details.delta.dx) / availableWidth)
                        .clamp(0.3, 0.7);
                  });
                },
                child: SizedBox(
                  width: dividerWidth,
                  child: Center(
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: preview),
          ],
        );
      },
    );
  }
}
