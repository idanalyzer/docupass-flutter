import 'package:docupass_flutter/docupass_flutter.dart';
import 'package:flutter/material.dart';

const String _defaultReference = '';

void main() {
  runApp(const DocuPassExampleApp());
}

class DocuPassExampleApp extends StatelessWidget {
  const DocuPassExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FFAB),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050A08),
        useMaterial3: true,
      ),
      home: const DocuPassExampleHome(),
    );
  }
}

class DocuPassExampleHome extends StatefulWidget {
  const DocuPassExampleHome({super.key});

  @override
  State<DocuPassExampleHome> createState() => _DocuPassExampleHomeState();
}

class _DocuPassExampleHomeState extends State<DocuPassExampleHome> {
  final TextEditingController _referenceController = TextEditingController(
    text: _defaultReference,
  );
  bool _started = false;
  bool _localDemo = false;
  DocuPassResult? _lastResult;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reference = _referenceController.text.trim();
    final activeReference = _localDemo ? 'LOCAL-DEMO' : reference;

    if (_started && activeReference.isNotEmpty) {
      return Scaffold(
        body: SafeArea(
          top: false,
          bottom: false,
          child: DocuPassView(
            reference: activeReference,
            enabled: !_localDemo,
            onBackAtFirstStep: () {
              setState(() => _started = false);
            },
            onResult: (result) {
              setState(() {
                _lastResult = result;
                _started = false;
              });
            },
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'DocuPass KYC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter a DocuPass reference to start the Flutter verification flow.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'DocuPass reference',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: reference.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _lastResult = null;
                          _localDemo = false;
                          _started = true;
                        });
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFF00FFAB),
                  foregroundColor: const Color(0xFF052017),
                ),
                child: const Text('Start KYC'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _lastResult = null;
                    _localDemo = true;
                    _started = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.38)),
                ),
                child: const Text('Start local camera demo'),
              ),
              if (_lastResult != null) ...<Widget>[
                const SizedBox(height: 22),
                _ResultSummary(result: _lastResult!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.result});

  final DocuPassResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.status) {
      DocuPassStatus.completed => const Color(0xFF00FFAB),
      DocuPassStatus.failed => const Color(0xFFFFA3A3),
      DocuPassStatus.cancelled => Colors.white70,
      DocuPassStatus.unknown => Colors.white70,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Last result: ${result.status.name}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (result.sessionId != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Session: ${result.sessionId}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (result.error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              result.error!.toDisplayMessage(),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}
