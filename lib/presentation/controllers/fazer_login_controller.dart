import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vision_app/presentation/pages/home/tela_home.dart';
import 'package:vision_app/presentation/widgets/loading_dialog.dart';
import 'package:vision_app/core/services/local_storage_service.dart';
import '../../core/services/auth_firebase_service.dart';
import '../../core/services/auth_backend_service.dart';
import '../../core/services/auth_token_service.dart';
import '../../core/services/keycloack_auth_service.dart';

class _LoginGuard {
  static bool inProgress = false;
}

Future<void> fazerLogin({
  required BuildContext context,
  required TextEditingController emailController,
  required TextEditingController senhaController,
  required void Function(String? cpfError, String? senhaError) setError,
}) async {
  if (_LoginGuard.inProgress) {
    if (kDebugMode) debugPrint('[LOGIN] tentativa ignorada: já em andamento');
    return;
  }
  _LoginGuard.inProgress = true;

  showLoadingDialog(context, mensagem: 'Entrando...');

  try {
    final tokens = await KeycloakAuthService().login();
    if (tokens == null) {
      if (kDebugMode) debugPrint('[LOGIN] tokens == null (login falhou)');
      Navigator.pop(context); // Fecha o diálogo de carregamento
      setError('Erro ao fazer login', null);
      return;
    }

    await LocalStorageService().saveTokens(tokens);
    if (kDebugMode) debugPrint('[LOGIN] tokens salvos. Chamando getUserProfile...');

    Map<String, dynamic>? perfil = await getUserProfile(tokens.accessToken);
    if (kDebugMode) debugPrint('[LOGIN] perfil.ok=${perfil != null}');
    // Fallback: tenta pegar dados do usuário direto do Keycloak para permitir navegação
    if (perfil == null) {
      if (kDebugMode) debugPrint('[LOGIN] tentando userinfo do Keycloak como fallback...');
      final kcInfo = await getKeycloakUserInfo(tokens.accessToken);
      if (kcInfo != null) {
        perfil = {
          'nome': kcInfo['name'] ?? kcInfo['preferred_username'] ?? 'Usuário',
          'cargo': 'Cargo não informado',
          'nivel_classe': 'Classe não informada',
          'matricula': kcInfo['preferred_username'] ?? '',
        };
      }
    }
    if (perfil == null) {
      Navigator.pop(context);
      setError('Não foi possível obter o perfil.', null);
      return;
    }

    Navigator.pop(context);
    FocusScope.of(context).unfocus();
    if (kDebugMode) debugPrint('[LOGIN] navegando → Home');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => TelaHome(perfil: perfil)),
      (route) => false,
    );

  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro ao fazer login: $e'),
      ),
    );

  }
  finally {
    _LoginGuard.inProgress = false;
  }
}
