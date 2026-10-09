
import 'package:savora/screens/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'auth/login_screen.dart';


class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // Image de fond
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset(
              "lib/assets/images/onboarding.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // Dégradé
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black54,
                  Colors.black87,
                ],
              ),
            ),
          ),

          // Contenu
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Réservez votre table\nen quelques clics",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Découvrez les meilleurs restaurants et réservez facilement.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D1B2B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () {
                Navigator.push(
                    context,
                     MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                 ),
               );
                  },
                      child: const Text(
                        "Commencer",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Center(
                    child: TextButton(
                      onPressed: () {
          Navigator.push(
         context,
            MaterialPageRoute(
      builder: (context) => const LoginScreen(),
          ),
        );
         },
                      child: const Text(
                        "J'ai déjà un compte",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}