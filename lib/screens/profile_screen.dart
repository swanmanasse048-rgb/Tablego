import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  bool isLoading = true;

  static const Color primaryColor = Color(0xFF6D1B2B);

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        profile = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // INFORMATION
  // ============================================================

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? "Non renseigné" : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F8F8),
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
        ),
      );
    }

    final user = supabase.auth.currentUser;

    final fullName =
        profile?["full_name"]?.toString() ?? "Utilisateur";

    final email =
        profile?["email"]?.toString() ??
        user?.email ??
        "";

    final phone =
        profile?["phone"]?.toString() ?? "";

    final role =
        profile?["role"]?.toString() ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Mon profil",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          25,
          20,
          30,
        ),
        children: [

          // ====================================================
          // HEADER PROFIL
          // ====================================================

          Center(
            child: Container(
              width: 105,
              height: 105,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Center(
            child: Text(
              fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Center(
            child: Text(
              email,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ROLE
          if (role.isNotEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role == "client"
                      ? "Client Savora"
                      : role,
                  style: const TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 35),

          // ====================================================
          // INFORMATIONS
          // ====================================================

          const Text(
            "Mes informations",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 14),

          _buildInfoCard(
            icon: Icons.person_outline,
            title: "Nom complet",
            value: fullName,
          ),

          _buildInfoCard(
            icon: Icons.email_outlined,
            title: "Adresse email",
            value: email,
          ),

          _buildInfoCard(
            icon: Icons.phone_outlined,
            title: "Téléphone",
            value: phone,
          ),

          _buildInfoCard(
            icon: Icons.badge_outlined,
            title: "Type de compte",
            value: role == "client"
                ? "Client"
                : role,
          ),

          const SizedBox(height: 18),

          // ====================================================
          // DÉCONNEXION
          // ====================================================

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withOpacity(0.15),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 5,
              ),
              leading: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
              ),
              title: const Text(
                "Se déconnecter",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                "Quitter votre compte Savora",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.red,
              ),
              onTap: logout,
            ),
          ),

          const SizedBox(height: 25),

          // ====================================================
          // VERSION
          // ====================================================

          Center(
            child: Text(
              "Savora",
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Center(
            child: Text(
              "Votre table, en quelques clics.",
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}