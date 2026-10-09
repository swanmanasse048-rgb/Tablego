import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:savora/services/notifications_service.dart';
import 'onboarding_screen.dart';
import '../screens/main_navigation.dart';
import 'package:savora/restaurant/restaurant_main_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // ============================================================
    // ÉCOUTEUR DE NOTIFICATIONS PUSH (PREMIER PLAN)
    // ============================================================
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        NotificationService.triggerLocalAlert(
          notification.title ?? "Nouvelle notification",
          notification.body ?? "",
        );
      }
    });

    // ============================================================
    // ANIMATION
    // ============================================================
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();

    // ============================================================
    // VÉRIFICATION SESSION
    // ============================================================
    Timer(
      const Duration(seconds: 2),
      _checkSession,
    );
  }

  // ============================================================
  // VÉRIFICATION DE LA SESSION
  // ============================================================
  Future<void> _checkSession() async {
    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    // ------------------------------------------------------------
    // AUCUNE SESSION
    // ------------------------------------------------------------
    if (session == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }

      // ----------------------------------------------------------
      // RÉCUPÉRER LE RÔLE
      // ----------------------------------------------------------
      final profileData = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = profileData?['role']?.toString().toLowerCase() ?? 'client';

      debugPrint("Session existante : ${user.id}");
      debugPrint("Rôle utilisateur : $role");

      if (!mounted) return;

      // ----------------------------------------------------------
      // RESTAURATEUR
      // ----------------------------------------------------------
      if (role == 'restaurant' || role == 'owner') {
        // Enregistrement du token FCM en arrière-plan
        await NotificationService.saveFcmTokenToDatabase();

        final restaurantData = await supabase
            .from('restaurants')
            .select('id, name, slug')
            .eq('owner_id', user.id)
            .maybeSingle();

        if (!mounted) return;

        if (restaurantData == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
          return;
        }

        final restaurantId = restaurantData['id'].toString();
        final restaurantName = restaurantData['name']?.toString() ?? '';
        final restaurantSlug = restaurantData['slug']?.toString() ?? '';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantMainDashboard(
              restaurantId: restaurantId,
              restaurantName: restaurantName,
              restaurantSlug: restaurantSlug,
            ),
          ),
        );
      }
      // ----------------------------------------------------------
      // CLIENT
      // ----------------------------------------------------------
      else {
        // Enregistrement du token FCM en arrière-plan
        await NotificationService.saveFcmTokenToDatabase();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      debugPrint("Erreur vérification session : $e");
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // INTERFACE ÉPURÉE ET FLUIDE
  // ============================================================
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6D1B2B);

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ==================================================
                  // LOGO ÉPURÉ
                  // ==================================================
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.table_bar_rounded,
                        color: primaryColor,
                        size: 46,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // NOM DE L'APPLICATION
                  // ==================================================
                  const Text(
                    "Savora",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ==================================================
                  // SLOGAN DISCRET
                  // ==================================================
                  Text(
                    "Découvrez. Réservez. Savourez.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ==================================================
                  // INDICATEUR DE CHARGEMENT FIN
                  // ==================================================
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}