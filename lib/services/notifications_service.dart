import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 👉 Ne pas oublier cet import
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialisation (à appeler dans main.dart)
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    // Création du canal de notification pour Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'savora_channel_id',
      'Savora Notifications',
      description: 'Notifications en temps réel pour Savora',
      importance: Importance.max,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 👉 1. Quand un client réserve (Enregistre l'alerte pour le restaurant dans Supabase)
  static Future<void> notifyRestaurantNewReservation({
    required String restaurantId,
    required String reservationId,
    required String clientName,
    required String reservationDate,
    required String reservationTime,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('notifications').insert({
        'restaurant_id': restaurantId,
        'title': 'Nouvelle réservation 🍽️',
        'message': '$clientName a réservé pour le $reservationDate à $reservationTime.',
        'type': 'new_reservation',
        'reference_id': reservationId,
        'is_read': false,
      });
    } catch (e) {
      debugPrint("Erreur notif restaurant : $e");
    }
  }

  // 👉 2. Quand le restaurant accepte ou refuse (Enregistre l'alerte pour le client dans Supabase)
  static Future<void> notifyClientReservationStatus({
    required String clientId,
    required String reservationId,
    required String restaurantName,
    required bool isAccepted,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final title = isAccepted ? 'Réservation acceptée ✅' : 'Réservation refusée ❌';
      final message = isAccepted
          ? 'Votre réservation au restaurant $restaurantName a été acceptée !'
          : 'Désolé, votre réservation au restaurant $restaurantName a été refusée.';

      await supabase.from('notifications').insert({
        'user_id': clientId, // Stocké pour le client
        'title': title,
        'message': message,
        'type': isAccepted ? 'reservation_accepted' : 'reservation_refused',
        'reference_id': reservationId,
        'is_read': false,
      });
    } catch (e) {
      debugPrint("Erreur notif client : $e");
    }
  }

  // Méthode interne pour la vibration et la bannière (disponible pour les écouteurs en temps réel)
  static Future<void> triggerLocalAlert(String title, String body) async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 1000);
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'savora_channel_id',
        'Savora Notifications',
        channelDescription: 'Notifications en temps réel pour Savora',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Erreur vibration/notification locale : $e');
    }
  }

  // 👉 3. Enregistrement et mise à jour du token FCM pour les pushs en arrière-plan
  static Future<void> saveFcmTokenToDatabase() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return;

      // Demander la permission d'afficher des notifications (Android 13+ / iOS)
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint("Permission de notification refusée par l'utilisateur.");
        return;
      }

      // Récupérer le token unique FCM de l'appareil
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      // Sauvegarder ou mettre à jour dans la table push_tokens
      await supabase.from('push_tokens').upsert({
        'user_id': user.id,
        'token': fcmToken,
        'device_type': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      }, onConflict: 'user_id, token');

      debugPrint("Token FCM enregistré avec succès : $fcmToken");

      // Écouter si le token change (réinstallation, rafraîchissement)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final currentUser = supabase.auth.currentUser;
        if (currentUser == null) return;

        await supabase.from('push_tokens').upsert({
          'user_id': currentUser.id,
          'token': newToken,
          'device_type': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        }, onConflict: 'user_id, token');
      });
    } catch (e) {
      debugPrint("Erreur lors de l'enregistrement du token FCM : $e");
    }
  }
}