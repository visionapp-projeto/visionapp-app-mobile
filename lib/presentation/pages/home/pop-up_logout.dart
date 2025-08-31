// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:vision_app/core/constants/app_colors.dart';
import 'package:vision_app/core/constants/app_texts.dart';
// NÃO navegue aqui: o controller fará isso após limpar tudo
import 'package:vision_app/presentation/controllers/logout_controller.dart';
import '../../widgets/button.dart';

void mostrarDialogoLogout(BuildContext parentContext) {
  showDialog(
    context: parentContext,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: ColorPalette.branco,
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botão de fechar alinhado à direita
            Stack(
              children: [
                Center(
                  child: Text(
                    StandardTexts.popupLogoutTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(parentContext).textTheme.titleMedium,
                  ),
                ),
                Positioned(
                  top: -15,
                  right: -17,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 28, color: ColorPalette.cinzaMedio),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    splashRadius: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            const SizedBox(height: 18),
            const Text(
              StandardTexts.popupLogoutMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: ColorPalette.preto,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              child: Button(
                text: StandardTexts.popupLogoutButton,
                backgroundColor: ColorPalette.vermelhoPaleta,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: ColorPalette.branco,
                ),
                onPressed: () async {
                  // fecha o diálogo antes de navegar/limpar
                  Navigator.of(dialogContext).pop();
                  // garante que o teclado feche (caso aberto)
                  FocusScope.of(parentContext).unfocus();
                  // limpa tokens + cache + sessão Keycloak e navega para Login
                  await fazerLogout(parentContext);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
