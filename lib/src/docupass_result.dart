/// Status of a finished DocuPass verification.
enum DocuPassStatus { completed, failed, cancelled, error }

/// Outcome of a DocuPass verification. The verification *data* lives server-side —
/// fetch it with `GET /docupass/{reference}` using your API key.
class DocuPassResult {
  final DocuPassStatus status;
  final String reference;

  /// Terminal/error code (e.g. DOCUPASS_COMPLETED, DOCUPASS_FAILED).
  final String? code;
  final String? message;

  /// Server-configured redirect URL, when present.
  final String? redirectUrl;

  const DocuPassResult({
    required this.status,
    required this.reference,
    this.code,
    this.message,
    this.redirectUrl,
  });

  factory DocuPassResult.fromMap(Map<dynamic, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'error';
    return DocuPassResult(
      status: DocuPassStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => DocuPassStatus.error,
      ),
      reference: map['reference'] as String? ?? '',
      code: map['code'] as String?,
      message: map['message'] as String?,
      redirectUrl: map['redirectUrl'] as String?,
    );
  }
}
