import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vision_app/presentation/widgets/splash_screen.dart';
import 'package:face_camera/face_camera.dart'; 
import 'core/theme/app_theme.dart';
import 'package:flutter/services.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forçar orientação apenas para retrato (portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  


  // Inicialização do FaceCamera
  try {
    await FaceCamera.initialize();
  } catch (e) {
    if (kDebugMode) {
      print('Erro ao inicializar FaceCamera: $e');
    }
  }

  // Configuração do modo de interface do sistema
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Inicialização do aplicativo
  runApp(const VisionApp());
}

class VisionApp extends StatelessWidget {
  const VisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(),
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
    );
  }
}
