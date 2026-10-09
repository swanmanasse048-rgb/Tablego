import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantReviewsScreen extends StatefulWidget {
  final String restaurantId;

  const RestaurantReviewsScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantReviewsScreen> createState() => _RestaurantReviewsScreenState();
}

class _RestaurantReviewsScreenState extends State<RestaurantReviewsScreen> {
  final supabase = Supabase.instance.client;
  static const Color primaryColor = Color(0xFF6D1B2B);

  List<Map<String, dynamic>> reviews = [];
  bool isLoading = true;

  double averageRating = 0.0;
  Map<int, int> ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => isLoading = true);
    try {
      // Jointure avec la table profiles pour récupérer le nom (ajustez 'full_name' si votre colonne s'appelle autrement dans profiles)
      final response = await supabase
          .from('reviews')
          .select('*, profiles(full_name)')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> loadedReviews =
          List<Map<String, dynamic>>.from(response);

      // Calcul de la note moyenne et de la répartition par étoile
      double totalRating = 0.0;
      final Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var review in loadedReviews) {
        final double r = double.tryParse(review['rating'].toString()) ?? 0.0;
        totalRating += r;
        final int starIndex = r.round().clamp(1, 5);
        counts[starIndex] = (counts[starIndex] ?? 0) + 1;
      }

      final double avg =
          loadedReviews.isNotEmpty ? (totalRating / loadedReviews.length) : 0.0;

      if (!mounted) return;
      setState(() {
        reviews = loadedReviews;
        averageRating = avg;
        ratingCounts = counts;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur de chargement des avis : $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Widget _buildStarRating(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index < rating && (rating - index) >= 0.5) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  Widget _buildRatingSummary() {
    final int totalCount = reviews.length;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                _buildStarRating(averageRating, size: 20),
                const SizedBox(height: 6),
                Text(
                  "$totalCount avis",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(width: 20),
            const SizedBox(
              height: 80,
              child: VerticalDivider(thickness: 1, width: 1),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: List.generate(5, (i) {
                  final int starLevel = 5 - i;
                  final int count = ratingCounts[starLevel] ?? 0;
                  final double percent =
                      totalCount > 0 ? (count / totalCount) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          "$starLevel",
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.grey.shade200,
                              color: primaryColor,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "$count",
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Avis & Commentaires", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadReviews,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildRatingSummary(),
                  const SizedBox(height: 20),
                  const Text(
                    "Commentaires clients",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (reviews.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.rate_review_outlined,
                                size: 50, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              "Aucun avis pour le moment",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...reviews.map((review) {
                      final double rating =
                          double.tryParse(review['rating'].toString()) ?? 0.0;
                      
                      // Récupération sécurisée du nom depuis la table profiles jointe
                      final profileData = review['profiles'] as Map<String, dynamic>?;
                      final String userName = profileData?['full_name'] ?? 'Client anonyme';
                      
                      final String comment = review['comment'] ?? '';
                      final String createdAtStr = review['created_at'] ?? '';
                      String dateDisplay = '';

                      if (createdAtStr.isNotEmpty) {
                        final DateTime? dt = DateTime.tryParse(createdAtStr);
                        if (dt != null) {
                          dateDisplay = "${dt.day}/${dt.month}/${dt.year}";
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            primaryColor.withOpacity(0.1),
                                        child: Text(
                                          userName.isNotEmpty
                                              ? userName[0].toUpperCase()
                                              : 'C',
                                          style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          _buildStarRating(rating, size: 14),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (dateDisplay.isNotEmpty)
                                    Text(
                                      dateDisplay,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  comment,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}