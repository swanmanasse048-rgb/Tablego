import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FCMService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Demande la permission et enregistre le token FCM dans Supabase
  static Future<void> setupFCMToken() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Demander la permission
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Récupérer le token FCM
        String? token = await messaging.getToken();

        if (token != null) {
          // 3. Enregistrer dans la table `push_tokens` sur Supabase
          await _supabase.from('push_tokens').upsert(
            {
              'user_id': user.id,
              'token': token,
              'device_type': kIsWeb ? 'web' : 'mobile',
            },
            onConflict: 'user_id, token',
          );

          debugPrint("FCM Token enregistré avec succès : $token");
        }
      }

      // 4. Écouter le rafraîchissement automatique du token
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _supabase.from('push_tokens').upsert(
          {
            'user_id': user.id,
            'token': newToken,
            'device_type': kIsWeb ? 'web' : 'mobile',
          },
          onConflict: 'user_id, token',
        );
      });
    } catch (e) {
      debugPrint("Erreur lors de la configuration FCM Flutter : $e");
    }
  }
}