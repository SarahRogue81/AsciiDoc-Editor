import 'dart:async';

import 'package:asciidoc_editor/controllers/document_controller.dart';
import 'package:asciidoc_editor/models/document_state.dart';
import 'package:asciidoc_editor/services/saf_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlatformDocumentService implements PlatformDocumentService {
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();
  final Map<String, String> files = <String, String>{};
  final List<String> writtenContents = <String>[];
  String? initialUri;
  SafDocumentResult? nextOpenResult;
  SafDocumentResult? nextCreateResult;
  String? lastExportedHtml;
  String? lastExportJobName;

  @override
  Future<SafDocumentResult?> openDocument() async => nextOpenResult;

  @override
  Future<SafDocumentResult?> createDocument({
    required String suggestedName,
    required String content,
  }) async {
    final result = nextCreateResult ??
        SafDocumentResult(
          uri: 'content://docs/$suggestedName',
          displayName: suggestedName,
          content: content,
          isReadOnly: false,
        );
    files[result.uri] = content;
    return result;
  }

  @override
  Future<SafDocumentResult> readDocument(String uri) async {
    return SafDocumentResult(
      uri: uri,
      displayName: uri.split('/').last,
      content: files[uri] ?? '',
      isReadOnly: false,
    );
  }

  @override
  Future<void> writeDocument(String uri, String content) async {
    files[uri] = content;
    writtenContents.add(content);
  }

  @override
  Future<String?> getInitialUri() async => initialUri;

  @override
  Stream<String> get incomingUriStream => _incomingController.stream;

  void emitIncomingUri(String uri) => _incomingController.add(uri);

  @override
  Future<void> exportPdf({
    required String html,
    required String jobName,
  }) async {
    lastExportedHtml = html;
    lastExportJobName = jobName;
  }

  void dispose() {
    unawaited(_incomingController.close());
  }
}

void main() {
  group('DocumentController', () {
    late FakePlatformDocumentService service;
    late DocumentController controller;

    setUp(() {
      service = FakePlatformDocumentService();
      controller = DocumentController(
        platformService: service,
        autoSaveDelay: const Duration(milliseconds: 50),
      );
    });

    tearDown(() {
      controller.dispose();
      service.dispose();
    });

    test('untitled draft marks unsaved without auto-saving until backed by URI', () async {
      controller.textController.text = '= Hello AsciiDoc';
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.state.hasBackingFile, isFalse);
      expect(controller.state.saveStatus, SaveStatus.unsaved);
      expect(service.writtenContents, isEmpty);
      expect(controller.needsSavePromptBeforeReplacing, isTrue);
    });

    test('auto-saves debounced edits on a SAF-backed document', () async {
      service.nextOpenResult = const SafDocumentResult(
        uri: 'content://docs/notes.adoc',
        displayName: 'notes.adoc',
        content: '= Notes',
        isReadOnly: false,
      );

      final opened = await controller.openDocument();
      expect(opened, isTrue);
      expect(controller.state.displayName, 'notes.adoc');
      expect(controller.state.saveStatus, SaveStatus.saved);

      controller.textController.text = '= Notes\n\nUpdated paragraph.';
      expect(controller.state.saveStatus, SaveStatus.unsaved);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.state.saveStatus, SaveStatus.saved);
      expect(service.writtenContents, ['= Notes\n\nUpdated paragraph.']);
    });

    test('opens initial URI from Open With intent on initialize', () async {
      service.initialUri = 'content://docs/readme.asciidoc';
      service.files['content://docs/readme.asciidoc'] = '= Readme';

      await controller.initialize();

      expect(controller.state.displayName, 'readme.asciidoc');
      expect(controller.textController.text, '= Readme');
      expect(controller.state.saveStatus, SaveStatus.saved);
    });

    test('flushAutoSave persists pending edits immediately', () async {
      final longDelayController = DocumentController(
        platformService: service,
        autoSaveDelay: const Duration(seconds: 10),
      );
      addTearDown(longDelayController.dispose);

      service.nextOpenResult = const SafDocumentResult(
        uri: 'content://docs/manual.adoc',
        displayName: 'manual.adoc',
        content: '= Manual',
        isReadOnly: false,
      );

      await longDelayController.openDocument();
      longDelayController.textController.text = '= Manual\n\nFlushed!';
      await longDelayController.flushAutoSave();

      expect(longDelayController.state.saveStatus, SaveStatus.saved);
      expect(service.files['content://docs/manual.adoc'], '= Manual\n\nFlushed!');
    });
  });
}
