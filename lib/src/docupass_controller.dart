import 'dart:async';

import 'package:flutter/foundation.dart';

import 'docupass_api_client.dart';
import 'docupass_config.dart';
import 'docupass_error_normalizer.dart';
import 'docupass_models.dart';

sealed class DocupassKycEvent {
  const DocupassKycEvent();
}

class DocupassKycLoading extends DocupassKycEvent {
  const DocupassKycLoading();
}

class DocupassKycPhoneVerification extends DocupassKycEvent {
  const DocupassKycPhoneVerification({
    required this.state,
    required this.codeSent,
    this.currentNumber,
  });

  final DocupassSessionState state;
  final bool codeSent;
  final String? currentNumber;
}

class DocupassKycCustomForm extends DocupassKycEvent {
  const DocupassKycCustomForm(this.fields);

  final List<DocupassCustomField> fields;
}

class DocupassKycDocumentCountrySelection extends DocupassKycEvent {
  const DocupassKycDocumentCountrySelection({
    this.filterCodes,
    this.selectedCountry,
  });

  final List<String>? filterCodes;
  final DocupassCountry? selectedCountry;
}

class DocupassKycDocumentSelection extends DocupassKycEvent {
  const DocupassKycDocumentSelection({
    required this.country,
    required this.documentTypes,
    this.selectedDocumentType,
  });

  final DocupassCountry country;
  final List<DocupassDocumentType> documentTypes;
  final DocupassDocumentType? selectedDocumentType;
}

class DocupassKycDocumentCapture extends DocupassKycEvent {
  const DocupassKycDocumentCapture({
    this.country,
    this.documentType,
    this.documentSide,
    required this.allowFileUpload,
  });

  final DocupassCountry? country;
  final DocupassDocumentType? documentType;
  final int? documentSide;
  final bool allowFileUpload;
}

class DocupassKycFaceVerification extends DocupassKycEvent {
  const DocupassKycFaceVerification(this.actions);

  final List<KYCAction> actions;
}

class DocupassKycContract extends DocupassKycEvent {
  const DocupassKycContract({
    required this.state,
    required this.html,
    required this.signatureFields,
  });

  final DocupassSessionState state;
  final String html;
  final List<DocupassContractSignatureField> signatureFields;
}

class DocupassKycPartyPending extends DocupassKycEvent {
  const DocupassKycPartyPending();
}

class DocupassKycCompleted extends DocupassKycEvent {
  const DocupassKycCompleted(this.result);

  final KYCResult result;
}

class DocupassKycFailed extends DocupassKycEvent {
  const DocupassKycFailed(this.result, this.error);

  final KYCResult result;
  final DocupassNormalizedError? error;
}

class DocupassKycErrorEvent {
  const DocupassKycErrorEvent({
    required this.message,
    this.normalized,
  });

  final String message;
  final DocupassNormalizedError? normalized;
}

class DocupassKycUiState {
  const DocupassKycUiState({
    this.event = const DocupassKycLoading(),
    this.result = const KYCResult(),
    this.isBusy = false,
    this.canGoBack = false,
    this.error,
  });

  final DocupassKycEvent event;
  final KYCResult result;
  final bool isBusy;
  final bool canGoBack;
  final DocupassKycErrorEvent? error;

  DocupassKycUiState copyWith({
    DocupassKycEvent? event,
    KYCResult? result,
    bool? isBusy,
    bool? canGoBack,
    DocupassKycErrorEvent? error,
    bool clearError = false,
  }) {
    return DocupassKycUiState(
      event: event ?? this.event,
      result: result ?? this.result,
      isBusy: isBusy ?? this.isBusy,
      canGoBack: canGoBack ?? this.canGoBack,
      error: clearError ? null : error ?? this.error,
    );
  }
}

enum _LocalKycStep {
  selectCountry,
  selectDocument,
  captureDocument,
  faceVerification,
  success,
}

class DocupassKycController extends ChangeNotifier {
  DocupassKycController({
    required this.config,
  }) : _apiClient = DocupassApiClient(config);

  final DocupassApiConfig config;
  final DocupassApiClient _apiClient;
  final List<KYCAction> _faceActionCandidates = KYCAction.values.toList();

  DocupassKycUiState _state = const DocupassKycUiState();
  KYCResult _result = const KYCResult();
  int _currentLocalStepIdx = 0;
  bool _phoneCodeSent = false;
  String? _currentPhoneNumber;
  bool _closed = false;

