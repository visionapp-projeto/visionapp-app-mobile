// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:vision_app/core/constants/app_colors.dart';
import 'package:vision_app/core/constants/app_texts.dart';
import 'package:vision_app/presentation/pages/login/tela_login.dart';
import 'package:vision_app/presentation/controllers/logout_controller.dart';
import '../../widgets/button.dart';



void mostrarDialogoLogout(BuildContext context) {
  // Mantemos uma referência ao contexto "raiz" (fora do diálogo)
  final rootContext = context;

  showDialog(
    context: rootContext,
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
                    style: Theme.of(context).textTheme.titleMedium,
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
                  // Fecha apenas o diálogo usando o contexto do diálogo
                  Navigator.of(dialogContext).pop();
                  // Usa o contexto raiz para navegar e limpar focos
                  FocusScope.of(rootContext).unfocus();
                  await fazerLogout(rootContext);
                },
              )
            ),
          ],
        ),
      ),
    ),
  );
}
