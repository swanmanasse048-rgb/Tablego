import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantRegisterScreen extends StatefulWidget {
  const RestaurantRegisterScreen({super.key});

  @override
  State<RestaurantRegisterScreen> createState() =>
      _RestaurantRegisterScreenState();
}

class _RestaurantRegisterScreenState
    extends State<RestaurantRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;

  static const Color primaryColor = Color(0xFF6D1B2B);

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> registerRestaurantOwner() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'full_name': fullNameController.text.trim(),
          'phone': phoneController.text.trim(),
          'role': 'restaurant',
        },
      );

      final user = response.user;

      if (user == null) {
        throw Exception(
          "Le compte n'a pas pu être créé.",
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Compte restaurateur créé avec succès !",
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
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

  Widget buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Ce champ est obligatoire";
          }
          if (hint.contains("mot de passe") && value.trim().length < 6) {
            return "Minimum 6 caractères requis";
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryColor),
          suffixIcon: suffixIcon,
          hintText: hint,
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
        title: const Text("Compte restaurateur", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
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
                const SizedBox(height: 10),
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
                  "Rejoignez Savora",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Gérez votre établissement et vos offres facilement.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 25),

                // NOM
                buildField(
                  controller: fullNameController,
                  hint: "Nom du responsable",
                  icon: Icons.person_outline_rounded,
                ),

                // TÉLÉPHONE
                buildField(
                  controller: phoneController,
                  hint: "Téléphone",
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),

                // EMAIL
                buildField(
                  controller: emailController,
                  hint: "Email professionnel",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),

                // MOT DE PASSE (Unique avec option visibilité)
                buildField(
                  controller: passwordController,
                  hint: "Mot de passe (6 caractères min.)",
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : registerRestaurantOwner,
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
                            "Créer mon compte",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
}