  final List<DocupassKycEvent> _eventBackStack = <DocupassKycEvent>[];
  final List<_LocalKycStep> _localWorkflow = const <_LocalKycStep>[
    _LocalKycStep.selectCountry,
    _LocalKycStep.selectDocument,
    _LocalKycStep.captureDocument,
    _LocalKycStep.faceVerification,
  ];

  DocupassKycUiState get state => _state;

  Future<void> start() async {
    _setState(
      _state.copyWith(
        event: const DocupassKycLoading(),
        isBusy: config.enabled,
        clearError: true,
      ),
    );
    if (!config.enabled) {
      _publishLocalStep();
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!config.enabled) {
      _publishLocalStep();
      return;
    }
    _setBusy(true);
    try {
      final session = await _apiClient.getAction();
      _applySessionState(session);
    } on DocupassApiError catch (error) {
      await _handleApiError(error);
    } finally {
      _setBusy(false);
    }
  }

  void clearError() {
    _setState(_state.copyWith(clearError: true));
  }

  Future<void> restart() async {
    _resetLocalState();
    await start();
  }

  void back() {
    if (_state.isBusy || _eventBackStack.isEmpty) return;
    final previous = _eventBackStack.removeLast();
    _setState(
      _state.copyWith(
        event: previous,
        canGoBack: _eventBackStack.isNotEmpty,
        clearError: true,
      ),
    );
  }

