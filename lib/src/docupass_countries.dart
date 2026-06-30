import 'dart:convert';

import 'package:http/http.dart' as http;

import 'docupass_models.dart';

const String docupassCountryUrl = 'https://v.idanalyzer.com/asset/country.json';

Future<List<DocupassCountry>> fetchDocupassCountries(
  List<String>? filterCodes, {
  http.Client? client,
}) async {
  final ownsClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient.get(
      Uri.parse(docupassCountryUrl).replace(
        queryParameters: <String, String>{
          'ts': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      },
    );
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception(
          'Unable to load countries (HTTP ${response.statusCode}).');
    }

    final payload = jsonDecode(response.body);
    if (payload is! List) {
      throw Exception('Country service returned an invalid response.');
    }

    final allowedCodes = filterCodes
        ?.map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final countries = <String, DocupassCountry>{};

    for (final item in payload) {
      final map = asStringKeyedMap(item);
      if (map == null) continue;
      final code = map.stringValue('iso').trim().toUpperCase();
      final name = map.stringValue('name_en').trim();
      if (code.isEmpty ||
          name.isEmpty ||
          countries.containsKey(code) ||
          (allowedCodes != null &&
              allowedCodes.isNotEmpty &&
              !allowedCodes.contains(code))) {
        continue;
      }
      countries[code] = DocupassCountry(code: code, name: name);
    }

    if (countries.isEmpty) {
      throw Exception('Country service returned no available countries.');
    }

    return countries.values.toList(growable: false)
      ..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}
