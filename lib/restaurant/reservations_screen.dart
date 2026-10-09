import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationsScreen extends StatefulWidget {
  final String restaurantId;

  const ReservationsScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  List<Map<String, dynamic>> reservations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadReservations();
  }

  // ============================================================
  // CHARGER LES RÉSERVATIONS
  // ============================================================

  Future<void> loadReservations() async {
    try {
      final data = await Supabase.instance.client
          .from('reservations')
          .select('''
            *,
            profiles(full_name)
          ''')
          .eq('restaurant_id', widget.restaurantId)
          .order('reservation_date', ascending: true);

      if (!mounted) return;

      setState(() {
        reservations = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement réservations : $e");
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CHANGER LE STATUT
  // ============================================================

  Future<void> updateStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'status': status})
          .eq('id', id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Statut mis à jour en : ${statusLabel(status)}"),
          backgroundColor: Colors.green,
        ),
      );

      await loadReservations();
    } catch (e) {
      debugPrint("Erreur mise à jour statut : $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur de modification : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // COULEURS ET TRADUCTIONS DES STATUTS
  // ============================================================

  Color statusColor(String status) {
    switch (status) {
      case "accepted":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "cancelled":
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case "accepted":
        return "Acceptée";
      case "rejected":
        return "Refusée";
      case "cancelled":
        return "Annulée";
      default:
        return "En attente";
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Réservations"),
        backgroundColor: const Color(0xFF6D1B2B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadReservations,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadReservations,
              child: reservations.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 150),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 70,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 15),
                              Text(
                                "Aucune réservation",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: reservations.length,
                      itemBuilder: (context, index) {
                        final reservation = reservations[index];
                        final String status =
                            reservation["status"]?.toString() ?? "pending";
                        final String clientName =
                            reservation["profiles"]?["full_name"]?.toString() ??
                                "Client";

                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      clientName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Chip(
                                      backgroundColor: statusColor(status),
                                      label: Text(
                                        statusLabel(status),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                Text("📅 Date : ${reservation["reservation_date"] ?? ""}"),
                                Text("🕒 Heure : ${reservation["reservation_time"] ?? ""}"),
                                Text("👥 Couverts : ${reservation["guests"] ?? 1} personne(s)"),

                                if (reservation["special_request"] != null &&
                                    reservation["special_request"]
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    "💬 Note : ${reservation["special_request"]}",
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 15),

                                // BOUTONS D'ACTION (SI EN ATTENTE)
                                if (status == "pending")
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                          onPressed: () {
                                            updateStatus(
                                              reservation["id"].toString(),
                                              "accepted",
                                            );
                                          },
                                          child: const Text(
                                            "Accepter",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () {
                                            updateStatus(
                                              reservation["id"].toString(),
                                              "rejected",
                                            );
                                          },
                                          child: const Text(
                                            "Refuser",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}