  Future<void> sendPhoneCode(String? number, String type) async {
    _setBusy(true);
    clearError();
    try {
      await _apiClient.createPhoneVerification(number, type);
      _phoneCodeSent = true;
      _currentPhoneNumber = number;
      _republishPhoneEvent();
    } on DocupassApiError catch (error) {
      await _handleApiError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> verifyPhoneCode(String? number, String code) async {
    _setBusy(true);
    clearError();
    try {
      final session = await _apiClient.checkPhoneVerification(number, code);
      _applySessionState(session);
    } on DocupassApiError catch (error) {
      await _handleApiError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> saveCustomForm(Map<String, String> answers) async {
    _setBusy(true);
    clearError();
    try {
      final session = await _apiClient.saveForm(answers);
      _applySessionState(session);
    } on DocupassApiError catch (error) {
      await _handleApiError(error);
    } finally {
      _setBusy(false);
    }
  }

  void selectDocumentCountry(DocupassCountry country) {
    _result = _result.copyWith(country: country);
    final documentTypes = documentTypesForFilter(
      _result.sessionState?.acceptedDocumentTypeCodes(),
    );
    _setState(
      _state.copyWith(
        event: DocupassKycDocumentSelection(
          country: country,
          documentTypes: documentTypes,
          selectedDocumentType: _result.documentType,
        ),
        result: _result,
        clearError: true,
      ),
      recordHistory: true,
    );
  }

  Future<void> selectDocumentType(String documentTypeCode) async {
    final country = _result.country;
    if (country == null) {
      _showLocalError('Please select country first.');
      return;
    }
    final documentType = documentTypeFromCode(documentTypeCode);
    if (documentType == null) {
      _showLocalError('Unsupported document type.');
      return;
    }

    _result = _result.copyWith(documentType: documentType);
    _setState(_state.copyWith(result: _result, clearError: true));

    if (!config.enabled) {
      _publishEventForStep(_LocalKycStep.captureDocument);
      return;
    }

    _setBusy(true);
    try {
      final session = await _apiClient.saveDocumentSelection(
        countryCode: country.code,
        documentType: documentType.apiTypeCode,
      );
      _applySessionState(session);
    } on DocupassApiError catch (error) {
      await _handleApiError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> uploadDocument(String frontBase64, String? backBase64) async {
    _result = _result.copyWith(
      documentFrontBase64: frontBase64,
      documentBackBase64: backBase64,
    );

    if (!config.enabled) {
      _currentLocalStepIdx = _nextLocalWorkflowIndexAfter(
        _LocalKycStep.captureDocument,
      );
      _publishLocalStep();
      return;
    }

    _setBusy(true);
    clearError();
    try {
      final session = await _apiClient.uploadDocument(
        frontDocumentBase64: frontBase64,
        backDocumentBase64: backBase64,
      );
      _applySessionState(session);
    } on DocupassApiError catch (error) {
      await _handleApiError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> uploadFace(List<String> faceBase64List) async {
    _result = _result.copyWith(
      faceBase64List: faceBase64List,
      isFaceVerified: true,
    );

    if (!config.enabled) {
      _currentLocalStepIdx = _nextLocalWorkflowIndexAfter(
        _LocalKycStep.faceVerification,
      );
      _publishLocalStep();
      return;
    }

    _setBusy(true);
    clearError();
    try {
      final session = await _apiClient.uploadFace(faceBase64List);
      _applySessionState(session);
    } on DocupassApiError catch (error) {
      await _handleApiError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> submitContract(Map<String, String> signatures) async {
    _setBusy(true);
    clearError();
    try {
      final session = await _apiClient.submitContract(signatures);
      _applySessionState(session);
    } on DocupassApiError catch (error) {
      await _handleApiError(error);
    } finally {
      _setBusy(false);
    }
  }

  @override
  void dispose() {
    _closed = true;
    _apiClient.close();
    super.dispose();
  }

  void _applySessionState(DocupassSessionState session) {
    final selectedCountry = session.selectedDocumentCountry == null
        ? null
        : countryFromCode(session.selectedDocumentCountry!);
    final selectedDocumentType = session.selectedDocumentType == null
        ? null
        : documentTypeFromCode(session.selectedDocumentType!);
    _result = _result.copyWith(
      country: selectedCountry,
      documentType: selectedDocumentType,
      serverTask: session.task,
      sessionId: session.sessionId,
      sessionState: session,
      clearTerminalError: true,
    );
    _phoneCodeSent = false;
    _currentPhoneNumber = null;
    _setState(
      _state.copyWith(
        event: _eventForSessionState(session),
        result: _result,
        clearError: true,
      ),
      recordHistory: true,
    );
  }

  Future<void> _handleApiError(DocupassApiError error) async {
    final normalized = normalizeDocupassError(error);
    _result = _result.copyWith(terminalError: normalized);
    switch (normalized.action) {
      case DocupassErrorAction.showCompleted:
        _setState(
          _state.copyWith(
            event: DocupassKycCompleted(_result),
            result: _result,
            clearError: true,
          ),
          recordHistory: true,
        );
      case DocupassErrorAction.showFailed:
        _setState(
          _state.copyWith(
            event: DocupassKycFailed(_result, normalized),
            result: _result,
            clearError: true,
          ),
          recordHistory: true,
        );
      case DocupassErrorAction.resyncSession:
        await refresh();
      default:
        _setState(
          _state.copyWith(
            result: _result,
            error: DocupassKycErrorEvent(
              message: formatApiErrorMessage(error),
              normalized: normalized,
            ),
          ),
        );
    }
  }

  DocupassKycEvent _eventForSessionState(DocupassSessionState session) {
    switch (session.task?.trim().toLowerCase()) {
      case 'phone':
        return DocupassKycPhoneVerification(
          state: session,
          codeSent: _phoneCodeSent,
          currentNumber: _currentPhoneNumber,
        );
      case 'customform':
        return DocupassKycCustomForm(session.customFields);
      case 'document':
        return _eventForDocumentSession(session);
      case 'face':
        return DocupassKycFaceVerification(
          randomizedFaceActions(_faceActionCandidates),
        );
      case 'contract':
        return DocupassKycContract(
          state: session,
          html: session.contractSource ?? '',
          signatureFields: extractContractSignatureFields(
            session.contractSource ?? '',
          ),
        );
      case 'party_pending':
        return const DocupassKycPartyPending();
      default:
        return DocupassKycCompleted(_result);
    }
  }

  DocupassKycEvent _eventForDocumentSession(DocupassSessionState session) {
    final selectedCountry =
        session.selectedDocumentCountry ?? _result.country?.code;
    final selectedType =
        session.selectedDocumentType ?? _result.documentType?.apiTypeCode;
    if (selectedCountry == null || selectedCountry.trim().isEmpty) {
      final filters = session.acceptedDocumentCountryCodes();
      return DocupassKycDocumentCountrySelection(
        filterCodes: filters.isEmpty ? null : filters,
        selectedCountry: _result.country,
      );
    }
    if (selectedType == null || selectedType.trim().isEmpty) {
      final country = countryFromCode(selectedCountry);
      _result = _result.copyWith(country: country);
      return DocupassKycDocumentSelection(
        country: country,
        documentTypes: documentTypesForFilter(
          session.acceptedDocumentTypeCodes(),
        ),
        selectedDocumentType: _result.documentType,
      );
    }
    return DocupassKycDocumentCapture(
      country: _result.country,
      documentType: _result.documentType,
      documentSide: session.documentSide,
      allowFileUpload: session.allowFileUpload,
    );
  }

  void _publishLocalStep() {
    final step = _localWorkflow.elementAtOrNull(_currentLocalStepIdx) ??
        _LocalKycStep.success;
    _publishEventForStep(step);
  }

  void _publishEventForStep(_LocalKycStep step) {
    final event = switch (step) {
      _LocalKycStep.selectCountry => DocupassKycDocumentCountrySelection(
          selectedCountry: _result.country,
        ),
      _LocalKycStep.selectDocument => _result.country == null
          ? DocupassKycDocumentCountrySelection(
              selectedCountry: null,
            )
          : DocupassKycDocumentSelection(
              country: _result.country!,
              documentTypes: documentTypesForFilter(null),
              selectedDocumentType: _result.documentType,
            ),
      _LocalKycStep.captureDocument => DocupassKycDocumentCapture(
          country: _result.country,
          documentType: _result.documentType,
          documentSide: null,
          allowFileUpload: false,
        ),
      _LocalKycStep.faceVerification => DocupassKycFaceVerification(
          randomizedFaceActions(_faceActionCandidates),
        ),
      _LocalKycStep.success => DocupassKycCompleted(_result),
    };
    _setState(
      _state.copyWith(
        event: event,
        result: _result,
        isBusy: false,
        clearError: true,
      ),
      recordHistory: true,
    );
  }

  void _republishPhoneEvent() {
    final current = _state.event;
    if (current is DocupassKycPhoneVerification) {
      _setState(
        _state.copyWith(
          event: DocupassKycPhoneVerification(
            state: current.state,
            codeSent: _phoneCodeSent,
            currentNumber: _currentPhoneNumber,
          ),
          result: _result,
          clearError: true,
        ),
      );
    }
  }

  int _nextLocalWorkflowIndexAfter(_LocalKycStep step) {
    final current = _localWorkflow.indexOf(step);
    final source = current >= 0 ? current : _currentLocalStepIdx;
    return (source + 1).clamp(0, _localWorkflow.length);
  }

  void _resetLocalState() {
    _currentLocalStepIdx = 0;
    _result = const KYCResult();
    _phoneCodeSent = false;
    _currentPhoneNumber = null;
    _eventBackStack.clear();
    _state = const DocupassKycUiState();
    notifyListeners();
  }

  void _setBusy(bool isBusy) {
    _setState(_state.copyWith(isBusy: isBusy));
  }

  void _showLocalError(String message) {
    _setState(
      _state.copyWith(
        error: DocupassKycErrorEvent(message: message),
      ),
    );
  }

  void _setState(DocupassKycUiState next, {bool recordHistory = false}) {
    if (_closed) return;
    if (recordHistory) {
      final currentEvent = _state.event;
      if (currentEvent is! DocupassKycLoading &&
          currentEvent.runtimeType != next.event.runtimeType) {
        _eventBackStack.add(currentEvent);
      }
    }
    _state = next.copyWith(canGoBack: _eventBackStack.isNotEmpty);
    notifyListeners();
  }
}

extension _NullableElementAt<T> on List<T> {
  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}

List<DocupassContractSignatureField> extractContractSignatureFields(
  String contractSource,
) {
  final tagRegex = RegExp(
    r'''<(?:img|div)\b[^>]*data-signature[^>]*>''',
    caseSensitive: false,
  );
  final fields = <DocupassContractSignatureField>[];
  final seen = <String>{};
  for (final match in tagRegex.allMatches(contractSource)) {
    final tag = match.group(0) ?? '';
    final uid = _htmlAttribute(tag, 'data-uid');
    if (uid == null || uid.trim().isEmpty || !seen.add(uid)) continue;
    fields.add(
      DocupassContractSignatureField(
        uid: uid,
        label: _htmlAttribute(tag, 'data-label')?.trim().isNotEmpty == true
            ? _htmlAttribute(tag, 'data-label')!
            : 'Signature',
        party: _htmlAttribute(tag, 'data-party'),
      ),
    );
  }
  return fields;
}

String? _htmlAttribute(String tag, String name) {
  final regex = RegExp(
    '''\\b${RegExp.escape(name)}\\s*=\\s*["']([^"']*)["']''',
    caseSensitive: false,
  );
  final value = regex.firstMatch(tag)?.group(1);
  return value
      ?.replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
