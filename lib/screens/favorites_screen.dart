import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:savora/client/restaurant_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List favorites = [];
  bool isLoading = true;

  final Color primaryColor = const Color(0xFF6D1B2B);
  final Color backgroundColor = const Color(0xFFF8F8F8);

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('favorites')
          .select('''
            id,
            restaurants(
              id,
              name,
              image_url,
              slug,
              category,
              rating
            )
          ''')
          .eq('user_id', user.id);

      setState(() {
        favorites = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Erreur lors du chargement des favoris : $e");
    }
  }

  Future<void> _removeFromFavorites(String restaurantId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('restaurant_id', restaurantId);

      await loadFavorites();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Retiré de vos favoris"),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryColor,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Mes favoris",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7ECEF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: primaryColor,
                  size: 17,
                ),
                const SizedBox(width: 5),
                Text(
                  "${favorites.length}",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : favorites.isEmpty
              ? _buildEmptyFavorites()
              : RefreshIndicator(
                  color: primaryColor,
                  onRefresh: loadFavorites,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                    children: [
                      const Text(
                        "Vos restaurants préférés",
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Retrouvez facilement les restaurants que vous aimez.",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ...List.generate(
                        favorites.length,
                        (index) {
                          final item = favorites[index];
                          final restaurant = item["restaurants"];
                          
                          if (restaurant == null) return const SizedBox.shrink();

                          return _buildFavoriteCard(restaurant);
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> restaurant) {
    final imageUrl = restaurant["image_url"]?.toString() ?? "";
    final name = restaurant["name"]?.toString() ?? "Restaurant";
    final restaurantId = restaurant["id"].toString();
    final slug = restaurant["slug"]?.toString() ?? "";
    final category = restaurant["category"]?.toString() ?? "";
    final rating = restaurant["rating"]?.toString() ?? "0.0"; // Converti en String pour correspondre au type attendu

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetails(
                restaurantId: restaurantId,
                name: name,
                image: imageUrl,
                slug: slug,
                category: category,
                rating: rating,
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
                  height: 205,
                  width: double.infinity,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _imagePlaceholder();
                          },
                        )
                      : _imagePlaceholder(),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.05),
                            Colors.transparent,
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _removeFromFavorites(restaurantId),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Colors.red.shade600,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          color: primaryColor,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Favori",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7ECEF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: primaryColor,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.restaurant_rounded,
            color: Colors.grey.shade500,
            size: 35,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFavorites() {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: loadFavorites,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 25),
        children: [
          const SizedBox(height: 110),
          Center(
            child: Container(
              width: 115,
              height: 115,
              decoration: const BoxDecoration(
                color: Color(0xFFF7ECEF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 55,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            "Aucun favori pour le moment",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Ajoutez vos restaurants préférés pour les retrouver rapidement ici.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}