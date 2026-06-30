import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'docupass_config.dart';
import 'docupass_error_normalizer.dart';
import 'docupass_models.dart';

class DocupassApiClient {
  DocupassApiClient(this.config, {http.Client? client})
      : _client = client ?? _createDefaultClient(config),
        _runtimeSessionId = config.sessionId;

  final DocupassApiConfig config;
  final http.Client _client;
  String? _runtimeSessionId;

  Future<DocupassSessionState> getAction() {
    return _requestSession('GET', 'get_action');
  }

  Future<DocupassSessionState> saveDocumentSelection({
    required String countryCode,
    required String documentType,
  }) {
    return _requestSession(
      'POST',
      'save_document_selection',
      <String, Object?>{
        'country': countryCode,
        'type': documentType,
      },
    );
  }

  Future<DocupassSessionState> uploadDocument({
    required String frontDocumentBase64,
    String? backDocumentBase64,
  }) {
    if (frontDocumentBase64.trim().isEmpty) {
      throw const DocupassApiError(
        message: 'Front document image is required.',
        code: 'LOCAL_VALIDATION',
      );
    }
    return _requestSession(
      'POST',
      'upload_document',
      <String, Object?>{
        'document': frontDocumentBase64,
        if (backDocumentBase64 != null && backDocumentBase64.trim().isNotEmpty)
          'documentBack': backDocumentBase64,
      },
    );
  }

  Future<DocupassSessionState> uploadFace(List<String> faceBase64List) {
    final nonEmptyFaces = faceBase64List
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (nonEmptyFaces.isEmpty) {
      throw const DocupassApiError(
        message: 'At least one face image is required.',
        code: 'LOCAL_VALIDATION',
      );
    }
    return _requestSession(
      'POST',
      'upload_face',
      <String, Object?>{'face': nonEmptyFaces.join(',')},
    );
  }

  Future<void> createPhoneVerification(String? number, String type) async {
    await _requestJson(
      'POST',
      'create_phone_verification',
      <String, Object?>{
        'type': type,
        'number': number?.trim().isEmpty == false ? number!.trim() : null,
      },
    );
  }

  Future<DocupassSessionState> checkPhoneVerification(
    String? number,
    String code,
  ) {
    return _requestSession(
      'POST',
      'check_phone_verification',
      <String, Object?>{
        'code': code.trim(),
        'number': number?.trim().isEmpty == false ? number!.trim() : null,
      },
    );
  }

  Future<DocupassSessionState> saveForm(Map<String, String> answers) {
    return _requestSession('POST', 'save_form', answers);
  }

  Future<DocupassSessionState> submitContract(
    Map<String, String> signatures,
  ) {
    return _requestSession('POST', 'submit_contract', signatures);
  }

  Future<void> logAuditData(String action, List<String> data) async {
    await _requestJson(
      'POST',
      'audit',
      <String, Object?>{
        'action': action,
        'data': data,
      },
    );
  }

  void close() {
    _client.close();
  }

  Future<DocupassSessionState> _requestSession(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final json = await _requestJson(method, path, body);
    final state = DocupassSessionState.fromMap(json, rawJson: jsonEncode(json));
    if (state.sessionId != null && state.sessionId!.trim().isNotEmpty) {
      _runtimeSessionId = state.sessionId;
    }
    return state;
  }

