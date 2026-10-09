import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatisticsScreen extends StatefulWidget {
  final String restaurantId;

  const StatisticsScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int totalReservations = 0;
  int acceptedReservations = 0;
  int pendingReservations = 0;
  int rejectedReservations = 0;

  int totalReviews = 0;
  double averageRating = 0.0;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadStatistics();
  }

  // ============================================================
  // CHARGEMENT DES STATISTIQUES
  // ============================================================

  Future<void> loadStatistics() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Charger les réservations
      final reservationsData = await supabase
          .from('reservations')
          .select()
          .eq('restaurant_id', widget.restaurantId);

      final reservations = List<Map<String, dynamic>>.from(reservationsData);

      final totalRes = reservations.length;
      final acceptedRes =
          reservations.where((r) => r["status"] == "accepted").length;
      final pendingRes =
          reservations.where((r) => r["status"] == "pending").length;
      final rejectedRes = reservations
          .where((r) => r["status"] == "rejected" || r["status"] == "cancelled")
          .length;

      // 2. Charger les avis
      final reviewsData = await supabase
          .from('reviews')
          .select()
          .eq('restaurant_id', widget.restaurantId);

      final reviews = List<Map<String, dynamic>>.from(reviewsData);

      final totalRev = reviews.length;
      double avgRating = 0.0;

      if (reviews.isNotEmpty) {
        double totalScore = 0.0;
        for (var review in reviews) {
          totalScore += ((review["rating"] as num?)?.toDouble() ?? 0.0);
        }
        avgRating = totalScore / reviews.length;
      }

      if (!mounted) return;

      setState(() {
        totalReservations = totalRes;
        acceptedReservations = acceptedRes;
        pendingReservations = pendingRes;
        rejectedReservations = rejectedRes;
        totalReviews = totalRev;
        averageRating = avgRating;
      });
    } catch (e) {
      debugPrint("Erreur statistiques : $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du chargement : $e"),
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
  // COMPOSANT CARTE DE STATISTIQUE
  // ============================================================

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          radius: 24,
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
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
      appBar: AppBar(
        title: const Text("Statistiques"),
        backgroundColor: const Color(0xFF6D1B2B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadStatistics,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatCard(
                    "Total des réservations",
                    totalReservations.toString(),
                    Colors.blue,
                    Icons.calendar_today,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    "Réservations acceptées",
                    acceptedReservations.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    "Réservations en attente",
                    pendingReservations.toString(),
                    Colors.orange,
                    Icons.schedule,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    "Réservations refusées",
                    rejectedReservations.toString(),
                    Colors.red,
                    Icons.cancel,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    "Nombre d'avis",
                    totalReviews.toString(),
                    Colors.purple,
                    Icons.reviews,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    "Note moyenne",
                    averageRating.toStringAsFixed(1),
                    Colors.amber,
                    Icons.star,
                  ),
                ],
              ),
            ),
    );
  }
}