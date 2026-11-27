import 'package:flutter/foundation.dart';

enum SaveStatus {
  idle,
  unsaved,
  saving,
  saved,
  error,
}

@immutable
class DocumentState {
  const DocumentState({
    this.uri,
    this.displayName = 'Untitled.adoc',
    this.content = '',
    this.saveStatus = SaveStatus.idle,
    this.isReadOnly = false,
    this.errorMessage,
  });

  final String? uri;
  final String displayName;
  final String content;
  final SaveStatus saveStatus;
  final bool isReadOnly;
  final String? errorMessage;

  bool get hasBackingFile => uri != null && uri!.isNotEmpty;

  bool get hasUnsavedChanges => saveStatus == SaveStatus.unsaved;

  DocumentState copyWith({
    String? uri,
    bool clearUri = false,
    String? displayName,
    String? content,
    SaveStatus? saveStatus,
    bool? isReadOnly,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DocumentState(
      uri: clearUri ? null : (uri ?? this.uri),
      displayName: displayName ?? this.displayName,
      content: content ?? this.content,
      saveStatus: saveStatus ?? this.saveStatus,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
