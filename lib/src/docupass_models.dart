enum DocuPassStatus { completed, failed, cancelled, unknown }

enum DocupassErrorAction {
  showCompleted,
  showFailed,
  resyncSession,
  requestLocation,
  retry,
  retakeDocument,
  retakeFace,
  editInput,
  fixSignature,
  fatal,
  contactSupport,
}

enum KYCAction {
  turnLeft('TURN HEAD LEFT'),
  turnRight('TURN HEAD RIGHT'),
  turnUp('TURN HEAD UP'),
  mouthOpen('OPEN MOUTH O-SHAPE');

  const KYCAction(this.instruction);

  final String instruction;
}

DocuPassStatus docuPassStatusFromString(String? value) {
  switch (value) {
    case 'completed':
      return DocuPassStatus.completed;
    case 'failed':
      return DocuPassStatus.failed;
    case 'cancelled':
      return DocuPassStatus.cancelled;
    default:
      return DocuPassStatus.unknown;
  }
}

class DocuPassResult {
  const DocuPassResult({
    required this.status,
    this.sessionId,
    this.reference,
    this.serverTask,
    this.country,
    this.documentType,
    this.isFaceVerified = false,
    this.sessionState,
    this.error,
    this.raw,
  });

  factory DocuPassResult.fromMap(Map<Object?, Object?> map) {
    return DocuPassResult(
      status: docuPassStatusFromString(map['status'] as String?),
      sessionId: map['sessionId'] as String?,
      reference: map['reference'] as String?,
      serverTask: map['serverTask'] as String?,
      country: DocupassCountry.fromObject(map['country']),
      documentType: DocupassDocumentType.fromObject(map['documentType']),
      isFaceVerified: map['isFaceVerified'] as bool? ?? false,
      sessionState: asStringKeyedMap(map['sessionState']),
      error: DocupassNormalizedError.fromObject(map['error']),
      raw: asStringKeyedMap(map['raw']),
    );
  }

  final DocuPassStatus status;
  final String? sessionId;
  final String? reference;
  final String? serverTask;
  final DocupassCountry? country;
  final DocupassDocumentType? documentType;
  final bool isFaceVerified;
  final Map<String, Object?>? sessionState;
  final DocupassNormalizedError? error;
  final Map<String, Object?>? raw;

  bool get isCompleted => status == DocuPassStatus.completed;
  bool get isFailed => status == DocuPassStatus.failed;
  bool get isCancelled => status == DocuPassStatus.cancelled;
}

class DocupassCountry {
  const DocupassCountry({
    required this.code,
    required this.name,
    this.flag = '',
  });

  factory DocupassCountry.fromMap(Map<String, Object?> map) {
    return DocupassCountry(
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      flag: map['flag'] as String? ?? '',
    );
  }

  static DocupassCountry? fromObject(Object? value) {
    final map = asStringKeyedMap(value);
    return map == null ? null : DocupassCountry.fromMap(map);
  }

  final String code;
  final String name;
  final String flag;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code,
      'name': name,
      'flag': flag,
    };
  }
}

class DocupassDocumentType {
  const DocupassDocumentType({
    required this.label,
    required this.apiTypeCode,
    required this.requiresBackSide,
  });

  factory DocupassDocumentType.fromMap(Map<String, Object?> map) {
    return DocupassDocumentType(
      label: map['label'] as String? ?? '',
      apiTypeCode: map['apiTypeCode'] as String? ?? '',
      requiresBackSide: map['requiresBackSide'] as bool? ?? false,
    );
  }

  static DocupassDocumentType? fromObject(Object? value) {
    final map = asStringKeyedMap(value);
    return map == null ? null : DocupassDocumentType.fromMap(map);
  }

  final String label;
  final String apiTypeCode;
  final bool requiresBackSide;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'label': label,
      'apiTypeCode': apiTypeCode,
      'requiresBackSide': requiresBackSide,
    };
  }
}

class DocupassCustomField {
  const DocupassCustomField({
    required this.fieldId,
    required this.fieldLabel,
    required this.fieldDescription,
    required this.fieldType,
    required this.fieldData,
  });

  factory DocupassCustomField.fromMap(Map<String, Object?> map) {
    return DocupassCustomField(
      fieldId: map.stringValue('fieldId'),
      fieldLabel: map.stringValue('fieldLabel'),
      fieldDescription: map.stringValue('fieldDescription'),
      fieldType: map.intValue('fieldType'),
      fieldData: map.stringValue('fieldData'),
    );
  }

