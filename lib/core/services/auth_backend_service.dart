import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vision_app/core/constants/api_constants.dart';
import 'package:vision_app/core/services/auth_token_service.dart';

// -------- Helpers locais (apenas leitura do payload; assinatura é validada no backend)
Map<String, dynamic>? _decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

String? _matriculaFromToken(String accessToken) {
  final claims = _decodeJwtPayload(accessToken);
  final candidates = [
    'matricula',
    'matriculaServidor',
    'employeeId',
    'employeeID',
    'employee_number',
    'preferred_username', // às vezes vem aqui
  ];
  for (final k in candidates) {
    final v = claims?[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

// -------- Util: pegar valor por caminho "a.b.c"
dynamic _getByPath(Map<String, dynamic> map, String path) {
  dynamic cur = map;
  for (final part in path.split('.')) {
    if (cur is Map<String, dynamic> && cur.containsKey(part)) {
      cur = cur[part];
    } else {
      return null;
    }
  }
  return cur;
}

String? _firstNonEmptyStr(Map<String, dynamic> map, List<String> paths) {
  for (final p in paths) {
    final v = _getByPath(map, p);
    if (v == null) continue;
    final s = (v is String) ? v.trim() : v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

// -------- Normalizador: garante chaves padronizadas no Map
Map<String, dynamic> _normalizePerfil(
  Map<String, dynamic> raw, {
  String? tokenMatricula,
}) {
  final nome = _firstNonEmptyStr(raw, [
    'nome',
    'fullName',
    'name',
    'pessoa.nome',
    'usuario.nome',
    'dados.nome',
  ]);

  final cargo = _firstNonEmptyStr(raw, [
    'cargo',                  // direto
    'funcao',
    'role',
    'roleName',
    'lotacao.cargo.descricao',// aninhado comum
    'cargo.descricao',
    'dados.cargo',
  ]);

  final nivelClasse = _firstNonEmptyStr(raw, [
    'nivel_classe',
    'classe',
    'nivelClasse',
    'cargo.classe',
    'classe.nivel',
    'dados.nivel_classe',
  ]);

  final matricula = _firstNonEmptyStr(raw, [
    'matricula',
    'matriculaServidor',
    'registration',
    'employeeId',
    'employeeID',
    'servidor.matricula',
    'dados.matricula',
  ]) ?? tokenMatricula;

  // devolve o JSON ORIGINAL, enriquecido com as chaves padronizadas
  return {
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
  _AuthHttpClient(this.accessToken, [http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $accessToken';

    final matricula = _matriculaFromToken(accessToken);
    if (matricula != null && matricula.isNotEmpty) {
      // ajuste o nome do header se teu backend espera outro
      request.headers['X-Matricula'] = matricula;
    }
    return _inner.send(request);
  }
}

/// Mantém a MESMA assinatura usada no app: getUserProfile(tokens.accessToken)
Future<Map<String, dynamic>?> getUserProfile(String access_token) async {
  // Fallback defensivo
  var token = (access_token).trim();
  if (token.isEmpty) {
    final t = await AuthTokenService().getValidAccessToken();
    if (t == null) {
      if (kDebugMode) print('getUserProfile: sem token válido');
      return null;
    }
    token = t;
  }

  final uri = Uri.parse(ApiConstants.getuser);
  final client = _AuthHttpClient(token);

  try {
    final response = await client.get(uri);
    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      final tokenMat = _matriculaFromToken(token);
      final normalized = _normalizePerfil(raw, tokenMatricula: tokenMat);

      if (kDebugMode) {
        print('Perfil obtido (raw): ${response.body}');
        print('Perfil normalizado: $normalized');
      }

      return normalized; // já enriquecido com 'cargo', 'nivel_classe', 'matricula', 'nome'
    } else {
      if (kDebugMode) {
        print('Erro na requisição GET /usuario/perfil: '
            '${response.statusCode} → ${response.body}');
      }
      return null;
    }
  } catch (e) {
    if (kDebugMode) print('Exception no getUserProfile: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> getKeycloakUserInfo(String accessToken) async {
  final uri = Uri.parse('${keycloakConstants.issuer}/protocol/openid-connect/userinfo');
  try {
    final response = await http.get(
      uri,
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}
