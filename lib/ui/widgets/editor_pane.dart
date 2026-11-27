import 'package:material_ui/material_ui.dart';

import '../adaptive/layout_breakpoints.dart';

class EditorPane extends StatelessWidget {
  const EditorPane({
    super.key,
    required this.controller,
    required this.undoController,
    required this.sizeClass,
    this.focusNode,
  });

  final TextEditingController controller;
  final UndoHistoryController undoController;
  final DeviceSizeClass sizeClass;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalPadding = switch (sizeClass) {
      DeviceSizeClass.large => 28.0,
      DeviceSizeClass.expanded => 24.0,
      DeviceSizeClass.medium => 20.0,
      DeviceSizeClass.compact => 16.0,
    };
    final fontSize = switch (sizeClass) {
      DeviceSizeClass.large => 15.5,
      DeviceSizeClass.expanded => 15.0,
      DeviceSizeClass.medium => 14.5,
      DeviceSizeClass.compact => 14.5,
    };

    return Container(
      color: colorScheme.surface,
      child: TextField(
        key: const ValueKey<String>('asciidoc_editor_field'),
        controller: controller,
        undoController: undoController,
        focusNode: focusNode,
        expands: true,
        maxLines: null,
        minLines: null,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        autocorrect: false,
        enableSuggestions: false,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          height: 1.55,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 20,
          ),
          hintText: '= Document Title\n\nWrite your AsciiDoc content here…',
          hintStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            height: 1.55,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