  final String fieldId;
  final String fieldLabel;
  final String fieldDescription;
  final int fieldType;
  final String fieldData;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'fieldId': fieldId,
      'fieldLabel': fieldLabel,
      'fieldDescription': fieldDescription,
      'fieldType': fieldType,
      'fieldData': fieldData,
    };
  }
}

class DocupassPhoneCountryCode {
  const DocupassPhoneCountryCode({
    required this.name,
    required this.dialCode,
    required this.code,
  });

  factory DocupassPhoneCountryCode.fromMap(Map<String, Object?> map) {
    return DocupassPhoneCountryCode(
      name: map.stringValue('name'),
      dialCode: map.stringValue('dial_code').isNotEmpty
          ? map.stringValue('dial_code')
          : map.stringValue('dialCode'),
      code: map.stringValue('code'),
    );
  }

  final String name;
  final String dialCode;
  final String code;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'dialCode': dialCode,
      'code': code,
    };
  }
}

class DocupassSessionState {
  const DocupassSessionState({
    required this.success,
    this.sessionId,
    this.task,
    this.reference,
    this.acceptedDocumentCountry,
    this.acceptedDocumentType,
    this.selectedDocumentCountry,
    this.selectedDocumentType,
    required this.allowFileUpload,
    required this.documentSide,
    required this.gps,
    required this.reviewData,
    this.logoUrl,
    this.companyName,
    this.welcomeMessage,
    this.language,
    this.userPhone,
    required this.hasFaceFile,
    required this.hasDocumentFile,
    this.verifyDocumentNo,
    this.verifyName,
    this.verifyDob,
    this.verifyAge,
    this.verifyAddress,
    this.verifyPostcode,
    required this.preloadFaceLib,
    this.contractSource,
    this.customFields = const <DocupassCustomField>[],
    this.phoneCountryCodes = const <DocupassPhoneCountryCode>[],
    this.rawJson = '',
  });

  factory DocupassSessionState.fromMap(
    Map<String, Object?> map, {
    String rawJson = '',
  }) {
    return DocupassSessionState(
      success: map.boolValue('success'),
      sessionId: map.nullableString('sessionId'),
      task: map.nullableString('task'),
      reference: map.nullableString('reference'),
      acceptedDocumentCountry: map.nullableString('acceptedDocumentCountry'),
      acceptedDocumentType: map.nullableString('acceptedDocumentType'),
      selectedDocumentCountry: map.nullableString('selectedDocumentCountry'),
      selectedDocumentType: map.nullableString('selectedDocumentType'),
      allowFileUpload: map.boolValue('allowFileUpload'),
      documentSide: map.intValue('documentSide'),
      gps: map.boolValue('gps'),
      reviewData: map.boolValue('reviewData'),
      logoUrl: map.nullableString('logoURL') ?? map.nullableString('logoUrl'),
      companyName: map.nullableString('companyName'),
      welcomeMessage: map.nullableString('welcomeMessage'),
      language: map.nullableString('language'),
      userPhone: map.nullableString('userPhone'),
      hasFaceFile: map.boolValue('hasFaceFile'),
      hasDocumentFile: map.boolValue('hasDocumentFile'),
      verifyDocumentNo: map.nullableString('verifyDocumentNo'),
      verifyName: map.nullableString('verifyName'),
      verifyDob: map.nullableString('verifyDob'),
      verifyAge: map.nullableString('verifyAge'),
      verifyAddress: map.nullableString('verifyAddress'),
      verifyPostcode: map.nullableString('verifyPostcode'),
      preloadFaceLib: map.boolValue('preloadFaceLib'),
      contractSource: map.nullableString('contractSource'),
      customFields: map
          .objectList('customField')
          .map(
            DocupassCustomField.fromMap,
          )
          .toList(growable: false),
      phoneCountryCodes: map
          .objectList('phoneCountryCode')
          .map(DocupassPhoneCountryCode.fromMap)
          .where((value) => value.dialCode.isNotEmpty)
          .toList(growable: false),
      rawJson: rawJson,
    );
  }

