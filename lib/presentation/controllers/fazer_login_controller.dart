import 'package:flutter/material.dart';
import 'package:vision_app/presentation/pages/home/tela_home.dart';
import 'package:vision_app/presentation/widgets/loading_dialog.dart';
import 'package:vision_app/core/services/local_storage_service.dart';
import '../../core/services/auth_firebase_service.dart';
import '../../core/services/auth_backend_service.dart';
import '../../core/services/auth_token_service.dart';
import '../../core/services/keycloack_auth_service.dart';

Future<void> fazerLogin({
  required BuildContext context,
  required TextEditingController emailController,
  required TextEditingController senhaController,
  required void Function(String? cpfError, String? senhaError) setError,
}) async {
  showLoadingDialog(context, mensagem: 'Entrando...');

  try {
    final tokens = await KeycloackAuthService().login();
    if (tokens == null) {
      Navigator.pop(context); // Fecha o diálogo de carregamento
      setError('Erro ao fazer login', null);
      return;
    }

    await LocalStorageService().saveTokens(tokens);

    final perfil = await getUserProfile(tokens.accessToken);
    if (perfil == null) {
      Navigator.pop(context);
      setError('Não foi possivel obter o perfil', null);
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

}