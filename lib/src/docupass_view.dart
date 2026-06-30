import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'docupass_config.dart';
import 'docupass_controller.dart';
import 'docupass_countries.dart';
import 'docupass_models.dart';

typedef DocuPassResultCallback = void Function(DocuPassResult result);

const Color _bg = Color(0xFF050A08);
const Color _accent = Color(0xFF00FFAB);
const Color _accentText = Color(0xFF00261A);
const Color _danger = Color(0xFFFFA3A3);
const Color _warning = Color(0xFFFF1E56);

class DocuPassView extends StatefulWidget {
  const DocuPassView({
    super.key,
    required this.reference,
    this.partyId,
    this.baseUrl,
    this.sessionId,
    this.authorization,
    this.geolocation,
    this.enabled = true,
    this.disableSslValidation = false,
    this.connectTimeoutMs = 20000,
    this.readTimeoutMs = 20000,
    this.maskCircleRadius = 0.42,
    this.maskCircleY = 0.45,
    this.turnTimeSeconds = 2.0,
    this.onResult,
    this.onBackAtFirstStep,
  });

  DocuPassView.config({
    super.key,
    required DocupassApiConfig config,
    this.maskCircleRadius = 0.42,
    this.maskCircleY = 0.45,
    this.turnTimeSeconds = 2.0,
    this.onResult,
    this.onBackAtFirstStep,
  })  : reference = config.reference,
        partyId = config.partyId,
        baseUrl = config.baseUrl,
        sessionId = config.sessionId,
        authorization = config.authorization,
        geolocation = config.geolocation,
        enabled = config.enabled,
        disableSslValidation = config.disableSslValidation,
        connectTimeoutMs = config.connectTimeoutMs,
        readTimeoutMs = config.readTimeoutMs;

  final String? reference;
  final String? partyId;
  final String? baseUrl;
  final String? sessionId;
  final String? authorization;
  final String? geolocation;
  final bool enabled;
  final bool disableSslValidation;
  final int connectTimeoutMs;
  final int readTimeoutMs;
  final double maskCircleRadius;
  final double maskCircleY;
  final double turnTimeSeconds;
  final DocuPassResultCallback? onResult;
  final VoidCallback? onBackAtFirstStep;

  @override
  State<DocuPassView> createState() => _DocuPassViewState();
}