  Future<Map<String, Object?>> _requestJson(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final endpoint = Uri.parse(_buildUrl(path));
    final headers = _buildHeaders();
    final timeout = Duration(milliseconds: config.readTimeoutMs);

    try {
      final response = await _send(method, endpoint, headers, body).timeout(
        timeout,
      );
      final parsed = _parseJsonObject(response.body);
      if (response.statusCode < 200 ||
          response.statusCode > 299 ||
          _hasApiError(parsed)) {
        throw _apiErrorFromJson(
          parsed,
          fallbackMessage:
              response.statusCode < 200 || response.statusCode > 299
                  ? 'HTTP ${response.statusCode}'
                  : 'Docupass API returned error',
          httpStatus: response.statusCode,
          rawBody: response.body,
        );
      }
      return parsed;
    } on DocupassApiError {
      rethrow;
    } on TimeoutException catch (error) {
      throw DocupassApiError(
        message: error.message ?? 'Network timeout',
        code: 'NETWORK_ERROR',
      );
    } catch (error) {
      throw DocupassApiError(
        message: error.toString(),
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<http.Response> _send(
    String method,
    Uri endpoint,
    Map<String, String> headers,
    Map<String, Object?>? body,
  ) {
    if (method == 'GET') {
      return _client.get(endpoint, headers: headers);
    }
    return _client.post(
      endpoint,
      headers: headers,
      body: jsonEncode(body ?? const <String, Object?>{}),
    );
  }

  String _buildUrl(String path) {
    final base = _resolveBaseUrl().trim().replaceFirst(RegExp(r'/+$'), '');
    final endpoint = path.trim().replaceFirst(RegExp(r'^/+'), '');
    return '$base/$endpoint';
  }

  String _resolveBaseUrl() {
    final reference = config.reference?.trim();
    if (config.baseUrl != null && config.baseUrl!.trim().isNotEmpty) {
      return config.baseUrl!.trim();
    }
    if (reference != null && reference.isNotEmpty) {
      return resolveDocupassEndpoint(reference);
    }
    return docupassApiEndpointUs;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final auth = _resolveAuthorizationHeader();
    if (auth != null) headers['Authorization'] = auth;
    if (config.geolocation != null && config.geolocation!.trim().isNotEmpty) {
      headers['Geolocation'] = config.geolocation!.trim();
    }
    return headers;
  }

  String? _resolveAuthorizationHeader() {
    if (config.authorization != null &&
        config.authorization!.trim().isNotEmpty) {
      return config.authorization!.trim();
    }
    final session = _runtimeSessionId?.trim();
    if (session != null && session.isNotEmpty) {
      return 'DOCUPASS_SESSION $session';
    }
    final reference = config.reference?.trim();
    if (reference == null || reference.isEmpty) return null;
    final parsed = parseDocupassReference(reference, config.partyId);
    if (parsed.partyId != null && parsed.partyId!.isNotEmpty) {
      return 'DOCUPASS ${parsed.reference} ${parsed.partyId}';
    }
    return 'DOCUPASS ${parsed.reference}';
  }
}

http.Client _createDefaultClient(DocupassApiConfig config) {
  if (!config.disableSslValidation) {
    return http.Client();
  }
  final httpClient = HttpClient();
  httpClient.badCertificateCallback = (certificate, host, port) => true;
  httpClient.connectionTimeout =
      Duration(milliseconds: config.connectTimeoutMs);
  return IOClient(httpClient);
}

Map<String, Object?> _parseJsonObject(String rawBody) {
  if (rawBody.trim().isEmpty) return <String, Object?>{};
  try {
    final parsed = jsonDecode(rawBody);
    if (parsed is Map<String, Object?>) return parsed;
    if (parsed is Map) {
      return parsed.map(
        (key, value) => MapEntry('$key', value as Object?),
      );
    }
    return <String, Object?>{'raw': rawBody};
  } catch (_) {
    return <String, Object?>{'raw': rawBody};
  }
}

bool _hasApiError(Map<String, Object?> json) {
  if (json['error'] is Map) return true;
  return json.boolValue('success', true) == false;
}

DocupassApiError _apiErrorFromJson(
  Map<String, Object?> json, {
  required String fallbackMessage,
  int? httpStatus,
  String? rawBody,
}) {
  final errorObject = asStringKeyedMap(json['error']) ?? json;
  return DocupassApiError(
    message: errorObject.nullableString('message') ??
        json.nullableString('message') ??
        fallbackMessage,
    code: errorObject.nullableString('code'),
    httpStatus: httpStatus,
    rawBody: rawBody,
  );
}
