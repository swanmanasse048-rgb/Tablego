import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteService {
  final supabase = Supabase.instance.client;

  Future<void> addFavorite(String restaurantId) async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    await supabase.from("favorites").insert({
      "user_id": user.id,
      "restaurant_id": restaurantId,
    });
  }

  Future<void> removeFavorite(String restaurantId) async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    await supabase
        .from("favorites")
        .delete()
        .eq("user_id", user.id)
        .eq("restaurant_id", restaurantId);
  }

  Future<bool> isFavorite(String restaurantId) async {
    final user = supabase.auth.currentUser;

    if (user == null) return false;

    final data = await supabase
        .from("favorites")
        .select()
        .eq("user_id", user.id)
        .eq("restaurant_id", restaurantId);

    return data.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final user = supabase.auth.currentUser;

    if (user == null) return [];

    final data = await supabase
        .from("favorites")
        .select("""
          restaurants(*)
        """)
        .eq("user_id", user.id);

    return List<Map<String, dynamic>>.from(data);
  }
}