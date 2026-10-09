import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  static const Color primaryColor = Color(0xFF6D1B2B);

  // ============================================================
  // CONNEXION
  // ============================================================

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response =
          await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = response.user;

      if (user == null) {
        throw Exception("Impossible de récupérer le compte.");
      }

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final String role =
          profileData?['role']?.toString().toLowerCase() ?? 'client';

      debugPrint("Utilisateur connecté : ${user.id}");
      debugPrint("Rôle : $role");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connexion réussie"),
          backgroundColor: Colors.green,
        ),
      );

      if (role == 'restaurant' || role == 'owner') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>  Container(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigation(),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // CHAMP
  // ============================================================

  Widget buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        obscureText: obscure && obscurePassword,
        keyboardType: obscure
            ? TextInputType.text
            : TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Champ obligatoire";
          }

          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            icon,
            color: primaryColor,
          ),
          suffixIcon: obscure
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: primaryColor,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.red,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  24,
                  22,
                  24,
                  38,
                ),
                decoration: const BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(38),
                    bottomRight: Radius.circular(38),
                  ),
                ),
                child: Column(
                  children: [
                    // Bouton retour
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: isLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Logo
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        size: 42,
                        color: primaryColor,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Bienvenue sur Savora",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Réservez votre table en toute simplicité.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // FORMULAIRE
              // ==================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  30,
                  24,
                  25,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Se connecter",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        "Accédez à votre compte Savora",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 27),

                      // EMAIL
                      const Text(
                        "Adresse e-mail",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 8),

                      buildField(
                        controller: emailController,
                        hint: "exemple@email.com",
                        icon: Icons.email_outlined,
                      ),

                      // MOT DE PASSE
                      const Text(
                        "Mot de passe",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 8),

                      buildField(
                        controller: passwordController,
                        hint: "Votre mot de passe",
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),

                      const SizedBox(height: 7),

                      // BOUTON
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            disabledBackgroundColor:
                                primaryColor.withOpacity(0.55),
                            elevation: 2,
                            shadowColor: primaryColor.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Se connecter",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 21,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // SEPARATEUR
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child: Text(
                              "ou",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // CREER UN COMPTE
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  Navigator.pop(context);
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: const BorderSide(
                              color: primaryColor,
                              width: 1.3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Créer un compte",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // TEXTE BAS
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_outlined,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Votre table, votre moment.",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}