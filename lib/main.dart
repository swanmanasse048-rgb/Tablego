import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:savora/screens/splah_screen.dart';
import 'package:savora/services/notifications_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

// 1. Déclare cette fonction en dehors de toute classe (niveau supérieur)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // S'assure que Firebase est initialisé en arrière-plan si nécessaire
  await Firebase.initializeApp();
  print("Notification reçue en arrière-plan : ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Initialisation de Firebase pour les notifications Push distantes
  await Firebase.initializeApp();

  // 0.5. Enregistrement du handler d'arrière-plan (INDISPENSABLE quand l'app est fermée)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 1. Initialisation de Supabase
  await Supabase.initialize(
    url: 'https://aexbtrgitskffsxuntca.supabase.co',
    publishableKey:
        'sb_publishable_ZZupjkQpIgob70aewgsjmQ_4hQkJAf1',
  );

  // 2. Initialisation des notifications locales et vibrations
  await NotificationService.init();

  runApp(const TableGO());
}

class TableGO extends StatelessWidget {
  const TableGO({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Savora',
      home: const SplashScreen(),
    );
  }
}