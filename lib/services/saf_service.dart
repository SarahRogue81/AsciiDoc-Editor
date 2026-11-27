import 'package:flutter/services.dart';

class SafDocumentResult {
  const SafDocumentResult({
    required this.uri,
    required this.displayName,
    required this.content,
    required this.isReadOnly,
  });

  final String uri;
  final String displayName;
  final String content;
  final bool isReadOnly;

  factory SafDocumentResult.fromMap(Map<Object?, Object?> map) {
    return SafDocumentResult(
      uri: (map['uri'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? 'Untitled.adoc',
      content: (map['content'] as String?) ?? '',
      isReadOnly: (map['isReadOnly'] as bool?) ?? false,
    );
  }
}

abstract class PlatformDocumentService {
  Future<SafDocumentResult?> openDocument();
  Future<SafDocumentResult?> createDocument({
    required String suggestedName,
    required String content,
  });
  Future<SafDocumentResult> readDocument(String uri);
  Future<void> writeDocument(String uri, String content);
  Future<String?> getInitialUri();
  Stream<String> get incomingUriStream;
  Future<void> exportPdf({
    required String html,
    required String jobName,
  });
}

class SafPlatformService implements PlatformDocumentService {
  static const MethodChannel _channel =
      MethodChannel('com.sarahrogue81.asciidoc_editor/platform');
  static const EventChannel _incomingUriChannel =
      EventChannel('com.sarahrogue81.asciidoc_editor/incoming_uri');

  Stream<String>? _cachedIncomingStream;

  @override
  Future<SafDocumentResult?> openDocument() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>('openDocument');
    if (result == null) return null;
    return SafDocumentResult.fromMap(result);
  }

  @override
  Future<SafDocumentResult?> createDocument({
    required String suggestedName,
    required String content,
  }) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'createDocument',
      <String, Object?>{
        'suggestedName': suggestedName,
        'content': content,
      },
    );
    if (result == null) return null;
    return SafDocumentResult.fromMap(result);
  }

  @override
  Future<SafDocumentResult> readDocument(String uri) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'readDocument',
      <String, Object?>{'uri': uri},
    );
    if (result == null) {
      throw PlatformException(
        code: 'EMPTY_RESULT',
        message: 'Failed to read document at $uri',
      );
    }
    return SafDocumentResult.fromMap(result);
  }

  @override
  Future<void> writeDocument(String uri, String content) async {
    await _channel.invokeMethod<bool>(
      'writeDocument',
      <String, Object?>{
        'uri': uri,
        'content': content,
      },
    );
  }

  @override
  Future<String?> getInitialUri() async {
    return _channel.invokeMethod<String>('getInitialUri');
  }

  @override
  Stream<String> get incomingUriStream {
    _cachedIncomingStream ??= _incomingUriChannel
        .receiveBroadcastStream()
        .where((event) => event is String && event.isNotEmpty)
        .cast<String>();
    return _cachedIncomingStream!;
  }

  @override
  Future<void> exportPdf({
    required String html,
    required String jobName,
  }) async {
    await _channel.invokeMethod<bool>(
      'exportPdf',
      <String, Object?>{
        'html': html,
        'jobName': jobName,
      },
    );
  }
}