  final bool success;
  final String? sessionId;
  final String? task;
  final String? reference;
  final String? acceptedDocumentCountry;
  final String? acceptedDocumentType;
  final String? selectedDocumentCountry;
  final String? selectedDocumentType;
  final bool allowFileUpload;
  final int documentSide;
  final bool gps;
  final bool reviewData;
  final String? logoUrl;
  final String? companyName;
  final String? welcomeMessage;
  final String? language;
  final String? userPhone;
  final bool hasFaceFile;
  final bool hasDocumentFile;
  final String? verifyDocumentNo;
  final String? verifyName;
  final String? verifyDob;
  final String? verifyAge;
  final String? verifyAddress;
  final String? verifyPostcode;
  final bool preloadFaceLib;
  final String? contractSource;
  final List<DocupassCustomField> customFields;
  final List<DocupassPhoneCountryCode> phoneCountryCodes;
  final String rawJson;

  List<String> acceptedDocumentCountryCodes() {
    return acceptedDocumentCountry.commaSeparatedValues();
  }

  List<String> acceptedDocumentTypeCodes() {
    return acceptedDocumentType.commaSeparatedValues();
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'success': success,
      'sessionId': sessionId,
      'task': task,
      'reference': reference,
      'acceptedDocumentCountry': acceptedDocumentCountry,
      'acceptedDocumentType': acceptedDocumentType,
      'selectedDocumentCountry': selectedDocumentCountry,
      'selectedDocumentType': selectedDocumentType,
      'allowFileUpload': allowFileUpload,
      'documentSide': documentSide,
      'gps': gps,
      'reviewData': reviewData,
      'logoUrl': logoUrl,
      'companyName': companyName,
      'welcomeMessage': welcomeMessage,
      'language': language,
      'userPhone': userPhone,
      'hasFaceFile': hasFaceFile,
      'hasDocumentFile': hasDocumentFile,
      'verifyDocumentNo': verifyDocumentNo,
      'verifyName': verifyName,
      'verifyDob': verifyDob,
      'verifyAge': verifyAge,
      'verifyAddress': verifyAddress,
      'verifyPostcode': verifyPostcode,
      'preloadFaceLib': preloadFaceLib,
      'contractSource': contractSource,
      'customFields': customFields.map((value) => value.toMap()).toList(),
      'phoneCountryCodes':
          phoneCountryCodes.map((value) => value.toMap()).toList(),
      'rawJson': rawJson,
    };
  }
}

class DocupassNormalizedError {
  const DocupassNormalizedError({
    this.code,
    this.subCode,
    required this.title,
    required this.detail,
    required this.suggestion,
    required this.action,
    this.warningCodes = const <String>[],
    this.httpStatus,
    this.rawMessage,
    this.rawBody,
  });

  factory DocupassNormalizedError.fromMap(Map<String, Object?> map) {
    return DocupassNormalizedError(
      code: map['code'] as String?,
      subCode: map['subCode'] as String?,
      title: map['title'] as String? ?? 'DocuPass error',
      detail: map['detail'] as String? ?? '',
      suggestion: map['suggestion'] as String? ?? '',
      action: docupassErrorActionFromName(map['action'] as String?),
      warningCodes: (map['warningCodes'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      httpStatus: map['httpStatus'] as int?,
      rawMessage: map['rawMessage'] as String?,
      rawBody: map['rawBody'] as String?,
    );
  }

  static DocupassNormalizedError? fromObject(Object? value) {
    final map = asStringKeyedMap(value);
    return map == null ? null : DocupassNormalizedError.fromMap(map);
  }

  final String? code;
  final String? subCode;
  final String title;
  final String detail;
  final String suggestion;
  final DocupassErrorAction action;
  final List<String> warningCodes;
  final int? httpStatus;
  final String? rawMessage;
  final String? rawBody;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code,
      'subCode': subCode,
      'title': title,
      'detail': detail,
      'suggestion': suggestion,
      'action': action.name,
      'warningCodes': warningCodes,
      'httpStatus': httpStatus,
      'rawMessage': rawMessage,
      'rawBody': rawBody,
    };
  }

  String toDisplayMessage({bool includeCode = true}) {
    final parts = <String>[
      title,
      detail,
      suggestion,
    ].where((value) => value.trim().isNotEmpty).toList();
    if (warningCodes.isNotEmpty) {
      parts.add('Warnings: ${warningCodes.join(', ')}');
    }
    if (includeCode) {
      final codes = <String>[
        if (code != null && code!.isNotEmpty) code!,
        if (subCode != null && subCode!.isNotEmpty) subCode!,
      ];
      if (codes.isNotEmpty) {
        parts.add('Code: ${codes.join(' / ')}');
      }
    }
    return parts.join('\n');
  }
}

