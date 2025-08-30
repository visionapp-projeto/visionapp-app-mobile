import 'package:flutter/material.dart';
import 'package:vision_app/presentation/pages/home/tela_home.dart';
import 'package:vision_app/presentation/widgets/loading_dialog.dart';
import 'package:vision_app/core/services/local_storage_service.dart';

import '../../core/services/auth_backend_service.dart';

import '../../core/services/keycloack_auth_service.dart';

class _LoginGuard {
  static bool inProgress = false;
}

Future<void> fazerLogin({
  required BuildContext context,
}) async {
  if (_LoginGuard.inProgress) {
    return;
  }
  _LoginGuard.inProgress = true;

  showLoadingDialog(context, mensagem: 'Entrando...');

  try {
    final tokens = await KeycloakAuthService().login();
    if (tokens == null) {
      Navigator.pop(context); // Fecha o diálogo de carregamento
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao fazer login. Tente novamente.')),
      );
      return;
    }

    await LocalStorageService().saveTokens(tokens);

    Map<String, dynamic>? perfil = await getUserProfile(tokens.accessToken);
    // Fallback: tenta pegar dados do usuário direto do Keycloak para permitir navegação
    if (perfil == null) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter o perfil.')),
      );
      return;
    }

    Navigator.pop(context);
    FocusScope.of(context).unfocus();
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
