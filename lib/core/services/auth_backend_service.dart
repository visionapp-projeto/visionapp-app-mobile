import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vision_app/core/constants/api_constants.dart';
import 'package:vision_app/core/services/auth_token_service.dart';

// -------- Helpers locais (apenas leitura do payload; assinatura é validada no backend)
Map<String, dynamic>? _decodeJwtPayload(final String token) {
  final List<String> parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final String payload =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return jsonDecode(payload) as Map<String, dynamic>;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('Formato inválido ao decodificar JWT: $e');
    return null;
  } on Exception catch (e) {
    if (kDebugMode) debugPrint('Falha ao decodificar payload do JWT: $e');
    return null;
  }
}
String? _matriculaFromToken(final String accessToken) {
  final Map<String, dynamic>? claims = _decodeJwtPayload(accessToken);
  if (claims == null) return null;

  const List<String> candidates = <String>[
    'matricula',
    'matriculaServidor',
    'employeeId',
    'employeeID',
    'employee_number',
    'preferred_username',
  ];

  for (final String k in candidates) {
    final Object? v = claims[k];
    if (v == null) continue;
    final String s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

// -------- Util: pegar valor por caminho "a.b.c"
Object? _getByPath(final Map<String, dynamic> map, final String path) {
  Object? cur = map;
  for (final String part in path.split('.')) {
    if (cur is Map<String, dynamic> && cur.containsKey(part)) {
      cur = cur[part];
    } else {
      return null;
    }
  }
  return cur;
}

String? _firstNonEmptyStr(final Map<String, dynamic> map, final List<String> paths) {
  for (final String p in paths) {
    final Object? v = _getByPath(map, p);
    if (v == null) continue;
    final String s = (v is String) ? v.trim() : v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

// -------- Normalizador: garante chaves padronizadas no Map
Map<String, dynamic> _normalizePerfil(
  final Map<String, dynamic> raw, {
  final String? tokenMatricula,
}) {
  final String? nome = _firstNonEmptyStr(raw, <String>[
    'nome',
    'fullName',
    'name',
    'pessoa.nome',
    'usuario.nome',
    'dados.nome',
  ]);

  final String? cargo = _firstNonEmptyStr(raw, <String>[
    'cargo',
    'funcao',
    'role',
    'roleName',
    'lotacao.cargo.descricao',
    'cargo.descricao',
    'dados.cargo',
  ]);

  final String? nivelClasse = _firstNonEmptyStr(raw, <String>[
    'nivel_classe',
    'classe',
    'nivelClasse',
    'cargo.classe',
    'classe.nivel',
    'dados.nivel_classe',
  ]);

  final String? matricula = _firstNonEmptyStr(raw, <String>[
    'matricula',
    'matriculaServidor',
    'registration',
    'employeeId',
    'employeeID',
    'servidor.matricula',
    'dados.matricula',
  ]) ?? tokenMatricula;

  return <String, dynamic>{
    ...raw,
    if (nome != null) 'nome': nome,
    if (cargo != null) 'cargo': cargo,
    if (nivelClasse != null) 'nivel_classe': nivelClasse,
    if (matricula != null) 'matricula': matricula,
  };
}

// -------- Cliente HTTP que sempre manda Bearer + X-Matricula
class _AuthHttpClient extends http.BaseClient {
  final String accessToken;
  final http.Client _inner;

  _AuthHttpClient(final String accessToken, [http.Client? inner])
      : accessToken = accessToken,
        _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $accessToken';

    final String? matricula = _matriculaFromToken(accessToken);
    if (matricula != null && matricula.isNotEmpty) {
      request.headers['X-Matricula'] = matricula; // ajuste se o backend esperar outro header
    }
    return _inner.send(request);
  }
}

/// Mantém a MESMA assinatura usada no app: getUserProfile(tokens.accessToken)
Future<Map<String, dynamic>?> getUserProfile(final String access_token) async {
  // Fallback defensivo
  String token = access_token.trim();
  if (token.isEmpty) {
    final String? t = await AuthTokenService().getValidAccessToken();
    if (t == null) {
      if (kDebugMode) debugPrint('getUserProfile: sem token válido');
      return null;
    }
    token = t;
  }

  final Uri uri = Uri.parse(ApiConstants.getuser);
  final _AuthHttpClient client = _AuthHttpClient(token);

  try {
    final http.Response response =
        await client.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final Map<String, dynamic> raw =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String? tokenMat = _matriculaFromToken(token);
      final Map<String, dynamic> normalized =
          _normalizePerfil(raw, tokenMatricula: tokenMat);

      if (kDebugMode) {
        debugPrint('Perfil obtido (raw): ${response.body}');
        debugPrint('Perfil normalizado: $normalized');
      }
      return normalized;
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
  } on Exception catch (e) {
    if (kDebugMode) debugPrint('Exception no getUserProfile: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> getKeycloakUserInfo(final String accessToken) async {
  final Uri uri =
      Uri.parse('${keycloakConstants.issuer}/protocol/openid-connect/userinfo');
  try {
    final http.Response response = await http
        .get(
          uri,
          headers: const <String, String>{
            'accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      return null;
    }
  } on TimeoutException {
    if (kDebugMode) debugPrint('Timeout no GET /userinfo');
    return null;
  } on http.ClientException catch (e) {
    if (kDebugMode) debugPrint('HTTP client error: $e');
    return null;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('JSON inválido em /userinfo: $e');
    return null;
  } on Exception catch (e) {
    if (kDebugMode) debugPrint('Exception em getKeycloakUserInfo: $e');
    return null;
  }
}