DocupassErrorAction docupassErrorActionFromName(String? value) {
  switch (value) {
    case 'SHOW_COMPLETED':
    case 'showCompleted':
      return DocupassErrorAction.showCompleted;
    case 'SHOW_FAILED':
    case 'showFailed':
      return DocupassErrorAction.showFailed;
    case 'RESYNC_SESSION':
    case 'resyncSession':
      return DocupassErrorAction.resyncSession;
    case 'REQUEST_LOCATION':
    case 'requestLocation':
      return DocupassErrorAction.requestLocation;
    case 'RETAKE_DOCUMENT':
    case 'retakeDocument':
      return DocupassErrorAction.retakeDocument;
    case 'RETAKE_FACE':
    case 'retakeFace':
      return DocupassErrorAction.retakeFace;
    case 'EDIT_INPUT':
    case 'editInput':
      return DocupassErrorAction.editInput;
    case 'FIX_SIGNATURE':
    case 'fixSignature':
      return DocupassErrorAction.fixSignature;
    case 'FATAL':
    case 'fatal':
      return DocupassErrorAction.fatal;
    case 'CONTACT_SUPPORT':
    case 'contactSupport':
      return DocupassErrorAction.contactSupport;
    default:
      return DocupassErrorAction.retry;
  }
}

class KYCResult {
  const KYCResult({
    this.country,
    this.documentType,
    this.documentFrontBase64,
    this.documentBackBase64,
    this.faceBase64List = const <String>[],
    this.isFaceVerified = false,
    this.serverTask,
    this.sessionId,
    this.sessionState,
    this.terminalError,
  });

  final DocupassCountry? country;
  final DocupassDocumentType? documentType;
  final String? documentFrontBase64;
  final String? documentBackBase64;
  final List<String> faceBase64List;
  final bool isFaceVerified;
  final String? serverTask;
  final String? sessionId;
  final DocupassSessionState? sessionState;
  final DocupassNormalizedError? terminalError;

  KYCResult copyWith({
    DocupassCountry? country,
    bool clearCountry = false,
    DocupassDocumentType? documentType,
    bool clearDocumentType = false,
    String? documentFrontBase64,
    String? documentBackBase64,
    List<String>? faceBase64List,
    bool? isFaceVerified,
    String? serverTask,
    String? sessionId,
    DocupassSessionState? sessionState,
    DocupassNormalizedError? terminalError,
    bool clearTerminalError = false,
  }) {
    return KYCResult(
      country: clearCountry ? null : country ?? this.country,
      documentType:
          clearDocumentType ? null : documentType ?? this.documentType,
      documentFrontBase64: documentFrontBase64 ?? this.documentFrontBase64,
      documentBackBase64: documentBackBase64 ?? this.documentBackBase64,
      faceBase64List: faceBase64List ?? this.faceBase64List,
      isFaceVerified: isFaceVerified ?? this.isFaceVerified,
      serverTask: serverTask ?? this.serverTask,
      sessionId: sessionId ?? this.sessionId,
      sessionState: sessionState ?? this.sessionState,
      terminalError:
          clearTerminalError ? null : terminalError ?? this.terminalError,
    );
  }

  DocuPassResult toPublicResult(DocuPassStatus status) {
    final finalStatus = switch (terminalError?.action) {
      DocupassErrorAction.showCompleted => DocuPassStatus.completed,
      DocupassErrorAction.showFailed => DocuPassStatus.failed,
      _ => status,
    };
    return DocuPassResult(
      status: finalStatus,
      sessionId: sessionId,
      reference: sessionState?.reference,
      serverTask: serverTask,
      country: country,
      documentType: documentType,
      isFaceVerified: isFaceVerified,
      sessionState: sessionState?.toMap(),
      error: terminalError,
      raw: <String, Object?>{
        'documentFrontBase64': documentFrontBase64,
        'documentBackBase64': documentBackBase64,
        'faceBase64List': faceBase64List,
      },
    );
  }
}

class DocupassContractSignatureField {
  const DocupassContractSignatureField({
    required this.uid,
    required this.label,
    this.party,
  });

  final String uid;
  final String label;
  final String? party;
}

const DocupassDocumentType passportDocumentType = DocupassDocumentType(
  label: 'Passport',
  apiTypeCode: 'P',
  requiresBackSide: false,
);

const DocupassDocumentType driverLicenseDocumentType = DocupassDocumentType(
  label: 'Driver License',
  apiTypeCode: 'D',
  requiresBackSide: true,
);

const DocupassDocumentType identityCardDocumentType = DocupassDocumentType(
  label: 'Identity Card',
  apiTypeCode: 'I',
  requiresBackSide: true,
);

