import 'docupass_models.dart';

class DocupassApiError implements Exception {
  const DocupassApiError({
    required this.message,
    this.code,
    this.httpStatus,
    this.rawBody,
  });

  final String message;
  final String? code;
  final int? httpStatus;
  final String? rawBody;
}

DocupassNormalizedError normalizeDocupassError(DocupassApiError error) {
  return normalizeDocupassErrorParts(
    code: error.code,
    message: error.message,
    httpStatus: error.httpStatus,
    rawBody: error.rawBody,
  );
}

DocupassNormalizedError normalizeDocupassErrorParts({
  String? code,
  String? message,
  int? httpStatus,
  String? rawBody,
}) {
  final normalizedCode = _normalizedKeyOrNull(code);
  final rawMessage = message?.trim();

  switch (normalizedCode) {
    case 'DOCUPASS_COMPLETED':
      return DocupassNormalizedError(
        code: normalizedCode,
        title: 'Verification completed',
        detail:
            'The DocuPass verification has already been completed successfully.',
        suggestion: _isLikelyUrl(rawMessage)
            ? 'Show the completed state and continue to the returned redirect URL.'
            : 'Show the completed state and stop submitting more verification data.',
        action: DocupassErrorAction.showCompleted,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
    case 'DOCUPASS_FAILED':
      return DocupassNormalizedError(
        code: normalizedCode,
        title: 'Verification failed',
        detail:
            'The DocuPass verification has reached a failed or rejected final state.',
        suggestion: _isLikelyUrl(rawMessage)
            ? 'Show the failed state and continue to the returned redirect URL.'
            : 'Show the failed state. Do not retry the same completed session.',
        action: DocupassErrorAction.showFailed,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
    case 'DOCUPASS_INVALID_ACTION':
      return _template(
        code: normalizedCode,
        title: 'Session is out of sync',
        detail:
            'The current DocuPass step no longer matches the server session.',
        suggestion:
            'Refresh the session and continue from the server supplied step.',
        action: DocupassErrorAction.resyncSession,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
    case 'DOCUPASS_DOCUMENT_REJECTED':
      return _rejected(
        code: normalizedCode!,
        message: rawMessage,
        title: 'Document rejected',
        detail: 'The document verification was rejected by the server.',
        suggestion:
            'Retake the document photo with the full document visible, focused, and free of glare.',
        action: DocupassErrorAction.retakeDocument,
        httpStatus: httpStatus,
        rawBody: rawBody,
      );
    case 'DOCUPASS_FACE_REJECTED':
      return _rejected(
        code: normalizedCode!,
        message: rawMessage,
        title: 'Face verification failed',
        detail: 'The face verification was rejected by the server.',
        suggestion:
            'Retake the selfie in good lighting and follow the liveness instructions.',
        action: DocupassErrorAction.retakeFace,
        httpStatus: httpStatus,
        rawBody: rawBody,
      );
    case 'DOCUPASS_FATAL_ERROR':
      return _template(
        code: normalizedCode,
        subCode: _normalizedKeyOrNull(rawMessage),
        title: 'Fatal DocuPass session error',
        detail:
            'The session cannot continue because the server rejected the reference, session, or required context.',
        suggestion:
            'Restart from a valid DocuPass link. If this repeats, ask the link issuer to create a new link.',
        action: DocupassErrorAction.fatal,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
    case 'DOCUPASS_GENERIC_ERROR':
      return _template(
        code: normalizedCode,
        subCode: _normalizedKeyOrNull(rawMessage),
        title: 'DocuPass input error',
        detail: 'The server rejected the current input.',
        suggestion: 'Review the entered data and try again.',
        action: DocupassErrorAction.editInput,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
    case 'ERROR_INVALID_VALUE':
      return _invalidValue(rawMessage, httpStatus, rawBody);
    case 'ERROR_OPERATION_FAILED':
      return _template(
        code: normalizedCode,
        subCode: rawMessage?.isNotEmpty == true ? rawMessage : null,
        title: 'Operation failed',
        detail: rawMessage?.isNotEmpty == true
            ? rawMessage!
            : 'The server rejected the requested operation.',
        suggestion: 'Review the request settings and try again.',
        action: DocupassErrorAction.editInput,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
    case 'ERROR_INTERNAL_ERROR':
      return _template(
        code: normalizedCode,
        title: 'Technical error',
        detail: rawMessage != null &&
                rawMessage.isNotEmpty &&
                rawMessage != 'Internal server error.'
            ? 'The server returned an internal error: $rawMessage'
            : 'The server hit an internal error while processing the request.',
        suggestion:
            'Retry once. If the same error repeats, contact support with the reference and request step.',
        action: DocupassErrorAction.contactSupport,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
    case 'LOCAL_VALIDATION':
    case 'NETWORK_ERROR':
      return _template(
        code: normalizedCode,
        title:
            normalizedCode == 'NETWORK_ERROR' ? 'Network error' : 'Input error',
        detail: rawMessage?.isNotEmpty == true
            ? rawMessage!
            : 'The request could not be completed.',
        suggestion: normalizedCode == 'NETWORK_ERROR'
            ? 'Check the connection and try again.'
            : 'Review the current step and try again.',
        action: DocupassErrorAction.retry,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
    default:
      return _template(
        code: normalizedCode,
        title: 'Unexpected DocuPass error',
        detail: rawMessage?.isNotEmpty == true
            ? rawMessage!
            : 'The server returned an unmapped error.',
        suggestion: 'Show this message and keep the raw error for debugging.',
        action: DocupassErrorAction.contactSupport,
        httpStatus: httpStatus,
        rawMessage: rawMessage,
        rawBody: rawBody,
      );
  }
}

String formatApiErrorMessage(DocupassApiError error) {
  final rawMessage = error.message.trim();
  if (rawMessage.isNotEmpty && !_isDiagnosticTokenList(rawMessage)) {
    return rawMessage;
  }
  final normalized = normalizeDocupassError(error);
  return normalized.detail.isNotEmpty ? normalized.detail : normalized.title;
}

DocupassNormalizedError _invalidValue(
  String? message,
  int? httpStatus,
  String? rawBody,
) {
  final field = message?.trim() ?? '';
  return switch (field) {
    'document' => _template(
        code: 'ERROR_INVALID_VALUE',
        subCode: field,
        title: 'Document image missing',
        detail: 'The request did not include a valid front document image.',
        suggestion:
            'Retake or reselect the front document image before uploading.',
        action: DocupassErrorAction.retakeDocument,
        httpStatus: httpStatus,
        rawMessage: message,
        rawBody: rawBody,
      ),
    'face' => _template(
        code: 'ERROR_INVALID_VALUE',
        subCode: field,
        title: 'Face image missing',
        detail: 'The request did not include a valid face image or face video.',
        suggestion:
            'Restart face capture and submit at least one valid face frame.',
        action: DocupassErrorAction.retakeFace,
        httpStatus: httpStatus,
        rawMessage: message,
        rawBody: rawBody,
      ),
    _ => _template(
        code: 'ERROR_INVALID_VALUE',
        subCode: field.isNotEmpty ? field : null,
        title: 'Invalid request value',
        detail: field.isNotEmpty
            ? "Parameter '$field' is missing or contains an invalid value."
            : 'A required parameter is missing or invalid.',
        suggestion: 'Fix the request payload and try again.',
        action: DocupassErrorAction.editInput,
        httpStatus: httpStatus,
        rawMessage: message,
        rawBody: rawBody,
      ),
  };
}

DocupassNormalizedError _rejected({
  required String code,
  required String? message,
  required String title,
  required String detail,
  required String suggestion,
  required DocupassErrorAction action,
  required int? httpStatus,
  required String? rawBody,
}) {
  final warningCodes = message
          ?.split(',')
          .map(_normalizedKeyOrNull)
          .whereType<String>()
          .toList(growable: false) ??
      const <String>[];
  return _template(
    code: code,
    subCode: warningCodes.isNotEmpty ? warningCodes.first : null,
    title: title,
    detail: detail,
    suggestion: suggestion,
    action: action,
    warningCodes: warningCodes,
    httpStatus: httpStatus,
    rawMessage: message,
    rawBody: rawBody,
  );
}

DocupassNormalizedError _template({
  required String? code,
  String? subCode,
  required String title,
  required String detail,
  required String suggestion,
  required DocupassErrorAction action,
  List<String> warningCodes = const <String>[],
  required int? httpStatus,
  required String? rawMessage,
  required String? rawBody,
}) {
  return DocupassNormalizedError(
    code: code,
    subCode: subCode,
    title: title,
    detail: detail,
    suggestion: suggestion,
    action: action,
    warningCodes: warningCodes,
    httpStatus: httpStatus,
    rawMessage: rawMessage,
    rawBody: rawBody,
  );
}

String? _normalizedKeyOrNull(String? value) {
  final text =
      value?.trim().toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
  if (text == null || text.isEmpty) return null;
  return text;
}

bool _isLikelyUrl(String? value) {
  if (value == null) return false;
  return value.startsWith('http://') || value.startsWith('https://');
}

bool _isDiagnosticTokenList(String value) {
  final parts = value
      .split(RegExp(r'[,;\n]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return false;
  return parts
      .every((part) => RegExp(r'^[A-Z][A-Z0-9_ -]{2,}$').hasMatch(part));
}
