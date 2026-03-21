import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

Map<String, dynamic>? extractFunctionArgsFromResponse(
  GenerateContentResponse response,
  String functionName,
) {
  for (final call in response.functionCalls) {
    if (call.name != functionName) continue;
    final normalized = <String, dynamic>{};
    call.args.forEach((key, value) {
      normalized[key] = value;
    });
    return normalized;
  }
  return null;
}

Map<String, dynamic>? extractJsonArgsFromText(String? text) {
  if (text == null || text.trim().isEmpty) return null;

  try {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) return null;
    final candidate = match.group(0);
    if (candidate == null) return null;

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
  }

  return null;
}