class _DocuPassViewState extends State<DocuPassView> {
  late DocupassKycController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DocupassKycController(config: _config);
    unawaited(_controller.start());
  }

  @override
  void didUpdateWidget(covariant DocuPassView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_configKey(oldWidget) != _configKey(widget)) {
      _controller.dispose();
      _controller = DocupassKycController(config: _config);
      unawaited(_controller.start());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DocupassApiConfig get _config {
    return DocupassApiConfig(
      enabled: widget.enabled,
      baseUrl: widget.baseUrl,
      reference: widget.reference,
      partyId: widget.partyId,
      sessionId: widget.sessionId,
      authorization: widget.authorization,
      geolocation: widget.geolocation,
      disableSslValidation: widget.disableSslValidation,
      connectTimeoutMs: widget.connectTimeoutMs,
      readTimeoutMs: widget.readTimeoutMs,
    );
  }

  Object _configKey(DocuPassView value) {
    return Object.hashAll(<Object?>[
      value.enabled,
      value.baseUrl,
      value.reference,
      value.partyId,
      value.sessionId,
      value.authorization,
      value.geolocation,
      value.disableSslValidation,
      value.connectTimeoutMs,
      value.readTimeoutMs,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final isResultScreen = state.event is DocupassKycCompleted ||
            state.event is DocupassKycFailed;
        final canShowBack =
            !isResultScreen && state.event is! DocupassKycLoading;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBack(state, isResultScreen);
          },
          child: Material(
            color: _bg,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: _buildEvent(state.event, state)),
                if (state.isBusy) const _DefaultBusyProgress(),
                if (canShowBack)
                  _KycBackButton(
                    enabled: !state.isBusy,
                    onBack: () => _handleBack(state, isResultScreen),
                  ),
                if (state.error != null)
                  _DefaultApiErrorAlert(
                    message: state.error!.message,
                    onDismiss: _controller.clearError,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleBack(DocupassKycUiState state, bool isResultScreen) {
    if (state.error != null) {
      _controller.clearError();
      return;
    }
    if (isResultScreen || state.isBusy) return;
    if (state.canGoBack) {
      _controller.back();
    } else {
      widget.onBackAtFirstStep?.call();
    }
  }

  Widget _buildEvent(DocupassKycEvent event, DocupassKycUiState state) {
    return switch (event) {
      DocupassKycLoading() => const _DefaultInitializingOverlay(),
      DocupassKycPhoneVerification() => _PhoneVerificationScreen(
          state: event.state,
          isBusy: state.isBusy,
          codeSent: event.codeSent,
          currentNumber: event.currentNumber,
          onSendCode: _controller.sendPhoneCode,
          onVerifyCode: _controller.verifyPhoneCode,
        ),
      DocupassKycCustomForm() => _CustomFormScreen(
          fields: event.fields,
          isBusy: state.isBusy,
          onSubmit: _controller.saveCustomForm,
        ),
      DocupassKycDocumentCountrySelection() => _CountryPickerScreen(
          filterCodes: event.filterCodes,
          onSelected: _controller.selectDocumentCountry,
        ),
      DocupassKycDocumentSelection() => _IDTypePickerScreen(
          country: event.country,
          documentTypes: event.documentTypes,
          isLoading: state.isBusy,
          onSelected: (type) => unawaited(
            _controller.selectDocumentType(type.apiTypeCode),
          ),
        ),
      DocupassKycDocumentCapture() => _DocumentCaptureScreen(
          documentType: event.documentType,
          documentSide: event.documentSide,
          isBusy: state.isBusy,
          onCaptured: (front, back) => unawaited(
            _controller.uploadDocument(front, back),
          ),
        ),
      DocupassKycFaceVerification() => _BiometricScreen(
          actions: event.actions,
          maskCircleRadius: widget.maskCircleRadius,
          maskCircleY: widget.maskCircleY,
          turnTimeSeconds: widget.turnTimeSeconds,
          isBusy: state.isBusy,
          onComplete: (faces) => unawaited(_controller.uploadFace(faces)),
        ),
      DocupassKycContract() => _ContractScreen(
          state: event.state,
          isBusy: state.isBusy,
          onSubmit: (signatures) => unawaited(
            _controller.submitContract(signatures),
          ),
        ),
      DocupassKycPartyPending() => _PartyPendingScreen(
          isBusy: state.isBusy,
          onRefresh: () => unawaited(_controller.refresh()),
        ),
      DocupassKycCompleted() => _SuccessResultScreen(
          onFinish: () => widget.onResult?.call(
            event.result.toPublicResult(DocuPassStatus.completed),
          ),
        ),
      DocupassKycFailed() => _FailedResultScreen(
          error: event.error,
          onFinish: () => widget.onResult?.call(
            event.result.toPublicResult(DocuPassStatus.failed),
          ),
        ),
    };
  }
}

class _KycBackButton extends StatelessWidget {
  const _KycBackButton({required this.enabled, required this.onBack});

  final bool enabled;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onBack : null,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: enabled ? 0.58 : 0.28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: enabled ? 0.35 : 0.14),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '<',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: enabled ? 1 : 0.42),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultBusyProgress extends StatelessWidget {
  const _DefaultBusyProgress();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topCenter,
          child: LinearProgressIndicator(
            minHeight: 3,
            color: _accent,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }
}

class _DefaultApiErrorAlert extends StatelessWidget {
  const _DefaultApiErrorAlert({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: const Color(0xFF451515),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'ERROR',
                    style: TextStyle(
                      color: _danger,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onDismiss,
                    child: const Text('DISMISS'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultInitializingOverlay extends StatelessWidget {
  const _DefaultInitializingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.65),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: _accent),
            SizedBox(height: 14),
            Text(
              'Initializing...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneVerificationScreen extends StatefulWidget {
  const _PhoneVerificationScreen({
    required this.state,
    required this.isBusy,
    required this.codeSent,
    required this.currentNumber,
    required this.onSendCode,
    required this.onVerifyCode,
  });

  final DocupassSessionState state;
  final bool isBusy;
  final bool codeSent;
  final String? currentNumber;
  final void Function(String? number, String type) onSendCode;
  final void Function(String? number, String code) onVerifyCode;

  @override
  State<_PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<_PhoneVerificationScreen> {
  String _selectedDialCode = '+1';
  String _localNumber = '';
  String _otp = '';

  @override
  void didUpdateWidget(covariant _PhoneVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.phoneCountryCodes != widget.state.phoneCountryCodes &&
        widget.state.phoneCountryCodes.isNotEmpty) {
      _selectedDialCode = widget.state.phoneCountryCodes.first.dialCode;
    }
  }

  String? _buildNumber() {
    if (widget.state.userPhone?.trim().isNotEmpty == true) return null;
    final digits = _localNumber.trim().replaceFirst(RegExp(r'^0+'), '');
    return digits.isEmpty ? null : '$_selectedDialCode$digits';
  }

  @override
  Widget build(BuildContext context) {
    final presetPhone = widget.state.userPhone?.trim();
    final countryCodes = widget.state.phoneCountryCodes;
    if (countryCodes.isNotEmpty && _selectedDialCode == '+1') {
      _selectedDialCode = countryCodes.first.dialCode;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        children: <Widget>[
          const _StepLabel('STEP: PHONE VERIFICATION'),
          const SizedBox(height: 8),
          Text(
            'Verify your phone number to continue.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 24),
          if (presetPhone != null && presetPhone.isNotEmpty)
            Card(
              color: Colors.white.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Phone number',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      presetPhone,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            if (countryCodes.isNotEmpty) ...<Widget>[
              const Text(
                'Country code',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  itemCount: countryCodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final code = countryCodes[index];
                    final selected = _selectedDialCode == code.dialCode;
                    return FilledButton(
                      onPressed: widget.isBusy
                          ? null
                          : () => setState(() {
                                _selectedDialCode = code.dialCode;
                              }),
                      style: FilledButton.styleFrom(
                        backgroundColor: selected
                            ? _accent
                            : Colors.white.withValues(alpha: 0.1),
                        foregroundColor: selected ? _accentText : Colors.white,
                      ),
                      child: Text('${code.name} ${code.dialCode}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              enabled: !widget.isBusy,
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                setState(() {
                  _localNumber = value.replaceAll(RegExp(r'\D'), '');
                });
              },
              decoration: InputDecoration(
                labelText: 'Phone number',
                prefixText: '$_selectedDialCode ',
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: _accent),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: !widget.isBusy &&
                          (presetPhone?.isNotEmpty == true ||
                              _buildNumber() != null)
                      ? () => widget.onSendCode(_buildNumber(), 'sms')
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _accentText,
                  ),
                  child: const Text(
                    'SEND SMS',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: !widget.isBusy &&
                          (presetPhone?.isNotEmpty == true ||
                              _buildNumber() != null)
                      ? () => widget.onSendCode(_buildNumber(), 'call')
                      : null,
                  child: const Text('CALL'),
                ),
              ),
            ],
          ),
          if (widget.codeSent) ...<Widget>[
            const SizedBox(height: 24),
            TextField(
              enabled: !widget.isBusy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (value) {
                setState(() {
                  _otp = value.replaceAll(RegExp(r'\D'), '').substring(
                        0,
                        math.min(6, value.replaceAll(RegExp(r'\D'), '').length),
                      );
                });
              },
              decoration: const InputDecoration(
                labelText: '6 digit code',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _accent),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: !widget.isBusy && _otp.length == 6
                  ? () => widget.onVerifyCode(widget.currentNumber, _otp)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'VERIFY CODE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomFormScreen extends StatefulWidget {
  const _CustomFormScreen({
    required this.fields,
    required this.isBusy,
    required this.onSubmit,
  });

  final List<DocupassCustomField> fields;
  final bool isBusy;
  final ValueChanged<Map<String, String>> onSubmit;

  @override
  State<_CustomFormScreen> createState() => _CustomFormScreenState();
}

class _CustomFormScreenState extends State<_CustomFormScreen> {
  final Map<String, String> _answers = <String, String>{};

  bool get _requiredAnswered {
    return widget.fields.every((field) {
      final key = field.fieldId.isNotEmpty ? field.fieldId : field.fieldLabel;
      return _answers[key]?.trim().isNotEmpty == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        children: <Widget>[
          const _StepLabel('STEP: CUSTOM FORM'),
          const SizedBox(height: 18),
          for (final field in widget.fields) ...<Widget>[
            _CustomFieldInput(
              field: field,
              enabled: !widget.isBusy,
              value: _answers[field.fieldId.isNotEmpty
                      ? field.fieldId
                      : field.fieldLabel] ??
                  '',
              onChanged: (value) {
                final key =
                    field.fieldId.isNotEmpty ? field.fieldId : field.fieldLabel;
                setState(() => _answers[key] = value);
              },
            ),
            const SizedBox(height: 18),
          ],
          FilledButton(
            onPressed:
                !widget.isBusy && widget.fields.isNotEmpty && _requiredAnswered
                    ? () => widget.onSubmit(Map<String, String>.from(_answers))
                    : null,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: _accentText,
            ),
            child: const Text(
              'SAVE FORM',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomFieldInput extends StatelessWidget {
  const _CustomFieldInput({
    required this.field,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final DocupassCustomField field;
  final bool enabled;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final key = field.fieldId.isNotEmpty ? field.fieldId : field.fieldLabel;
    final label = field.fieldLabel.isNotEmpty ? field.fieldLabel : key;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (field.fieldDescription.isNotEmpty)
          Text(
            field.fieldDescription,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        const SizedBox(height: 8),
        if (field.fieldType == 2)
          for (final option in _parseCustomFieldOptions(field.fieldData))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: FilledButton(
                onPressed: enabled ? () => onChanged(option.value) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: value == option.value
                      ? _accent
                      : Colors.white.withValues(alpha: 0.1),
                  foregroundColor:
                      value == option.value ? _accentText : Colors.white,
                ),
                child: Text(option.label),
              ),
            )
        else
          TextField(
            enabled: enabled,
            minLines: field.fieldType == 1 ? 3 : 1,
            maxLines: field.fieldType == 1 ? 5 : 1,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _accent),
              ),
            ),
          ),
      ],
    );
  }
}

class _CountryPickerScreen extends StatefulWidget {
  const _CountryPickerScreen({
    required this.filterCodes,
    required this.onSelected,
  });

  final List<String>? filterCodes;
  final ValueChanged<DocupassCountry> onSelected;

  @override
  State<_CountryPickerScreen> createState() => _CountryPickerScreenState();
}

class _CountryPickerScreenState extends State<_CountryPickerScreen> {
  String _query = '';
  List<DocupassCountry> _countries = const <DocupassCountry>[];
  bool _isLoading = true;
  String? _loadError;
  int _requestId = 0;

  String get _filterKey => (widget.filterCodes ?? const <String>[])
      .map((code) => code.trim().toUpperCase())
      .where((code) => code.isNotEmpty)
      .join(',');

  @override
  void initState() {
    super.initState();
    unawaited(_loadCountries());
  }

  @override
  void didUpdateWidget(covariant _CountryPickerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFilterKey = (oldWidget.filterCodes ?? const <String>[])
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .join(',');
    if (oldFilterKey != _filterKey) {
      unawaited(_loadCountries());
    }
  }

  @override
  void dispose() {
    _requestId++;
    super.dispose();
  }

  Future<void> _loadCountries() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final countries = await fetchDocupassCountries(widget.filterCodes);
      if (!mounted || _requestId != requestId) return;
      setState(() {
        _countries = countries;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || _requestId != requestId) return;
      setState(() {
        _countries = const <DocupassCountry>[];
        _loadError = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _query.isEmpty
        ? _countries
        : _countries.where((country) {
            final query = _query.toLowerCase();
            return country.name.toLowerCase().contains(query) ||
                country.code.toLowerCase().contains(query);
          }).toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _StepLabel('STEP: SELECT COUNTRY'),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _CountryPickerBody(
                isLoading: _isLoading,
                loadError: _loadError,
                countries: displayList,
                onRetry: () => unawaited(_loadCountries()),
                onSelected: widget.onSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerBody extends StatelessWidget {
  const _CountryPickerBody({
    required this.isLoading,
    required this.loadError,
    required this.countries,
    required this.onRetry,
    required this.onSelected,
  });

  final bool isLoading;
  final String? loadError;
  final List<DocupassCountry> countries;
  final VoidCallback onRetry;
  final ValueChanged<DocupassCountry> onSelected;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }
    if (loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _danger),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }
    if (countries.isEmpty) {
      return Center(
        child: Text(
          'No countries found.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }
    return ListView.separated(
      itemCount: countries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final country = countries[index];
        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          child: InkWell(
            onTap: () => onSelected(country),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      country.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    country.code,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IDTypePickerScreen extends StatelessWidget {
  const _IDTypePickerScreen({
    required this.country,
    required this.documentTypes,
    required this.isLoading,
    required this.onSelected,
  });

  final DocupassCountry country;
  final List<DocupassDocumentType> documentTypes;
  final bool isLoading;
  final ValueChanged<DocupassDocumentType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _StepLabel('STEP: SELECT DOCUMENT'),
            Text(
              'For ${country.flag} ${country.name}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            for (final type in documentTypes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: FilledButton(
                  onPressed: isLoading ? null : () => onSelected(type),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    type.label,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _DocumentCaptureSide { front, back }

class _DocumentCaptureScreen extends StatefulWidget {
  const _DocumentCaptureScreen({
    required this.documentType,
    required this.documentSide,
    required this.isBusy,
    required this.onCaptured,
  });

  final DocupassDocumentType? documentType;
  final int? documentSide;
  final bool isBusy;
  final void Function(String frontBase64, String? backBase64) onCaptured;

  @override
  State<_DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends State<_DocumentCaptureScreen> {
  _DocumentCaptureSide? _activeSide;
  String? _frontBase64;
  String? _backBase64;
  Uint8List? _frontPreview;
  Uint8List? _backPreview;
  DocupassDocumentType? _cardMaskType;

  bool get _requiresBack {
    return switch (widget.documentSide) {
      1 => false,
      2 => widget.documentType != passportDocumentType,
      _ => widget.documentType?.requiresBackSide == true,
    };
  }

  bool get _readyToSubmit {
    return _frontBase64 != null && (!_requiresBack || _backBase64 != null);
  }

  @override
  void didUpdateWidget(covariant _DocumentCaptureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentType != widget.documentType) {
      _cardMaskType = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSide != null) {
      final canToggleCardMask =
          widget.documentType == driverLicenseDocumentType ||
              widget.documentType == identityCardDocumentType;
      final effectiveMaskType = canToggleCardMask
          ? (_cardMaskType ?? widget.documentType)
          : widget.documentType;
      return _DocumentCameraCapture(
        documentType: effectiveMaskType,
        canToggleCardMask: canToggleCardMask,
        isBusy: widget.isBusy,
        onToggleMask: canToggleCardMask
            ? () {
                setState(() {
                  _cardMaskType = effectiveMaskType == driverLicenseDocumentType
                      ? identityCardDocumentType
                      : driverLicenseDocumentType;
                });
              }
            : null,
        onCaptured: (encoded, previewBytes) {
          setState(() {
            if (_activeSide == _DocumentCaptureSide.front) {
              _frontBase64 = encoded;
              _frontPreview = previewBytes;
            } else {
              _backBase64 = encoded;
              _backPreview = previewBytes;
            }
            _activeSide = null;
          });
        },
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Card(
              color: Colors.black.withValues(alpha: 0.45),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _StepLabel('STEP: DOCUMENT UPLOAD', fontSize: 13),
                    const SizedBox(height: 6),
                    Text(
                      'Front: ${_frontBase64 != null ? "Done" : "Pending"} | Back: ${!_requiresBack ? "Not Required" : _backBase64 != null ? "Done" : "Pending"}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DocumentCapturePreviewCard(
              bytes: _frontPreview,
              emptyLabel: 'No front photo yet',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.isBusy
                  ? null
                  : () => setState(() {
                        _activeSide = _DocumentCaptureSide.front;
                      }),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: _accent,
                foregroundColor: _accentText,
              ),
              child: const Text(
                'CAPTURE DOCUMENT FRONT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 20),
            if (_requiresBack) ...<Widget>[
              _DocumentCapturePreviewCard(
                bytes: _backPreview,
                emptyLabel: 'No back photo yet',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.isBusy
                    ? null
                    : () => setState(() {
                          _activeSide = _DocumentCaptureSide.back;
                        }),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'CAPTURE DOCUMENT BACK',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...<Widget>[
              const Text(
                'Back side is not required for passport.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],
            FilledButton(
              onPressed: !widget.isBusy && _readyToSubmit
                  ? () => widget.onCaptured(
                        _frontBase64!,
                        _requiresBack ? _backBase64 : null,
                      )
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: _accent,
                foregroundColor: _accentText,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
              ),
              child: const Text(
                'UPLOAD DOCUMENT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCameraCapture extends StatefulWidget {
  const _DocumentCameraCapture({
    required this.documentType,
    required this.canToggleCardMask,
    required this.isBusy,
    required this.onCaptured,
    this.onToggleMask,
  });

  final DocupassDocumentType? documentType;
  final bool canToggleCardMask;
  final bool isBusy;
  final void Function(String encoded, Uint8List previewBytes) onCaptured;
  final VoidCallback? onToggleMask;

  @override
  State<_DocumentCameraCapture> createState() => _DocumentCameraCaptureState();
}

class _DocumentCameraCaptureState extends State<_DocumentCameraCapture> {
  CameraController? _camera;
  Object? _error;
  bool _initializing = true;
  bool _capturing = false;
  Size _previewSize = Size.zero;
  _DocumentMaskSpec? _maskSpec;
  bool _isPortrait = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    unawaited(_camera?.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      setState(() {
        _error = 'Camera permission is required';
        _initializing = false;
      });
      return;
    }
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _initializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) return const _DefaultInitializingOverlay();
    final camera = _camera;
    if (_error != null || camera == null || !camera.value.isInitialized) {
      return Center(
        child: Text(
          _error?.toString() ?? 'Camera is unavailable',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    final isPortrait =
        MediaQuery.orientationOf(context) != Orientation.landscape;
    final previewAspect = isPortrait ? 9 / 16 : 16 / 9;
    final maskSpec = _resolveDocumentMaskSpec(widget.documentType, isPortrait);

    return ColoredBox(
      color: const Color(0xFF090909),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 64, bottom: 20),
          child: Column(
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth =
                        constraints.maxWidth * (isPortrait ? 1.0 : 0.9);
                    final maxHeight = constraints.maxHeight;
                    final width = math.min(maxWidth, maxHeight * previewAspect);
                    final height = width / previewAspect;
                    final previewSize = Size(width, height);
                    _previewSize = previewSize;
                    _maskSpec = maskSpec;
                    _isPortrait = isPortrait;
                    return Center(
                      child: Container(
                        width: width,
                        height: height,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            _CameraPreviewCover(controller: camera),
                            CustomPaint(
                              painter: _DocumentMaskPainter(
                                maskSpec: maskSpec,
                                isPhonePortrait: isPortrait,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    const SizedBox(width: double.infinity, height: 90),
                    _CameraShutterButton(
                      enabled: !widget.isBusy && !_capturing,
                      onClick: () => unawaited(_captureCurrent()),
                    ),
                    if (widget.canToggleCardMask)
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: widget.isBusy ? null : widget.onToggleMask,
                          style: OutlinedButton.styleFrom(
                            fixedSize: const Size(70, 42),
                            padding: EdgeInsets.zero,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            widget.documentType == driverLicenseDocumentType
                                ? 'VERT'
                                : 'LAND',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureCurrent() async {
    final camera = _camera;
    final maskSpec = _maskSpec;
    if (camera == null || maskSpec == null || _previewSize == Size.zero) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final result = await _captureDocumentImage(
        camera: camera,
        previewSize: _previewSize,
        maskSpec: maskSpec,
        isPortrait: _isPortrait,
      );
      widget.onCaptured(result.base64, result.previewBytes);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }
}

class _DocumentCapturePreviewCard extends StatelessWidget {
  const _DocumentCapturePreviewCard({
    required this.bytes,
    required this.emptyLabel,
  });

  final Uint8List? bytes;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      child: SizedBox(
        height: 132,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: bytes == null
                ? Text(
                    emptyLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  )
                : Image.memory(bytes!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _BiometricScreen extends StatefulWidget {
  const _BiometricScreen({
    required this.actions,
    required this.maskCircleRadius,
    required this.maskCircleY,
    required this.turnTimeSeconds,
    required this.isBusy,
    required this.onComplete,
  });

  final List<KYCAction> actions;
  final double maskCircleRadius;
  final double maskCircleY;
  final double turnTimeSeconds;
  final bool isBusy;
  final ValueChanged<List<String>> onComplete;

  @override
  State<_BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<_BiometricScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  FaceDetector? _faceDetector;
  CameraDescription? _cameraDescription;
  Object? _error;
  bool _initializing = true;
  bool _processing = false;
  bool _completeTriggered = false;
  int _actionIndex = -1;
  String _instruction = 'ALIGN FACE TO CIRCLE';
  double _timer = 0;
  DateTime? _stepStartTime;
  DateTime? _lastFrameAnalysisAt;
  final List<String> _capturedFaces = <String>[];

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    unawaited(_faceDetector?.close());
    unawaited(_disposeCamera());
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
    } catch (_) {
      // The controller may already be shutting down.
    }
    await camera.dispose();
  }

  Future<void> _initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      setState(() {
        _error = 'Camera permission is required';
        _initializing = false;
      });
      return;
    }
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: _streamImageFormatGroup(),
      );
      await controller.initialize();
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      if (!mounted) {
        await detector.close();
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraDescription = front;
        _faceDetector = detector;
        _initializing = false;
      });
      await controller.startImageStream(_handleCameraImage);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _initializing = false;
      });
    }
  }

  void _handleCameraImage(CameraImage image) {
    if (_processing || widget.isBusy || _completeTriggered) return;
    final now = DateTime.now();
    final last = _lastFrameAnalysisAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 180)) {
      return;
    }
    _lastFrameAnalysisAt = now;
    unawaited(_analyzeFrame(image));
  }

  Future<void> _analyzeFrame(CameraImage image) async {
    final camera = _camera;
    final cameraDescription = _cameraDescription;
    final detector = _faceDetector;
    if (_processing ||
        widget.isBusy ||
        _completeTriggered ||
        camera == null ||
        cameraDescription == null ||
        detector == null ||
        !camera.value.isInitialized) {
      return;
    }
    final inputImage = _inputImageFromCameraImage(
      cameraDescription: cameraDescription,
      controller: camera,
      image: image,
    );
    if (inputImage == null) return;

    _processing = true;
    try {
      final faces = await detector.processImage(inputImage);
      if (faces.isEmpty) {
        _stepStartTime = null;
        if (mounted) {
          setState(() {
            _instruction = 'ALIGN FACE TO CIRCLE';
            _timer = 0;
          });
        }
        return;
      }
      final face = faces.first;
      if (_actionIndex == -1) {
        final aligned = _isFaceAligned(face, image.width, image.height);
        if (mounted) {
          setState(() {
            _instruction = aligned ? 'READY TO SCAN' : 'ALIGN FACE TO CIRCLE';
          });
        }
      } else if (_actionIndex >= 0 && _actionIndex < widget.actions.length) {
        await _processAction(
          face,
          image.width,
          image.height,
          image,
          cameraDescription,
          camera.value.deviceOrientation,
        );
      }
    } catch (_) {
      // The next stream frame will retry; ML Kit can reject transient frames.
    } finally {
      _processing = false;
    }
  }

  Future<void> _processAction(
    Face face,
    int imageWidth,
    int imageHeight,
    CameraImage cameraImage,
    CameraDescription cameraDescription,
    DeviceOrientation deviceOrientation,
  ) async {
    final action = widget.actions[_actionIndex];
    if (!_isFaceAligned(face, imageWidth, imageHeight)) {
      _stepStartTime = null;
      if (mounted) {
        setState(() {
          _instruction = 'KEEP FACE INSIDE';
          _timer = 0;
        });
      }
      return;
    }

    final triggered = _isActionTriggered(face, action, cameraDescription);
    if (!triggered) {
      _stepStartTime = null;
      if (mounted) {
        setState(() {
          _instruction = action.instruction;
          _timer = 0;
        });
      }
      return;
    }

    _stepStartTime ??= DateTime.now();
    final elapsed =
        DateTime.now().difference(_stepStartTime!).inMilliseconds / 1000.0;
    if (elapsed >= widget.turnTimeSeconds) {
      final faceBase64 = _cameraImageToJpegBase64(
        cameraImage,
        cameraDescription,
        deviceOrientation,
      );
      if (faceBase64 == null) {
        _stepStartTime = null;
        if (mounted) {
          setState(() {
            _instruction = 'KEEP FACE INSIDE';
            _timer = 0;
          });
        }
        return;
      }
      _stepStartTime = null;
      _capturedFaces.add(faceBase64);
      final nextIndex = _actionIndex + 1;
      if (mounted) {
        setState(() {
          _actionIndex = nextIndex;
          _instruction = nextIndex < widget.actions.length
              ? widget.actions[nextIndex].instruction
              : 'VERIFIED';
          _timer = 0;
        });
      }
      if (nextIndex == widget.actions.length && !_completeTriggered) {
        _completeTriggered = true;
        widget.onComplete(List<String>.from(_capturedFaces));
      }
    } else if (mounted) {
      setState(() {
        _instruction = 'HOLDING...';
        _timer = elapsed;
      });
    }
  }

  bool _isFaceAligned(Face face, int imageWidth, int imageHeight) {
    final box = face.boundingBox;
    final centerX = box.center.dx / imageWidth;
    final centerY = box.center.dy / imageHeight;
    final faceRadius =
        math.max(box.width / imageWidth, box.height / imageHeight) / 2;
    final circleDistance = math.sqrt(
      math.pow(centerX - 0.5, 2) +
          math.pow(
              (centerY - widget.maskCircleY) *
                  (imageHeight / math.max(1, imageWidth)),
              2),
    );
    return circleDistance + faceRadius * 0.58 < widget.maskCircleRadius;
  }

  bool _isActionTriggered(
    Face face,
    KYCAction action,
    CameraDescription cameraDescription,
  ) {
    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;
    return switch (action) {
      KYCAction.turnLeft => _faceTurnLeft(face, cameraDescription, yaw),
      KYCAction.turnRight => _faceTurnRight(face, cameraDescription, yaw),
      KYCAction.turnUp => pitch.abs() > 10,
      KYCAction.mouthOpen => _mouthOpen(face),
    };
  }

  bool _faceTurnLeft(
    Face face,
    CameraDescription cameraDescription,
    double yaw,
  ) {
    final noseX = _faceDisplayNoseXRatio(face, cameraDescription);
    if (noseX != null) return noseX < 0.40;
    return _displayYaw(yaw, cameraDescription) >= 12;
  }

  bool _faceTurnRight(
    Face face,
    CameraDescription cameraDescription,
    double yaw,
  ) {
    final noseX = _faceDisplayNoseXRatio(face, cameraDescription);
    if (noseX != null) return noseX > 0.60;
    return _displayYaw(yaw, cameraDescription) <= -12;
  }

  bool _mouthOpen(Face face) {
    const mouthOpenRatio = 0.075;
    final faceHeight = math.max(1.0, face.boundingBox.height.toDouble());
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
    if (leftMouth != null && rightMouth != null && bottomMouth != null) {
      final mouthLineY = (leftMouth.y + rightMouth.y) / 2.0;
      return (bottomMouth.y - mouthLineY).abs() / faceHeight >= mouthOpenRatio;
    }

    final upperY = _averagePointY(<math.Point<int>>[
      ...?face.contours[FaceContourType.upperLipBottom]?.points,
      ...?face.contours[FaceContourType.upperLipTop]?.points,
    ]);
    final lowerY = _averagePointY(<math.Point<int>>[
      ...?face.contours[FaceContourType.lowerLipTop]?.points,
      ...?face.contours[FaceContourType.lowerLipBottom]?.points,
    ]);
    if (upperY != null && lowerY != null) {
      return (lowerY - upperY).abs() / faceHeight >= mouthOpenRatio * 0.7;
    }

    return false;
  }

  double? _averagePointY(List<math.Point<int>> points) {
    if (points.isEmpty) return null;
    final total = points.fold<double>(0, (sum, point) => sum + point.y);
    return total / points.length;
  }

  double? _faceDisplayNoseXRatio(
    Face face,
    CameraDescription cameraDescription,
  ) {
    final noseX = _noseX(face);
    final bounds = _faceHorizontalBounds(face);
    if (noseX == null || bounds == null || bounds.width <= 1) return null;
    var ratio = ((noseX - bounds.minX) / bounds.width).clamp(0.0, 1.0);
    if (_shouldMirrorFaceHorizontally(cameraDescription)) {
      ratio = 1.0 - ratio;
    }
    return ratio;
  }

  double? _noseX(Face face) {
    final noseBase = face.landmarks[FaceLandmarkType.noseBase]?.position;
    if (noseBase != null) return noseBase.x.toDouble();
    return _averagePointX(face.contours[FaceContourType.noseBottom]?.points);
  }

  double? _averagePointX(List<math.Point<int>>? points) {
    if (points == null || points.isEmpty) return null;
    final total = points.fold<double>(0, (sum, point) => sum + point.x);
    return total / points.length;
  }

  _FaceHorizontalBounds? _faceHorizontalBounds(Face face) {
    final xs = <double>[];

    for (final landmark in face.landmarks.values) {
      final point = landmark?.position;
      if (point != null) xs.add(point.x.toDouble());
    }

    for (final contour in face.contours.values) {
      final points = contour?.points;
      if (points == null) continue;
      for (final point in points) {
        xs.add(point.x.toDouble());
      }
    }

    if (xs.length < 2) {
      final box = face.boundingBox;
      if (box.width <= 1) return null;
      return _FaceHorizontalBounds(box.left, box.right);
    }

    var minX = xs.first;
    var maxX = xs.first;
    for (final x in xs.skip(1)) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
    }
    return maxX - minX <= 1 ? null : _FaceHorizontalBounds(minX, maxX);
  }

  double _displayYaw(double yaw, CameraDescription cameraDescription) {
    return _shouldMirrorFaceHorizontally(cameraDescription) ? -yaw : yaw;
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) return const _DefaultInitializingOverlay();
    final camera = _camera;
    if (_error != null || camera == null || !camera.value.isInitialized) {
      return Center(
        child: Text(
          _error?.toString() ?? 'Camera is unavailable',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    final isWarn =
        _instruction.contains('KEEP') || _instruction.contains('ALIGN');
    final ringColor = isWarn ? _warning : _accent;
    final progress = (_timer / widget.turnTimeSeconds).clamp(0.0, 1.0);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: _CameraPreviewCover(controller: camera),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _FaceMaskPainter(
              circleRadius: widget.maskCircleRadius,
              circleY: widget.maskCircleY,
              ringColor: ringColor,
              progress: _actionIndex >= 0 && !isWarn ? progress : 0,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Text(
                              _instruction,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Captured faces: ${_capturedFaces.length}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                if (_actionIndex == -1)
                  FilledButton(
                    onPressed: widget.isBusy
                        ? null
                        : () {
                            if (widget.actions.isEmpty) {
                              _completeTriggered = true;
                              widget.onComplete(
                                  List<String>.from(_capturedFaces));
                            } else {
                              setState(() {
                                _actionIndex = 0;
                                _instruction = widget.actions.first.instruction;
                              });
                            }
                          },
                    child: const Text('INITIATE SCAN'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FaceHorizontalBounds {
  const _FaceHorizontalBounds(this.minX, this.maxX);

  final double minX;
  final double maxX;

  double get width => maxX - minX;
}

class _ContractScreen extends StatefulWidget {
  const _ContractScreen({
    required this.state,
    required this.isBusy,
    required this.onSubmit,
  });

  final DocupassSessionState state;
  final bool isBusy;
  final ValueChanged<Map<String, String>> onSubmit;

  @override
  State<_ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends State<_ContractScreen> {
  late WebViewController _webViewController;
  final List<List<Offset>> _strokes = <List<Offset>>[];
  Map<String, String> _contractSignatures = <String, String>{};
  List<Offset> _activeStroke = <Offset>[];
  Size _signaturePadSize = Size.zero;
  bool _encodingSignature = false;
  int _signaturePreviewRequest = 0;

  bool get _hasSignature {
    return _strokes.any((stroke) => stroke.isNotEmpty) ||
        _activeStroke.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..loadHtmlString(_contractHtml());
  }

  @override
  void didUpdateWidget(covariant _ContractScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.contractSource != widget.state.contractSource) {
      _contractSignatures = <String, String>{};
      _signaturePreviewRequest++;
      unawaited(_webViewController.loadHtmlString(_contractHtml()));
      _strokes.clear();
      _activeStroke = <Offset>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final signatureFields = extractContractSignatureFields(
      widget.state.contractSource ?? '',
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _StepLabel('STEP: REVIEW CONTRACT'),
            const SizedBox(height: 10),
            Expanded(
              child: Card(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: WebViewWidget(controller: _webViewController),
              ),
            ),
            const SizedBox(height: 12),
            if (signatureFields.isNotEmpty) ...<Widget>[
              Text(
                '${signatureFields.length} signature field(s) required',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              _SignaturePad(
                strokes: _strokes,
                activeStroke: _activeStroke,
                enabled: !widget.isBusy,
                onSize: (size) => _signaturePadSize = size,
                onStrokeStart: (offset) {
                  setState(() => _activeStroke = <Offset>[offset]);
                },
                onStrokeUpdate: (offset) {
                  setState(() => _activeStroke = <Offset>[
                        ..._activeStroke,
                        offset,
                      ]);
                },
                onStrokeEnd: () {
                  var didAddStroke = false;
                  setState(() {
                    if (_activeStroke.isNotEmpty) {
                      _strokes.add(_activeStroke);
                      didAddStroke = true;
                    }
                    _activeStroke = <Offset>[];
                  });
                  if (didAddStroke) {
                    unawaited(_updateSignaturePreview(signatureFields));
                  }
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: !widget.isBusy && _hasSignature
                      ? () {
                          setState(() {
                            _strokes.clear();
                            _activeStroke = <Offset>[];
                            _contractSignatures = <String, String>{};
                          });
                          _signaturePreviewRequest++;
                          unawaited(
                            _webViewController.loadHtmlString(_contractHtml()),
                          );
                        }
                      : null,
                  child: const Text('CLEAR'),
                ),
              ),
            ] else
              Text(
                'No signature image is required for this contract.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: !widget.isBusy &&
                      !_encodingSignature &&
                      (signatureFields.isEmpty || _hasSignature)
                  ? () => unawaited(_submit(signatureFields))
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: _accent,
                foregroundColor: _accentText,
              ),
              child: const Text(
                'ACCEPT AND SUBMIT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(
    List<DocupassContractSignatureField> signatureFields,
  ) async {
    setState(() => _encodingSignature = true);
    try {
      var signatures = Map<String, String>.from(_contractSignatures);
      if (signatureFields.isNotEmpty) {
        if (!_hasAllSignatureFields(signatureFields, signatures)) {
          final image = await _createHandwrittenSignatureDataUrl(
            _strokes,
            _signaturePadSize,
          );
          if (image == null) return;
          signatures = <String, String>{
            for (final field in signatureFields) field.uid: image,
          };
          _contractSignatures = signatures;
          await _webViewController.loadHtmlString(_contractHtml(signatures));
        }
      }
      widget.onSubmit(signatures);
    } finally {
      if (mounted) setState(() => _encodingSignature = false);
    }
  }

  String _contractHtml([Map<String, String>? signatures]) {
    final html = _injectContractSignatures(
      widget.state.contractSource ?? '',
      signatures ?? _contractSignatures,
    );
    return _cleanupContractHtml(html);
  }

  Future<void> _updateSignaturePreview(
    List<DocupassContractSignatureField> signatureFields,
  ) async {
    if (signatureFields.isEmpty || !_hasSignature) return;
    final requestId = ++_signaturePreviewRequest;
    final image = await _createHandwrittenSignatureDataUrl(
      _strokes,
      _signaturePadSize,
    );
    if (!mounted || requestId != _signaturePreviewRequest || image == null) {
      return;
    }
    final signatures = <String, String>{
      for (final field in signatureFields) field.uid: image,
    };
    setState(() => _contractSignatures = signatures);
    await _webViewController.loadHtmlString(_contractHtml(signatures));
  }

  bool _hasAllSignatureFields(
    List<DocupassContractSignatureField> signatureFields,
    Map<String, String> signatures,
  ) {
    return signatureFields.every(
      (field) => signatures[field.uid]?.trim().isNotEmpty == true,
    );
  }
}

class _PartyPendingScreen extends StatelessWidget {
  const _PartyPendingScreen({required this.isBusy, required this.onRefresh});

  final bool isBusy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'SIGNATURE PENDING',
              style: TextStyle(
                color: _accent,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your part is complete. The contract is waiting for another party to finish signing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isBusy ? null : onRefresh,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _accentText,
              ),
              child: const Text(
                'REFRESH STATUS',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessResultScreen extends StatelessWidget {
  const _SuccessResultScreen({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'VERIFIED SUCCESSFULLY',
            style: TextStyle(
              color: _accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 40),
          FilledButton(onPressed: onFinish, child: const Text('FINISH')),
        ],
      ),
    );
  }
}

class _FailedResultScreen extends StatelessWidget {
  const _FailedResultScreen({required this.error, required this.onFinish});

  final DocupassNormalizedError? error;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'VERIFICATION FAILED',
              style: TextStyle(
                color: _danger,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error?.toDisplayMessage() ??
                  'The DocuPass verification did not complete successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onFinish,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: Colors.white,
              ),
              child: const Text('FINISH'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.text, {this.fontSize = 14});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _accent,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = CameraPreview(controller);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: preview,
        ),
      ),
    );
  }
}

class _CameraShutterButton extends StatelessWidget {
  const _CameraShutterButton({required this.enabled, required this.onClick});

  final bool enabled;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: enabled ? 1 : 0.42);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? onClick : null,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _SignaturePad extends StatelessWidget {
  const _SignaturePad({
    required this.strokes,
    required this.activeStroke,
    required this.enabled,
    required this.onSize,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  final List<List<Offset>> strokes;
  final List<Offset> activeStroke;
  final bool enabled;
  final ValueChanged<Size> onSize;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  @override
  Widget build(BuildContext context) {
    final hasSignature =
        strokes.any((stroke) => stroke.isNotEmpty) || activeStroke.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 176);
        onSize(size);
        return GestureDetector(
          onPanStart: enabled
              ? (details) => onStrokeStart(details.localPosition)
              : null,
          onPanUpdate: enabled
              ? (details) => onStrokeUpdate(details.localPosition)
              : null,
          onPanEnd: enabled ? (_) => onStrokeEnd() : null,
          onPanCancel: enabled ? onStrokeEnd : null,
          child: Container(
            height: 176,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasSignature ? _accent : const Color(0xFF4A5C55),
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SignaturePainter(
                      strokes: strokes,
                      activeStroke: activeStroke,
                    ),
                  ),
                ),
                if (!hasSignature)
                  const Center(
                    child: Text(
                      'Draw signature here',
                      style: TextStyle(color: Color(0xFF6C7772), fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({
    required this.strokes,
    required this.activeStroke,
  });

  final List<List<Offset>> strokes;
  final List<Offset> activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in <List<Offset>>[...strokes, activeStroke]) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, paint.strokeWidth / 2, paint);
      } else {
        for (var i = 0; i < stroke.length - 1; i++) {
          canvas.drawLine(stroke[i], stroke[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke;
  }
}

class _DocumentMaskPainter extends CustomPainter {
  const _DocumentMaskPainter({
    required this.maskSpec,
    required this.isPhonePortrait,
  });

  final _DocumentMaskSpec maskSpec;
  final bool isPhonePortrait;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = _calculateMaskFrame(size, maskSpec, isPhonePortrait);
    final rect =
        Rect.fromLTWH(frame.left, frame.top, frame.width, frame.height);
    final radius = Radius.circular(16);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.56),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    if (maskSpec.lowerHalfOnly) {
      final halfY = frame.top + frame.height * 0.5;
      canvas.drawRect(
        Rect.fromLTWH(frame.left, frame.top, frame.width, frame.height * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.36),
      );
      canvas.drawLine(
        Offset(frame.left, halfY),
        Offset(frame.left + frame.width, halfY),
        Paint()
          ..color = const Color(0xFFFFD166)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DocumentMaskPainter oldDelegate) {
    return oldDelegate.maskSpec != maskSpec ||
        oldDelegate.isPhonePortrait != isPhonePortrait;
  }
}

class _FaceMaskPainter extends CustomPainter {
  const _FaceMaskPainter({
    required this.circleRadius,
    required this.circleY,
    required this.ringColor,
    required this.progress,
  });

  final double circleRadius;
  final double circleY;
  final Color ringColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * circleY);
    final radius = size.width * circleRadius;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
        center, radius * 1.02, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        radius + i * 8,
        Paint()
          ..color = ringColor.withValues(alpha: 0.45 / (i * 2))
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4 - i) * 2,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ringColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * math.pi * 2,
        false,
        Paint()
          ..color = _accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaceMaskPainter oldDelegate) {
    return oldDelegate.circleRadius != circleRadius ||
        oldDelegate.circleY != circleY ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.progress != progress;
  }
}

class _DocumentMaskSpec {
  const _DocumentMaskSpec({
    required this.aspectRatio,
    required this.widthRatioPortrait,
    required this.widthRatioLandscape,
    required this.centerYRatio,
    required this.lowerHalfOnly,
  });

  final double aspectRatio;
  final double widthRatioPortrait;
  final double widthRatioLandscape;
  final double centerYRatio;
  final bool lowerHalfOnly;
}

class _MaskFrame {
  const _MaskFrame({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

_DocumentMaskSpec _resolveDocumentMaskSpec(
  DocupassDocumentType? documentType,
  bool isPhonePortrait,
) {
  const id1LandscapeRatio = 85.60 / 53.98;
  const id1PortraitRatio = 53.98 / 85.60;
  const passportLandscapeRatio = 125 / 88;
  const passportPortraitRatio = 88 / 125;

  if (documentType == driverLicenseDocumentType) {
    return isPhonePortrait
        ? const _DocumentMaskSpec(
            aspectRatio: id1PortraitRatio,
            widthRatioPortrait: 0.96,
            widthRatioLandscape: 0.90,
            centerYRatio: 0.52,
            lowerHalfOnly: false,
          )
        : const _DocumentMaskSpec(
            aspectRatio: id1LandscapeRatio,
            widthRatioPortrait: 0.96,
            widthRatioLandscape: 0.92,
            centerYRatio: 0.50,
            lowerHalfOnly: false,
          );
  }
  if (documentType == passportDocumentType) {
    return isPhonePortrait
        ? const _DocumentMaskSpec(
            aspectRatio: passportPortraitRatio,
            widthRatioPortrait: 0.96,
            widthRatioLandscape: 0.90,
            centerYRatio: 0.55,
            lowerHalfOnly: true,
          )
        : const _DocumentMaskSpec(
            aspectRatio: passportLandscapeRatio,
            widthRatioPortrait: 0.96,
            widthRatioLandscape: 0.92,
            centerYRatio: 0.52,
            lowerHalfOnly: true,
          );
  }
  return const _DocumentMaskSpec(
    aspectRatio: id1LandscapeRatio,
    widthRatioPortrait: 0.96,
    widthRatioLandscape: 0.92,
    centerYRatio: 0.50,
    lowerHalfOnly: false,
  );
}

_MaskFrame _calculateMaskFrame(
  Size containerSize,
  _DocumentMaskSpec spec,
  bool isPhonePortrait,
) {
  final frameWidthRatio =
      isPhonePortrait ? spec.widthRatioPortrait : spec.widthRatioLandscape;
  var frameWidth = containerSize.width * frameWidthRatio;
  var frameHeight = frameWidth / spec.aspectRatio;
  final maxFrameHeight = containerSize.height * (isPhonePortrait ? 0.94 : 0.86);
  if (frameHeight > maxFrameHeight) {
    frameHeight = maxFrameHeight;
    frameWidth = frameHeight * spec.aspectRatio;
  }
  final centerX = containerSize.width * 0.5;
  final centerY = containerSize.height * spec.centerYRatio;
  return _MaskFrame(
    left: centerX - frameWidth * 0.5,
    top: centerY - frameHeight * 0.5,
    width: frameWidth,
    height: frameHeight,
  );
}

const Map<DeviceOrientation, int> _cameraOrientations =
    <DeviceOrientation, int>{
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

ImageFormatGroup _streamImageFormatGroup() {
  return defaultTargetPlatform == TargetPlatform.android
      ? ImageFormatGroup.nv21
      : ImageFormatGroup.bgra8888;
}

bool _shouldMirrorFaceHorizontally(CameraDescription cameraDescription) {
  return defaultTargetPlatform == TargetPlatform.android &&
      cameraDescription.lensDirection == CameraLensDirection.front;
}

InputImage? _inputImageFromCameraImage({
  required CameraDescription cameraDescription,
  required CameraController controller,
  required CameraImage image,
}) {
  final rotation = _inputImageRotation(
    cameraDescription,
    controller.value.deviceOrientation,
  );
  final format = _inputImageFormat(image);
  if (rotation == null || format == null || image.planes.length != 1) {
    return null;
  }
  if (defaultTargetPlatform == TargetPlatform.android &&
      format != InputImageFormat.nv21) {
    return null;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS &&
      format != InputImageFormat.bgra8888) {
    return null;
  }
  final plane = image.planes.first;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

InputImageRotation? _inputImageRotation(
  CameraDescription cameraDescription,
  DeviceOrientation deviceOrientation,
) {
  final sensorOrientation = cameraDescription.sensorOrientation;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return InputImageRotationValue.fromRawValue(sensorOrientation);
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    final orientation = _cameraOrientations[deviceOrientation];
    if (orientation == null) return null;
    final rotation =
        cameraDescription.lensDirection == CameraLensDirection.front
            ? (sensorOrientation + orientation) % 360
            : (sensorOrientation - orientation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotation);
  }
  return InputImageRotation.rotation0deg;
}

InputImageFormat? _inputImageFormat(CameraImage image) {
  final raw = image.format.raw;
  if (raw is int) {
    final format = InputImageFormatValue.fromRawValue(raw);
    if (format != null) return format;
  }
  return switch (image.format.group) {
    ImageFormatGroup.nv21 => InputImageFormat.nv21,
    ImageFormatGroup.bgra8888 => InputImageFormat.bgra8888,
    ImageFormatGroup.yuv420 => defaultTargetPlatform == TargetPlatform.iOS
        ? InputImageFormat.yuv420
        : InputImageFormat.yuv_420_888,
    _ => null,
  };
}

String? _cameraImageToJpegBase64(
  CameraImage cameraImage,
  CameraDescription cameraDescription,
  DeviceOrientation deviceOrientation,
) {
  final image = _cameraImageToRgbImage(cameraImage);
  if (image == null) return null;
  final rotation = _inputImageRotation(cameraDescription, deviceOrientation);
  final oriented = rotation == null || rotation.rawValue == 0
      ? image
      : img.copyRotate(image, angle: rotation.rawValue);
  final userFacing = _shouldMirrorFaceHorizontally(cameraDescription)
      ? img.copyFlip(oriented, direction: img.FlipDirection.horizontal)
      : oriented;
  final jpg = Uint8List.fromList(img.encodeJpg(userFacing, quality: 90));
  return base64Encode(jpg);
}

img.Image? _cameraImageToRgbImage(CameraImage cameraImage) {
  return switch (cameraImage.format.group) {
    ImageFormatGroup.bgra8888 => _bgra8888ToImage(cameraImage),
    ImageFormatGroup.nv21 => _nv21ToImage(cameraImage),
    ImageFormatGroup.yuv420 => _yuv420ToImage(cameraImage),
    _ => null,
  };
}

img.Image? _bgra8888ToImage(CameraImage cameraImage) {
  if (cameraImage.planes.isEmpty) return null;
  final plane = cameraImage.planes.first;
  final bytes = plane.bytes;
  final width = cameraImage.width;
  final height = cameraImage.height;
  final output = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final rowOffset = y * plane.bytesPerRow;
    for (var x = 0; x < width; x++) {
      final offset = rowOffset + x * 4;
      if (offset + 3 >= bytes.length) continue;
      output.setPixelRgba(
        x,
        y,
        bytes[offset + 2],
        bytes[offset + 1],
        bytes[offset],
        bytes[offset + 3],
      );
    }
  }
  return output;
}

img.Image? _nv21ToImage(CameraImage cameraImage) {
  if (cameraImage.planes.isEmpty) return null;
  final plane = cameraImage.planes.first;
  final bytes = plane.bytes;
  final width = cameraImage.width;
  final height = cameraImage.height;
  final rowStride = math.max(width, plane.bytesPerRow);
  final frameSize = rowStride * height;
  final output = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final yRow = y * rowStride;
    final uvRow = frameSize + (y >> 1) * rowStride;
    for (var x = 0; x < width; x++) {
      final yIndex = yRow + x;
      final uvIndex = uvRow + (x & ~1);
      if (yIndex >= bytes.length || uvIndex + 1 >= bytes.length) continue;
      final yy = bytes[yIndex] & 0xff;
      final vv = (bytes[uvIndex] & 0xff) - 128;
      final uu = (bytes[uvIndex + 1] & 0xff) - 128;
      output.setPixelRgb(
        x,
        y,
        _yuvToRed(yy, uu, vv),
        _yuvToGreen(yy, uu, vv),
        _yuvToBlue(yy, uu, vv),
      );
    }
  }
  return output;
}

img.Image? _yuv420ToImage(CameraImage cameraImage) {
  if (cameraImage.planes.length < 3) return null;
  final yPlane = cameraImage.planes[0];
  final uPlane = cameraImage.planes[1];
  final vPlane = cameraImage.planes[2];
  final width = cameraImage.width;
  final height = cameraImage.height;
  final output = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final yRow = y * yPlane.bytesPerRow;
    final uvRow = (y >> 1) * uPlane.bytesPerRow;
    for (var x = 0; x < width; x++) {
      final uvColumn = (x >> 1) * (uPlane.bytesPerPixel ?? 1);
      final yIndex = yRow + x;
      final uIndex = uvRow + uvColumn;
      final vIndex = (y >> 1) * vPlane.bytesPerRow +
          (x >> 1) * (vPlane.bytesPerPixel ?? 1);
      if (yIndex >= yPlane.bytes.length ||
          uIndex >= uPlane.bytes.length ||
          vIndex >= vPlane.bytes.length) {
        continue;
      }
      final yy = yPlane.bytes[yIndex] & 0xff;
      final uu = (uPlane.bytes[uIndex] & 0xff) - 128;
      final vv = (vPlane.bytes[vIndex] & 0xff) - 128;
      output.setPixelRgb(
        x,
        y,
        _yuvToRed(yy, uu, vv),
        _yuvToGreen(yy, uu, vv),
        _yuvToBlue(yy, uu, vv),
      );
    }
  }
  return output;
}

int _yuvToRed(int y, int u, int v) {
  return (y + 1.402 * v).round().clamp(0, 255);
}

int _yuvToGreen(int y, int u, int v) {
  return (y - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
}

int _yuvToBlue(int y, int u, int v) {
  return (y + 1.772 * u).round().clamp(0, 255);
}

class _CapturedDocumentImage {
  const _CapturedDocumentImage({
    required this.base64,
    required this.previewBytes,
  });

  final String base64;
  final Uint8List previewBytes;
}

Future<_CapturedDocumentImage> _captureDocumentImage({
  required CameraController camera,
  required Size previewSize,
  required _DocumentMaskSpec maskSpec,
  required bool isPortrait,
}) async {
  final file = await camera.takePicture();
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return _CapturedDocumentImage(
        base64: base64Encode(bytes), previewBytes: bytes);
  }
  final oriented = img.bakeOrientation(decoded);
  final frame = _calculateMaskFrame(previewSize, maskSpec, isPortrait);
  var left = ((frame.left / previewSize.width) * oriented.width).round();
  var top = ((frame.top / previewSize.height) * oriented.height).round();
  var width = ((frame.width / previewSize.width) * oriented.width).round();
  var height = ((frame.height / previewSize.height) * oriented.height).round();
  if (maskSpec.lowerHalfOnly) {
    top += height ~/ 2;
    height -= height ~/ 2;
  }
  left = left.clamp(0, oriented.width - 1);
  top = top.clamp(0, oriented.height - 1);
  width = width.clamp(2, oriented.width - left);
  height = height.clamp(2, oriented.height - top);
  final cropped = img.copyCrop(
    oriented,
    x: left,
    y: top,
    width: width,
    height: height,
  );
  final jpg = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  return _CapturedDocumentImage(base64: base64Encode(jpg), previewBytes: jpg);
}

class _CustomFieldOption {
  const _CustomFieldOption({required this.label, required this.value});

  final String label;
  final String value;
}

List<_CustomFieldOption> _parseCustomFieldOptions(String raw) {
  return raw
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
    final separator = line.contains(';')
        ? ';'
        : line.contains('\t')
            ? '\t'
            : line.contains('|')
                ? '|'
                : null;
    final parts =
        separator == null ? <String>[line, line] : line.split(separator);
    final label = parts.first.trim();
    final value = parts.length > 1 && parts[1].trim().isNotEmpty
        ? parts[1].trim()
        : label;
    return _CustomFieldOption(label: label, value: value);
  }).toList(growable: false);
}

String _cleanupContractHtml(String contractSource) {
  final cleaned = contractSource.replaceAll(
    RegExp(r'%\{[0-9A-Za-z_.\-]+\}'),
    '',
  );
  return cleaned.toLowerCase().contains('<html')
      ? cleaned
      : '''
<html>
  <head>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <style>
      body { font-family: -apple-system, Roboto, sans-serif; color: #111; padding: 12px; line-height: 1.45; }
      img[data-signature], div[data-signature] { display: none; }
    </style>
  </head>
  <body>$cleaned</body>
</html>
''';
}

String _injectContractSignatures(
  String contractSource,
  Map<String, String> signatures,
) {
  if (signatures.isEmpty) return contractSource;
  final tagRegex = RegExp(
    r'''<(?:img|div)\b[^>]*data-signature[^>]*>''',
    caseSensitive: false,
  );
  return contractSource.replaceAllMapped(tagRegex, (match) {
    final tag = match.group(0) ?? '';
    final uid = _htmlAttributeValue(tag, 'data-uid');
    final signature = uid == null ? null : signatures[uid]?.trim();
    if (signature == null || signature.isEmpty) return tag;

    if (RegExp(r'^<img\b', caseSensitive: false).hasMatch(tag)) {
      return _setHtmlAttribute(
        _setHtmlAttribute(tag, 'src', signature),
        'style',
        _mergeHtmlStyle(
          _htmlAttributeValue(tag, 'style') ?? '',
          'display:block;object-fit:contain',
        ),
      );
    }

    return '${_setHtmlAttribute(
      tag,
      'style',
      _mergeHtmlStyle(
        _htmlAttributeValue(tag, 'style') ?? '',
        'display:block',
      ),
    )}<img src="${_escapeHtmlAttribute(signature)}" alt="Signature" style="display:block;max-width:100%;height:auto;object-fit:contain" />';
  });
}

String? _htmlAttributeValue(String tag, String name) {
  final regex = RegExp(
    '''\\b${RegExp.escape(name)}\\s*=\\s*(["'])(.*?)\\1''',
    caseSensitive: false,
  );
  final value = regex.firstMatch(tag)?.group(2);
  return value
      ?.replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

String _setHtmlAttribute(String tag, String name, String value) {
  final regex = RegExp(
    '''\\b${RegExp.escape(name)}\\s*=\\s*(["'])(.*?)\\1''',
    caseSensitive: false,
  );
  final escaped = _escapeHtmlAttribute(value);
  if (regex.hasMatch(tag)) {
    return tag.replaceFirstMapped(regex, (match) {
      final quote = match.group(1) ?? '"';
      return '$name=$quote$escaped$quote';
    });
  }

  final insertIndex =
      tag.lastIndexOf('/>') >= 0 ? tag.lastIndexOf('/>') : tag.lastIndexOf('>');
  if (insertIndex < 0) return tag;
  return '${tag.substring(0, insertIndex)} $name="$escaped"${tag.substring(insertIndex)}';
}

String _mergeHtmlStyle(String current, String addition) {
  final base = current.trim();
  final next = addition.trim();
  if (base.isEmpty) return next;
  if (base.endsWith(';')) return '$base$next';
  return '$base;$next';
}

String _escapeHtmlAttribute(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

Future<String?> _createHandwrittenSignatureDataUrl(
  List<List<Offset>> strokes,
  Size size,
) async {
  final drawableStrokes =
      strokes.where((stroke) => stroke.isNotEmpty).toList(growable: false);
  if (drawableStrokes.isEmpty || size.width <= 0 || size.height <= 0) {
    return null;
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = Colors.white,
  );
  final strokeWidth = (size.height * 0.025).clamp(6.0, 16.0);
  final paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final dotPaint = Paint()..color = Colors.black;
  for (final stroke in drawableStrokes) {
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, strokeWidth / 2, dotPaint);
    } else {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return null;
  return 'data:image/png;base64,${base64Encode(byteData.buffer.asUint8List())}';
}
