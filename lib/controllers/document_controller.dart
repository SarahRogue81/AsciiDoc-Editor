import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/document_state.dart';
import '../services/saf_service.dart';

class DocumentController extends ChangeNotifier {
  DocumentController({
    required this.platformService,
    this.autoSaveDelay = const Duration(milliseconds: 800),
  }) {
    textController.addListener(_handleTextChanged);
  }

  final PlatformDocumentService platformService;
  final Duration autoSaveDelay;
  final TextEditingController textController = TextEditingController();
  final UndoHistoryController undoController = UndoHistoryController();

  DocumentState _state = const DocumentState();
  Timer? _autoSaveTimer;
  StreamSubscription<String>? _incomingUriSub;
  bool _suppressTextListener = false;
  bool _isSavingInFlight = false;
  bool _saveQueuedAfterFlight = false;

  DocumentState get state => _state;

  Future<void> initialize() async {
    _incomingUriSub = platformService.incomingUriStream.listen((uri) {
      unawaited(openFromUri(uri));
    });

    try {
      final initialUri = await platformService.getInitialUri();
      if (initialUri != null && initialUri.isNotEmpty) {
        await openFromUri(initialUri);
      }
    } catch (e) {
      _setState(
        _state.copyWith(
          saveStatus: SaveStatus.error,
          errorMessage: 'Could not open incoming file: $e',
        ),
      );
    }
  }

  void newDocument() {
    _cancelAutoSaveTimer();
    _replaceText('');
    _setState(const DocumentState());
  }

  Future<bool> openDocument() async {
    await flushAutoSave();
    try {
      final result = await platformService.openDocument();
      if (result == null) return false;
      _applyLoadedDocument(result);
      return true;
    } catch (e) {
      _setState(
        _state.copyWith(
          saveStatus: SaveStatus.error,
          errorMessage: 'Failed to open file: $e',
        ),
      );
      return false;
    }
  }

  Future<bool> openFromUri(String uri) async {
    await flushAutoSave();
    try {
      final result = await platformService.readDocument(uri);
      _applyLoadedDocument(result);
      return true;
    } catch (e) {
      _setState(
        _state.copyWith(
          saveStatus: SaveStatus.error,
          errorMessage: 'Failed to open file: $e',
        ),
      );
      return false;
    }
  }

  Future<bool> save() async {
    if (_state.hasBackingFile && !_state.isReadOnly) {
      return _writeCurrentToBackingFile();
    }
    return saveAs();
  }

  Future<bool> saveAs() async {
    _cancelAutoSaveTimer();
    final content = textController.text;
    try {
      final result = await platformService.createDocument(
        suggestedName: _state.displayName,
        content: content,
      );
      if (result == null) return false;
      _setState(
        DocumentState(
          uri: result.uri,
          displayName: result.displayName,
          content: content,
          saveStatus: SaveStatus.saved,
          isReadOnly: false,
        ),
      );
      return true;
    } catch (e) {
      _setState(
        _state.copyWith(
          saveStatus: SaveStatus.error,
          errorMessage: 'Failed to save file: $e',
        ),
      );
      return false;
    }
  }

  Future<void> flushAutoSave() async {
    if (_autoSaveTimer?.isActive ?? false) {
      _cancelAutoSaveTimer();
      await _writeCurrentToBackingFile();
    } else if (_state.hasBackingFile &&
        !_state.isReadOnly &&
        _state.saveStatus == SaveStatus.unsaved) {
      await _writeCurrentToBackingFile();
    }
  }

  Future<void> exportPdf(String html) async {
    await platformService.exportPdf(
      html: html,
      jobName: _state.displayName,
    );
  }

  bool get needsSavePromptBeforeReplacing {
    if (!_state.hasUnsavedChanges) return false;
    return !_state.hasBackingFile || _state.isReadOnly;
  }

  void _applyLoadedDocument(SafDocumentResult result) {
    _cancelAutoSaveTimer();
    _replaceText(result.content);
    _setState(
      DocumentState(
        uri: result.uri,
        displayName: result.displayName,
        content: result.content,
        saveStatus: SaveStatus.saved,
        isReadOnly: result.isReadOnly,
      ),
    );
  }

  void _replaceText(String content) {
    _suppressTextListener = true;
    textController.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(offset: content.length),
    );
    _suppressTextListener = false;
  }

  void _handleTextChanged() {
    if (_suppressTextListener) return;
    final currentText = textController.text;
    if (currentText == _state.content) return;

    _setState(
      _state.copyWith(
        content: currentText,
        saveStatus: SaveStatus.unsaved,
        clearError: true,
      ),
    );

    if (_state.hasBackingFile && !_state.isReadOnly) {
      _scheduleAutoSave();
    }
  }

  void _scheduleAutoSave() {
    _cancelAutoSaveTimer();
    _autoSaveTimer = Timer(autoSaveDelay, () {
      unawaited(_writeCurrentToBackingFile());
    });
  }

  void _cancelAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  Future<bool> _writeCurrentToBackingFile() async {
    final uri = _state.uri;
    if (uri == null || uri.isEmpty || _state.isReadOnly) return false;

    if (_isSavingInFlight) {
      _saveQueuedAfterFlight = true;
      return false;
    }

    _isSavingInFlight = true;
    final contentSnapshot = textController.text;
    _setState(_state.copyWith(saveStatus: SaveStatus.saving, clearError: true));

    try {
      await platformService.writeDocument(uri, contentSnapshot);
      final stillMatches = textController.text == contentSnapshot && _state.uri == uri;
      _setState(
        _state.copyWith(
          saveStatus: stillMatches ? SaveStatus.saved : SaveStatus.unsaved,
          clearError: true,
        ),
      );
      return true;
    } catch (e) {
      _setState(
        _state.copyWith(
          saveStatus: SaveStatus.error,
          errorMessage: 'Auto-save failed: $e',
        ),
      );
      return false;
    } finally {
      _isSavingInFlight = false;
      if (_saveQueuedAfterFlight) {
        _saveQueuedAfterFlight = false;
        if (_state.hasBackingFile &&
            !_state.isReadOnly &&
            _state.saveStatus == SaveStatus.unsaved) {
          unawaited(_writeCurrentToBackingFile());
        }
      }
    }
  }

  void _setState(DocumentState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelAutoSaveTimer();
    unawaited(_incomingUriSub?.cancel());
    textController.removeListener(_handleTextChanged);
    textController.dispose();
    undoController.dispose();
    super.dispose();
  }
}
