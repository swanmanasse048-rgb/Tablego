import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_restaurant_screen.dart';
import 'restaurant_main_dashboard.dart';
import 'restaurant_register_screen.dart'; // Import pour l'accès direct à l'inscription

class RestaurantLoginScreen extends StatefulWidget {
  const RestaurantLoginScreen({super.key});

  @override
  State<RestaurantLoginScreen> createState() =>
      _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState
    extends State<RestaurantLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  static const Color primaryColor = Color(0xFF6D1B2B);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginRestaurant() async {
    if (isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() {
      isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. CONNEXION SUPABASE AUTH
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Impossible de récupérer votre compte.");
      }

      // 2. RÉCUPÉRER LE PROFIL
      final profile = await supabase
          .from('profiles')
          .select('id, role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        await supabase.auth.signOut();
        throw Exception("Votre profil n'existe pas dans le système.");
      }

      final role = profile['role']?.toString();

      // 3. VÉRIFIER LE RÔLE
      if (role != 'restaurant' && role != 'owner') {
        await supabase.auth.signOut();
        throw Exception("Ce compte n'est pas un compte restaurateur.");
      }

      // 4. RÉCUPÉRER LE RESTAURANT
      final restaurant = await supabase
          .from('restaurants')
          .select('id, name, owner_id, slug')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (restaurant == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const CreateRestaurantScreen(),
          ),
        );
        return;
      }

      // 5. NAVIGATION VERS LE DASHBOARD
      final restaurantId = restaurant['id'].toString();
      final restaurantName = restaurant['name']?.toString() ?? '';
      final restaurantSlug = restaurant['slug']?.toString() ?? '';

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
    } on AuthException catch (e) {
      if (!mounted) return;
      String message = e.message;
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        message = "Email ou mot de passe incorrect.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur Supabase : ${e.message}"), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    Function(String)? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !isLoading,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: onSubmitted,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Ce champ est obligatoire";
          }
          if (label.contains("Email") && !value.contains('@')) {
            return "Veuillez entrer un email valide";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Connexion restaurateur", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Bon retour !",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Connectez-vous pour gérer votre établissement.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 30),

                // EMAIL
                buildField(
                  controller: emailController,
                  label: "Email professionnel",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),

                // MOT DE PASSE
                buildField(
                  controller: passwordController,
                  label: "Mot de passe",
                  icon: Icons.lock_outline_rounded,
                  obscure: obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                  ),
                  onSubmitted: (_) {
                    if (!isLoading) loginRestaurant();
                  },
                ),

                const SizedBox(height: 20),

                // BOUTON CONNEXION
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : loginRestaurant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "Se connecter",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // LIEN VERS INSCRIPTION SI PAS ENCORE DE COMPTE
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Pas encore de compte ? ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RestaurantRegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "S'inscrire",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}