const List<DocupassDocumentType> allDocumentTypes = <DocupassDocumentType>[
  passportDocumentType,
  driverLicenseDocumentType,
  identityCardDocumentType,
];

const List<DocupassCountry> allCountries = <DocupassCountry>[
  DocupassCountry(code: 'AU', name: 'Australia'),
  DocupassCountry(code: 'CA', name: 'Canada'),
  DocupassCountry(code: 'FR', name: 'France'),
  DocupassCountry(code: 'DE', name: 'Germany'),
  DocupassCountry(code: 'HK', name: 'Hong Kong'),
  DocupassCountry(code: 'JP', name: 'Japan'),
  DocupassCountry(code: 'KR', name: 'South Korea'),
  DocupassCountry(code: 'SG', name: 'Singapore'),
  DocupassCountry(code: 'TW', name: 'Taiwan'),
  DocupassCountry(code: 'TH', name: 'Thailand'),
  DocupassCountry(code: 'GB', name: 'United Kingdom'),
  DocupassCountry(code: 'US', name: 'United States'),
];

DocupassCountry countryFromCode(String code) {
  final normalized = code.trim().toUpperCase();
  return allCountries.firstWhere(
    (country) => country.code.toUpperCase() == normalized,
    orElse: () => DocupassCountry(code: normalized, name: normalized),
  );
}

DocupassDocumentType? documentTypeFromCode(String code) {
  final normalized = code.trim().toUpperCase();
  for (final type in allDocumentTypes) {
    if (type.apiTypeCode.toUpperCase() == normalized) {
      return type;
    }
  }
  return null;
}

List<DocupassCountry> countriesForFilter(List<String>? filterCodes) {
  if (filterCodes == null || filterCodes.isEmpty) {
    return allCountries;
  }
  final known = <String, DocupassCountry>{
    for (final country in allCountries) country.code.toUpperCase(): country,
  };
  final seen = <String>{};
  final countries = <DocupassCountry>[];
  for (final rawCode in filterCodes) {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty || !seen.add(code)) continue;
    countries.add(known[code] ?? DocupassCountry(code: code, name: code));
  }
  countries.sort((a, b) => a.name.compareTo(b.name));
  return countries;
}

List<DocupassDocumentType> documentTypesForFilter(List<String>? acceptedTypes) {
  final accepted = acceptedTypes
      ?.map((value) => value.trim().toUpperCase())
      .where((value) => value.isNotEmpty)
      .toSet();
  if (accepted == null || accepted.isEmpty) {
    return allDocumentTypes;
  }
  return allDocumentTypes
      .where((type) => accepted.contains(type.apiTypeCode.toUpperCase()))
      .toList(growable: false);
}

List<KYCAction> randomizedFaceActions(
  List<KYCAction> actions, {
  int minCount = 2,
}) {
  final unique = actions.toSet().toList();
  final candidates = unique.isEmpty ? KYCAction.values.toList() : unique;
  final desired = minCount.clamp(1, KYCAction.values.length);
  candidates.shuffle();
  if (candidates.length < desired) {
    final rest = KYCAction.values
        .where((action) => !candidates.contains(action))
        .toList()
      ..shuffle();
    candidates.addAll(rest);
  }
  return candidates.take(desired).toList(growable: false);
}

List<String> _commaSeparatedValues(String? value) {
  return value
          ?.split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false) ??
      const <String>[];
}

extension NullableDocupassStringHelpers on String? {
  List<String> commaSeparatedValues() => _commaSeparatedValues(this);
}

Map<String, Object?>? asStringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map<Object?, Object?>) {
    return value.map(
      (Object? key, Object? mapValue) => MapEntry('$key', mapValue),
    );
  }
  if (value is Map) {
    return value.map(
      (key, mapValue) => MapEntry('$key', mapValue as Object?),
    );
  }
  return null;
}

extension DocupassMapRead on Map<String, Object?> {
  String? nullableString(String key) {
    final value = this[key];
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  String stringValue(String key) => nullableString(key) ?? '';

  bool boolValue(String key, [bool defaultValue = false]) {
    final value = this[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }
    return defaultValue;
  }

  int intValue(String key, [int defaultValue = 0]) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? defaultValue;
    return defaultValue;
  }

  List<Map<String, Object?>> objectList(String key) {
    final value = this[key];
    if (value is! List) return const <Map<String, Object?>>[];
    return value
        .map(asStringKeyedMap)
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
  }
}
