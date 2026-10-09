import 'package:flutter/material.dart';
import '../main_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;

  static const Color primaryColor = Color(0xFF6D1B2B);

  // ============================================================
  // INSCRIPTION
  // ============================================================

  Future<void> signUp() async {
  if (!_formKey.currentState!.validate()) return;

  if (passwordController.text != confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Les mots de passe ne correspondent pas"),
      ),
    );
    return;
  }

  setState(() => isLoading = true);

  try {
    // Transmettre les données personnalisées dans les métadonnées lors du signUp
    final response = await Supabase.instance.client.auth.signUp(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      data: {
        'full_name': fullNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': 'client',
      },
    );

    if (response.user != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Compte créé avec succès"),
          ),
        );

        Navigator.pop(context);
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
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
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: (value) {
          if (value == null || value.isEmpty) {
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
          prefixIcon: Container(
            margin: const EdgeInsets.only(
              left: 8,
              right: 8,
            ),
            child: Icon(
              icon,
              color: primaryColor,
            ),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: primaryColor,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Colors.red,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Créer un compte",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            22,
            10,
            22,
            30,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ==================================================
                // HEADER
                // ==================================================

                Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      size: 40,
                      color: primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Center(
                  child: Text(
                    "Bienvenue sur Savora",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    "Créez votre compte et commencez\nà découvrir les meilleurs restaurants.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ==================================================
                // INFORMATIONS PERSONNELLES
                // ==================================================

                const Text(
                  "Informations personnelles",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 14),

                buildField(
                  controller: fullNameController,
                  hint: "Nom complet",
                  icon: Icons.person_outline,
                ),

                buildField(
                  controller: phoneController,
                  hint: "Numéro de téléphone",
                  icon: Icons.phone_outlined,
                ),

                // ==================================================
                // COMPTE
                // ==================================================

                const SizedBox(height: 8),

                const Text(
                  "Informations du compte",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 14),

                buildField(
                  controller: emailController,
                  hint: "Adresse email",
                  icon: Icons.email_outlined,
                ),

                buildField(
                  controller: passwordController,
                  hint: "Mot de passe",
                  icon: Icons.lock_outline,
                  obscure: true,
                ),

                buildField(
                  controller: confirmPasswordController,
                  hint: "Confirmer le mot de passe",
                  icon: Icons.lock_reset_outlined,
                  obscure: true,
                ),

                const SizedBox(height: 8),

                // ==================================================
                // BOUTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor:
                          primaryColor.withOpacity(0.55),
                      elevation: 2,
                      shadowColor: primaryColor.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add_alt_1,
                                color: Colors.white,
                                size: 21,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Créer mon compte",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                // ==================================================
                // CONDITIONS
                // ==================================================

                Center(
                  child: Text(
                    "En créant un compte, vous acceptez les\n"
                    "conditions d'utilisation de Savora.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // CONNEXION
                // ==================================================

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainNavigation(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                    ),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: "Vous avez déjà un compte ? ",
                          ),
                          TextSpan(
                            text: "Se connecter",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}