import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String email = "";
  String role = "";

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHARGER LE PROFIL
  // ============================================================

  Future<void> loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      email = user.email ?? "";

      if (data != null) {
        role = data["role"]?.toString() ?? "Utilisateur";
        fullNameController.text = data["full_name"]?.toString() ?? "";
        phoneController.text = data["phone"]?.toString() ?? "";
      }
    } catch (e) {
      debugPrint("Erreur chargement profil : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de chargement du profil : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SAUVEGARDER LE PROFIL
  // ============================================================

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Utilisateur non connecté"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await Supabase.instance.client.from('profiles').update({
        "full_name": fullNameController.text.trim(),
        "phone": phoneController.text.trim(),
      }).eq("id", user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profil mis à jour avec succès ✅"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Erreur sauvegarde profil : $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la mise à jour : $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // DECONNEXION
  // ============================================================

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon profil"),
        backgroundColor: const Color(0xFF6D1B2B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: signOut,
            tooltip: "Se déconnecter",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 100,
                      color: Color(0xFF6D1B2B),
                    ),
                    const SizedBox(height: 20),

                    // NOM COMPLET
                    TextFormField(
                      controller: fullNameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Veuillez entrer votre nom complet";
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: "Nom complet",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // TELEPHONE
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Téléphone",
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // EMAIL (LECTURE SEULE)
                    ListTile(
                      leading: const Icon(Icons.email, color: Color(0xFF6D1B2B)),
                      title: const Text("Email"),
                      subtitle: Text(
                        email.isNotEmpty ? email : "Non renseigné",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    // RÔLE (LECTURE SEULE)
                    ListTile(
                      leading: const Icon(Icons.badge, color: Color(0xFF6D1B2B)),
                      title: const Text("Rôle"),
                      subtitle: Text(
                        role.isNotEmpty ? role : "Client",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // BOUTON ENREGISTRER
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D1B2B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Enregistrer",
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
    );
  }
}