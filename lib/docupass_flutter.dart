import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'src/docupass_result.dart';

export 'src/docupass_result.dart';

const String _viewType = 'com.idanalyzer.docupass/view';
const String _channelPrefix = 'com.idanalyzer.docupass/view_';

/// Drop-in DocuPass verification widget. Embeds the native Android/iOS DocuPass
/// SDK (true native camera + MediaPipe liveness — not a wrapped web page).
///
/// ```dart
/// DocuPassView(
///   reference: 'US…',                 // create server-side via POST /docupass
///   onResult: (r) => print(r.status), // completed | failed | cancelled | error
/// )
/// ```
class DocuPassView extends StatefulWidget {
  /// The DocuPass reference (create server-side via `POST /docupass`).
  final String reference;

  /// Optional party sign-token for multi-party contract flows.
  final String? partyId;

  /// Optional base URL override (on-prem ID Fort).
  final String? baseUrl;

  /// Terminal callback.
  final void Function(DocuPassResult result)? onResult;

  const DocuPassView({
    super.key,
    required this.reference,
    this.partyId,
    this.baseUrl,
    this.onResult,
  });

  @override
  State<DocuPassView> createState() => _DocuPassViewState();
}

class _DocuPassViewState extends State<DocuPassView> {
  MethodChannel? _channel;

  Map<String, dynamic> get _creationParams => {
        'reference': widget.reference,
        if (widget.partyId != null) 'partyId': widget.partyId,
        if (widget.baseUrl != null) 'baseUrl': widget.baseUrl,
      };

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('$_channelPrefix$id');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onResult') {
        widget.onResult?.call(DocuPassResult.fromMap(call.arguments as Map));
      }
      return null;
    });
    _channel = channel;
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: _viewType,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: _viewType,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
