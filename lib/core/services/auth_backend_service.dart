import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vision_app/core/constants/api_constants.dart';

// -------- Helper local: lê APENAS o payload do JWT (sem validar assinatura)
Map<String, dynamic>? _decodeJwtPayload(final String token) {
  final List<String> parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final String normalized = base64Url.normalize(parts[1]);
    final List<int> bytes = base64Url.decode(normalized);
    final String jsonStr = utf8.decode(bytes);
    final Map<String, dynamic> payload =
        jsonDecode(jsonStr) as Map<String, dynamic>;
    return payload;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('Formato inválido ao decodificar JWT: $e');
    return null;
  } on ArgumentError catch (e) {
    if (kDebugMode) debugPrint('Segmento base64 inválido: $e');
    return null;
  }
}

/// Extrai a matrícula de um JWT do backend (se existir no payload)
String? _matriculaFromToken(final String accessToken) {
  final Map<String, dynamic>? claims = _decodeJwtPayload(accessToken);
  if (claims == null) return null;

  // chaves possíveis onde a matrícula pode vir do backend
  const List<String> candidateKeys = <String>['matricula', 'mat', 'registration'];

  for (final String key in candidateKeys) {
    final Object? value = claims[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }
  return null;
}

/// Envia o Firebase ID token e retorna o JWT do back-end
Future<String?> postWithToken(final String firebaseToken) async {
  // OBS: hoje o token vai na URL. Idealmente mover para cabeçalho/JSON.
  final Uri uri = Uri.parse('${ApiConstants.token}$firebaseToken');

  try {
    final http.Response response = await http
        .post(
          uri,
          headers: const {'accept': 'application/json'},
          // body omitido; enviar '' é desnecessário
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint(
          'Erro POST (${response.statusCode}): ${response.body}',
        );
      }
      return null;
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (kDebugMode) debugPrint('POST /auth/firebase retornou: $data');

    final String? accessToken = data['access_token'] as String?;
    if (kDebugMode) debugPrint('accessToken="$accessToken"');
    return accessToken;
  } on TimeoutException {
    if (kDebugMode) debugPrint('Timeout ao chamar POST /auth/firebase');
    return null;
  } on http.ClientException catch (e) {
    if (kDebugMode) debugPrint('HTTP client error: $e');
    return null;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('JSON inválido na resposta: $e');
    return null;
  } catch (e) {
    if (kDebugMode) debugPrint('Erro inesperado no POST: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> getUserProfile(final String backendJwt) async {
  final Uri uri = Uri.parse(ApiConstants.getuser);

  try {
    final http.Response response = await http
        .get(
          uri,
          headers: <String, String>{
            'accept': 'application/json',
            'Authorization': 'Bearer $backendJwt',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      if (kDebugMode) debugPrint('Perfil obtido!: ${response.body}');
      final Map<String, dynamic> map =
          jsonDecode(response.body) as Map<String, dynamic>;
      return map;
    } else {
      if (kDebugMode) {
        debugPrint(
          'Erro GET /usuario/perfil: ${response.statusCode} → ${response.body}',
        );
      }
      return null;
    }
  } on TimeoutException {
    if (kDebugMode) debugPrint('Timeout no GET /usuario/perfil');
    return null;
  } on http.ClientException catch (e) {
    if (kDebugMode) debugPrint('HTTP client error: $e');
    return null;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('JSON inválido no perfil: $e');
    return null;
  } catch (e) {
    if (kDebugMode) debugPrint('Exception no getUserProfile: $e');
    return null;
  }
}
