
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:savora/services/notifications_service.dart';
import 'onboarding_restaurant.dart';
import '../screens/main_navigation.dart';
import 'package:savora/restaurant/restaurant_main_dashboard.dart';

class SplashRestaurant extends StatefulWidget {
  const SplashRestaurant({super.key});

  @override
  State<SplashRestaurant> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashRestaurant>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  @override
  void initState() {
    super.initState();

    // ============================================================
    // ÉCOUTEUR DE NOTIFICATIONS PUSH (TYPE WHATSAPP)
    // ============================================================
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        // Déclenche instantanément la vibration et la bannière locale
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
      begin: 0.75,
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
        MaterialPageRoute(
          builder: (_) => const OnboardingRestaurant(),
        ),
      );

      return;
    }

    // ------------------------------------------------------------
    // SESSION EXISTANTE
    // ------------------------------------------------------------

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OnboardingRestaurant(),
          ),
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

      final role =
          profileData?['role']
                  ?.toString()
                  .toLowerCase() ??
              'client';

      debugPrint(
        "Session existante : ${user.id}",
      );

      debugPrint(
        "Rôle utilisateur : $role",
      );

      if (!mounted) return;

      // ----------------------------------------------------------
      // RESTAURATEUR
      // ----------------------------------------------------------

      if (role == 'restaurant' || role == 'owner') {
        final restaurantData = await supabase
            .from('restaurants')
            .select('id, name, slug')
            .eq('owner_id', user.id)
            .maybeSingle();

        if (!mounted) return;

        // --------------------------------------------------------
        // AUCUN RESTAURANT ASSOCIÉ
        // --------------------------------------------------------

        if (restaurantData == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const OnboardingRestaurant(),
            ),
          );

          return;
        }

        final restaurantId =
            restaurantData['id'].toString();

        final restaurantName =
            restaurantData['name']
                    ?.toString() ??
                '';

        final restaurantSlug =
            restaurantData['slug']
                    ?.toString() ??
                '';

        // --------------------------------------------------------
        // DASHBOARD
        // --------------------------------------------------------

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RestaurantMainDashboard(
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigation(),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "Erreur vérification session : $e",
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const OnboardingRestaurant(),
        ),
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6D1B2B);

    return Scaffold(
      backgroundColor: primaryColor,

      body: Stack(
        children: [

          // ======================================================
          // DÉCORATION HAUT DROITE
          // ======================================================

          Positioned(
            top: -100,
            right: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.055),
              ),
            ),
          ),

          // ======================================================
          // DÉCORATION BAS GAUCHE
          // ======================================================

          Positioned(
            bottom: -120,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.045),
              ),
            ),
          ),

          // ======================================================
          // PETITS CERCLES
          // ======================================================

          Positioned(
            top: 130,
            left: 35,
            child: _decorativeCircle(8),
          ),

          Positioned(
            top: 190,
            right: 45,
            child: _decorativeCircle(5),
          ),

          Positioned(
            bottom: 180,
            right: 30,
            child: _decorativeCircle(7),
          ),

          // ======================================================
          // CONTENU
          // ======================================================

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [

                    // ==================================================
                    // LOGO
                    // ==================================================

                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.18),
                            blurRadius: 35,
                            offset:
                                const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Container(
                        margin:
                            const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius:
                              BorderRadius.circular(26),
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // NOM
                    // ==================================================

                    const Text(
                      "Savora Pro",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // SLOGAN
                    // ==================================================

                    Text(
                      "La gestion de votre restaurant,\n"
                      "simplifiée.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(0.82),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 38),

                    // ==================================================
                    // LOADING
                    // ==================================================

                    SizedBox(
                      width: 26,
                      height: 26,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                          Colors.white
                              .withOpacity(0.9),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      "Chargement...",
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ======================================================
          // FOOTER
          // ======================================================

          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "ESPACE PROFESSIONNEL",
                style: TextStyle(
                  color:
                      Colors.white.withOpacity(0.45),
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CERCLE DÉCORATIF
  // ============================================================

  Widget _decorativeCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        shape: BoxShape.circle,
      ),
    );
  }
}

