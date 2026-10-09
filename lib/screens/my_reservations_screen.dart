import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final Color primaryColor = const Color(0xFF6D1B2B);

  List<Map<String, dynamic>> reservations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadReservations();
  }

  // ============================================================
  // CHARGER MES RÉSERVATIONS (Avec toutes les infos globales)
  // ============================================================

  Future<void> loadReservations() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        reservations = [];
        isLoading = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final data = await Supabase.instance.client
          .from('reservations')
          .select('''
            *,
            restaurants (
              id,
              name,
              image_url
            ),
            tables (
              id,
              table_number,
              name,
              zone
            )
          ''')
          .eq('user_id', user.id)
          .order('reservation_date', ascending: false);

      if (!mounted) return;

      setState(() {
        reservations = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement réservations : $e");

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Impossible de charger vos réservations."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ============================================================
  // ANNULER UNE RÉSERVATION
  // ============================================================

  Future<void> cancelReservation(String reservationId) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({
            'status': 'cancelled',
          })
          .eq('id', reservationId);

      await loadReservations();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Réservation annulée avec succès"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Erreur annulation : $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Impossible d'annuler la réservation."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ============================================================
  // COULEUR DU STATUT
  // ============================================================

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "accepted":
        return Colors.green;

      case "rejected":
      case "cancelled":
        return Colors.red;

      case "pending":
      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // TEXTE DU STATUT
  // ============================================================

  String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case "accepted":
        return "Confirmée";

      case "rejected":
        return "Refusée";

      case "cancelled":
        return "Annulée";

      case "pending":
      default:
        return "En attente";
    }
  }

  // ============================================================
  // ICÔNE DU STATUT
  // ============================================================

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "accepted":
        return Icons.check_circle;

      case "rejected":
        return Icons.cancel;

      case "cancelled":
        return Icons.event_busy;

      case "pending":
      default:
        return Icons.access_time;
    }
  }

  // ============================================================
  // FORMATTER LA DATE
  // ============================================================

  String formatDate(String? date) {
    if (date == null || date.isEmpty) {
      return "Date inconnue";
    }

    try {
      final parsedDate = DateTime.parse(date);

      return "${parsedDate.day.toString().padLeft(2, '0')}/"
          "${parsedDate.month.toString().padLeft(2, '0')}/"
          "${parsedDate.year}";
    } catch (_) {
      return date;
    }
  }

  // ============================================================
  // IMAGE DU RESTAURANT
  // ============================================================

  Widget _buildRestaurantImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.restaurant,
          size: 32,
          color: Colors.grey.shade500,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey.shade200,
            child: Icon(
              Icons.restaurant,
              size: 32,
              color: Colors.grey.shade500,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BADGE STATUT
  // ============================================================

  Widget _buildStatusBadge(String status) {
    final color = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getStatusIcon(status),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            getStatusText(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LIGNE D'INFORMATION
  // ============================================================

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          "$label : ",
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARTE RÉSERVATION (Résumé Global)
  // ============================================================

  Widget _buildReservationCard(Map<String, dynamic> reservation) {
    final restaurant = reservation["restaurants"];
    final tableInfo = reservation["tables"];

    final String status = reservation["status"]?.toString() ?? "pending";

    final String restaurantName = restaurant is Map
        ? restaurant["name"]?.toString() ?? "Restaurant inconnu"
        : "Restaurant inconnu";

    final String imageUrl = restaurant is Map
        ? restaurant["image_url"]?.toString() ?? ""
        : "";

    final String date = reservation["reservation_date"]?.toString() ?? "";
    final String time = reservation["reservation_time"]?.toString() ?? "";
    final String guests = reservation["guests"]?.toString() ?? "1";
    
    // Récupération des nouveaux champs demandés
    final String clientName = reservation["client_name"]?.toString() ?? "";
    final String phone = reservation["phone"]?.toString() ?? "";
    final String specialRequest = reservation["special_request"]?.toString() ?? "";

    // Récupération propre du nom ou numéro de la table et de sa zone
    final String tableName = tableInfo is Map
        ? (tableInfo["name"] != null &&
                tableInfo["name"].toString().isNotEmpty
            ? "${tableInfo["name"]} (Table n°${tableInfo["table_number"] ?? '--'})"
            : "Table n°${tableInfo["table_number"] ?? '--'}")
        : "Non assignée";

    final String tableZone = tableInfo is Map && tableInfo["zone"] != null && tableInfo["zone"].toString().isNotEmpty
        ? " - Zone : ${tableInfo["zone"]}"
        : "";

    final bool canCancel = status.toLowerCase() == "pending";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entête : Image + Nom + Statut
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRestaurantImage(imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildStatusBadge(status),
                    ],
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF0F0F0)),
            ),

            // Détails globaux (Date, Heure, Table, Personnes, Contact, Demandes spéciales)
            Column(
              children: [
                _buildInfoRow(
                    Icons.calendar_today_outlined, "Date", formatDate(date)),
                const SizedBox(height: 8),
                _buildInfoRow(
                    Icons.access_time, "Heure", time.isNotEmpty ? time.substring(0, 5) : "--:--"),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.table_restaurant, "Table", "$tableName$tableZone"),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.people_outline, "Personnes",
                    "$guests personne${guests == "1" ? "" : "s"}"),
                
                // Affichage du nom du client si renseigné
                if (clientName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.person_outline, "Nom", clientName),
                ],

                // Affichage du téléphone si renseigné
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.phone_outlined, "Téléphone", phone),
                ],

                // Affichage des demandes spéciales / notes si présentes
                if (specialRequest.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.note_alt_outlined, "Notes", specialRequest),
                ],
              ],
            ),

            // Bouton Annuler si en attente
            if (canCancel) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _showCancelDialog(reservation["id"].toString());
                  },
                  child: const Text(
                    "Annuler la réservation",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ÉCRAN VIDE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucune réservation",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Vos futures réservations apparaîtront ici.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
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
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Mes réservations",
          style: TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(
          color: primaryColor,
        ),
        actions: [
          IconButton(
            tooltip: "Actualiser",
            icon: Icon(
              Icons.refresh,
              color: primaryColor,
            ),
            onPressed: isLoading ? null : loadReservations,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: loadReservations,
              child: reservations.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: reservations.length,
                      itemBuilder: (context, index) {
                        return _buildReservationCard(reservations[index]);
                      },
                    ),
            ),
    );
  }

  // ============================================================
  // DIALOGUE ANNULATION
  // ============================================================
  void _showCancelDialog(String reservationId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Annuler la réservation ?",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Voulez-vous vraiment annuler cette réservation ?",
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                "Non",
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await cancelReservation(reservationId);
              },
              child: const Text(
                "Oui, annuler",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}