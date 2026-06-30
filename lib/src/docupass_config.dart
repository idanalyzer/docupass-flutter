const String docupassApiEndpointUs =
    'https://api2.idanalyzer.com/docupassappv3';
const String docupassApiEndpointEu =
    'https://api2-eu.idanalyzer.com/docupassappv3';

String resolveDocupassEndpoint(String? reference) {
  final ref = reference?.trim() ?? '';
  return ref.toLowerCase().startsWith('eu')
      ? docupassApiEndpointEu
      : docupassApiEndpointUs;
}

class DocupassParsedReference {
  const DocupassParsedReference({
    required this.reference,
    this.partyId,
  });

  final String reference;
  final String? partyId;
}

DocupassParsedReference parseDocupassReference(
  String value, [
  String? partyId,
]) {
  final reference = value.trim();
  final explicitPartyId = partyId?.trim();
  if (explicitPartyId != null && explicitPartyId.isNotEmpty) {
    return DocupassParsedReference(
      reference: reference,
      partyId: explicitPartyId,
    );
  }

  final separatorIndex = reference.indexOf('/');
  if (separatorIndex <= 0 || separatorIndex == reference.length - 1) {
    return DocupassParsedReference(reference: reference);
  }

  final parsedReference = reference.substring(0, separatorIndex).trim();
  final parsedPartyId = reference.substring(separatorIndex + 1).trim();
  return DocupassParsedReference(
    reference: parsedReference,
    partyId: parsedPartyId.isEmpty ? null : parsedPartyId,
  );
}

class DocupassApiConfig {
  const DocupassApiConfig({
    this.enabled = true,
    this.baseUrl,
    this.reference,
    this.partyId,
    this.sessionId,
    this.authorization,
    this.geolocation,
    this.disableSslValidation = false,
    this.connectTimeoutMs = 20000,
    this.readTimeoutMs = 20000,
  });

  factory DocupassApiConfig.fromReference(
    String reference, {
    String? partyId,
    String? geolocation,
    bool enabled = true,
  }) {
    final parsed = parseDocupassReference(reference, partyId);
    return DocupassApiConfig(
      enabled: enabled,
      baseUrl: resolveDocupassEndpoint(parsed.reference),
      reference: parsed.reference,
      partyId: parsed.partyId,
      geolocation: geolocation,
    );
  }

  final bool enabled;
  final String? baseUrl;
  final String? reference;
  final String? partyId;
  final String? sessionId;
  final String? authorization;
  final String? geolocation;
  final bool disableSslValidation;
  final int connectTimeoutMs;
  final int readTimeoutMs;

  Map<String, Object?> toCreationParams() {
    return <String, Object?>{
      'enabled': enabled,
      'baseUrl': baseUrl,
      'reference': reference,
      'partyId': partyId,
      'sessionId': sessionId,
      'authorization': authorization,
      'geolocation': geolocation,
      'disableSslValidation': disableSslValidation,
      'connectTimeoutMs': connectTimeoutMs,
      'readTimeoutMs': readTimeoutMs,
    };
  }
}

DocupassApiConfig docupassConfigFromReference(
  String reference, {
  String? partyId,
  String? geolocation,
  bool enabled = true,
}) {
  return DocupassApiConfig.fromReference(
    reference,
    partyId: partyId,
    geolocation: geolocation,
    enabled: enabled,
  );
}
