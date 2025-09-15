// lib/presentation/controllers/fazer_login_controller.dart
import 'package:flutter/material.dart';
import 'package:vision_app/presentation/pages/home/tela_home.dart';
import 'package:vision_app/presentation/widgets/loading_dialog.dart';
import 'package:vision_app/core/services/local_storage_service.dart';
import 'package:vision_app/core/services/auth_token_service.dart'; // <— ADICIONE ISTO
import '../../core/services/auth_backend_service.dart';
import '../../core/services/keycloack_auth_service.dart';

class _LoginGuard {
  static bool inProgress = false;
}

Future<void> fazerLogin({
  required BuildContext context,
}) async {
  if (_LoginGuard.inProgress) return;
  _LoginGuard.inProgress = true;

  showLoadingDialog(context, mensagem: 'Entrando...');

  try {
    final tokens = await KeycloakAuthService().login();
    if (tokens == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao fazer login. Tente novamente.')),
      );
      return;
    }

    // Persiste tokens
    await LocalStorageService().saveTokens(tokens);

    // Alinha cache em memória para a sessão nova
    AuthTokenService().setInMemoryToken(tokens.accessToken);

    // Busca perfil (seu código como já estava)
    Map<String, dynamic>? perfil = await getUserProfile(tokens.accessToken);
    if (perfil == null) {
      final kcInfo = await getKeycloakUserInfo(tokens.accessToken);
      if (kcInfo != null) {
        perfil = {
          'name': kcInfo['name'] ?? kcInfo['preferred_username'] ?? 'Usuário',
          'cargo': kcInfo['cargo'] ?? 'Cargo não informado',
          'classe': kcInfo['classe'] ?? 'Classe não informada',
          'matricula': kcInfo['matricula'] ?? kcInfo['preferred_username'] ?? '',
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
      SnackBar(content: Text('Erro ao fazer login: $e')),
    );
  } finally {
    _LoginGuard.inProgress = false;
  }
}
