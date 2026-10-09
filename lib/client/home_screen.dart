import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:savora/services/notifications_service.dart'; // 👉 Import de ton service de notification
import 'restaurant_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> restaurants = [];

  bool isLoading = true;
  String selectedCategory = "Tous";

  final Color primaryColor = const Color(0xFF6D1B2B);
  final Color lightPrimary = const Color(0xFFF7ECEF);
  final Color backgroundColor = const Color(0xFFF8F9FA);

  // Liste complète et diversifiée de catégories intelligentes
  final List<Map<String, String>> categories = [
    {"name": "Tous", "icon": "🍽️"},
    {"name": "Fast Food", "icon": "🍔"},
    {"name": "Pizza", "icon": "🍕"},
    {"name": "Asiatique", "icon": "🍣"},
    {"name": "Grillades", "icon": "🥩"},
    {"name": "Congolais", "icon": "🍲"},
    {"name": "Poulet", "icon": "🍗"},
    {"name": "Café & Dessert", "icon": "☕"},
    {"name": "Boissons", "icon": "🧃"},
    {"name": "Boulangerie", "icon": "🥐"},
  ];

  @override
  void initState() {
    super.initState();
    loadRestaurants();
    _startRealtimeNotificationsListener(); // 👉 Lancement de l'écouteur en temps réel au démarrage
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // 👉 Écouteur en temps réel pour déclencher la bannière et la vibration une seule fois
  void _startRealtimeNotificationsListener() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) {
          for (var row in data) {
            final notificationId = row['id'];
            final targetUserId = row['user_id'];
            final targetRestaurantId = row['restaurant_id'];
            final isRead = row['is_read'] ?? false;

            // Si la notification est destinée à l'utilisateur actuel et qu'elle n'est pas encore lue
            if ((targetUserId == user.id || targetRestaurantId == user.id) && !isRead) {
              
              // 1. Marquer immédiatement comme lue dans Supabase pour éviter les boucles
              supabase
                  .from('notifications')
                  .update({'is_read': true})
                  .eq('id', notificationId)
                  .then((_) {
                    // 2. Déclenchement de la vibration et de la bannière visuelle après la mise à jour
                    NotificationService.triggerLocalAlert(
                      row['title'] ?? 'Notification Savora',
                      row['message'] ?? '',
                    );
                  })
                  .catchError((error) {
                    debugPrint("Erreur lors du marquage de la notification comme lue : $error");
                  });
            }
          }
        }, onError: (error) {
          debugPrint("Erreur flux notifications Realtime : $error");
        });
  }

  Future<void> loadRestaurants() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await Supabase.instance.client
          .from('restaurants')
          .select(
            'id, name, description, address, image_url, category, slug, created_at, reviews(rating)',
          )
          .eq("status", "approved")
          .order('created_at', ascending: false);

      if (!mounted) return;

      final processedRestaurants = List<Map<String, dynamic>>.from(data).map((restaurant) {
        final reviews = restaurant['reviews'] as List<dynamic>? ?? [];
        
        if (reviews.isNotEmpty) {
          double sum = 0;
          for (var review in reviews) {
            final ratingVal = review['rating'];
            if (ratingVal is num) {
              sum += ratingVal.toDouble();
            } else if (ratingVal is String) {
              sum += double.tryParse(ratingVal) ?? 0.0;
            }
          }
          double average = sum / reviews.length;
          restaurant['computed_rating'] = average.toStringAsFixed(1);
        } else {
          restaurant['computed_rating'] = "0.0";
        }
        
        return restaurant;
      }).toList();

      setState(() {
        restaurants = processedRestaurants;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Une erreur est survenue : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  Widget _buildCategoryChip(String categoryName, String emoji) {
    final bool isSelected = selectedCategory == categoryName;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              selectedCategory = categoryName;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? primaryColor.withOpacity(0.25) : Colors.black.withOpacity(0.03),
                  blurRadius: isSelected ? 10 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  categoryName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalize(searchController.text);

    final filteredRestaurants = restaurants.where((restaurant) {
      final name = _normalize(restaurant["name"]?.toString() ?? "");
      final description = _normalize(restaurant["description"]?.toString() ?? "");
      final address = _normalize(restaurant["address"]?.toString() ?? "");
      final category = _normalize(restaurant["category"]?.toString() ?? "");

      final matchSearch =
          query.isEmpty ||
          name.contains(query) ||
          description.contains(query) ||
          address.contains(query) ||
          category.contains(query);

      bool matchCategory = true;
      if (selectedCategory != "Tous") {
        if (selectedCategory == "Fast Food") {
          matchCategory = category.contains("fast") || category.contains("burger") || category.contains("sandwich");
        } else if (selectedCategory == "Grillades") {
          matchCategory = category.contains("grill") || category.contains("viande") || category.contains("steak");
        } else if (selectedCategory == "Café & Dessert") {
          matchCategory = category.contains("cafe") || category.contains("café") || category.contains("dessert") || category.contains("boulangerie");
        } else if (selectedCategory == "Asiatique") {
          matchCategory = category.contains("sushi") || category.contains("asian") || category.contains("chinoise");
        } else if (selectedCategory == "Congolais") {
          matchCategory = category.contains("congolais") || category.contains("locale");
        } else {
          matchCategory = category.contains(_normalize(selectedCategory));
        }
      }

      return matchSearch && matchCategory;
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, const Color(0xFF8D2B40)],
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Savora",
              style: TextStyle(
                color: Color(0xFF6D1B2B),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: lightPrimary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: IconButton(
              tooltip: "Actualiser",
              icon: Icon(
                Icons.refresh_rounded,
                color: primaryColor,
                size: 21,
              ),
              onPressed: isLoading ? null : loadRestaurants,
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: loadRestaurants,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barre de recherche moderne
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: searchController,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: "Rechercher un restaurant, un plat...",
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: primaryColor,
                                  size: 22,
                                ),
                                suffixIcon: searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: Colors.grey.shade600,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            "Catégories",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                return _buildCategoryChip(cat["name"]!, cat["icon"]!);
                              },
                            ),
                          ),

                          const SizedBox(height: 26),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Restaurants à proximité",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                "${filteredRestaurants.length} ${filteredRestaurants.length > 1 ? 'disponibles' : 'disponible'}",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // Affichage grille (Grid) ou état vide
                  filteredRestaurants.isEmpty
                      ? SliverFillRemaining(
                          child: _buildEmptyState(),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return _buildRestaurantCard(context, filteredRestaurants[index]);
                              },
                              childCount: filteredRestaurants.length,
                            ),
                          ),
                        ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 35),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: lightPrimary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 32,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Aucun résultat trouvé",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Essayez de modifier vos filtres de recherche.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              searchController.clear();
              setState(() {
                selectedCategory = "Tous";
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text("Réinitialiser les filtres", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(BuildContext context, Map<String, dynamic> restaurant) {
    final String id = restaurant["id"]?.toString() ?? "";
    final String name = restaurant["name"]?.toString().trim().isNotEmpty == true
        ? restaurant["name"].toString()
        : "Restaurant";
    final String address = restaurant["address"]?.toString() ?? "";
    final String imageUrl = restaurant["image_url"]?.toString().trim() ?? "";
    final String category = restaurant["category"]?.toString().trim() ?? "";
    final String rating = restaurant["computed_rating"]?.toString().trim() ?? "0.0";
    final String slug = restaurant["slug"]?.toString().trim() ?? "";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantDetails(
                restaurantId: id,
                name: name,
                image: imageUrl,
                category: category,
                rating: rating,
                slug: slug,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 115,
                  width: double.infinity,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          rating.isNotEmpty ? rating : "0.0",
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (category.isNotEmpty)
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    if (address.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 28,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}