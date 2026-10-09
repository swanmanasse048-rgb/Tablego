import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:savora/restaurant/restaurant_menu_screen.dart';
import 'booking_screen.dart';

class RestaurantDetails extends StatefulWidget {
  final String restaurantId;
  final String name;
  final String image;
  final String category;
  final String rating;
  final String slug;

  const RestaurantDetails({
    super.key,
    required this.restaurantId,
    required this.name,
    required this.image,
    required this.category,
    required this.rating,
    required this.slug,
  });

  @override
  State<RestaurantDetails> createState() => _RestaurantDetailsState();
}

class _RestaurantDetailsState extends State<RestaurantDetails> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? restaurant;
  List<String> galleryUrls = [];
  List<String> menuUrls = [];
  List<String> services = [];
  List<Map<String, dynamic>> reviews = [];

  bool isLoading = true;
  bool isFavorite = false;
  bool isLoadingReviews = true;

  double averageRating = 0;
  int totalReviews = 0;
  Map<String, dynamic>? myReview;

  final Color primaryColor = const Color(0xFF6D1B2B);
  final Color lightPrimary = const Color(0xFFF7ECEF);

  @override
  void initState() {
    super.initState();
    loadRestaurant();
    checkFavorite();
    loadReviews();
  }

  Future<void> loadRestaurant() async {
    try {
      final data = await supabase
          .from('restaurants')
          .select()
          .eq('id', widget.restaurantId)
          .maybeSingle();

      if (!mounted) return;
      if (data == null) {
        setState(() => isLoading = false);
        return;
      }

      final map = Map<String, dynamic>.from(data);
      final loadedGallery = <String>[];
      final gallery = map['gallery_urls'];

      if (gallery is List) {
        for (final item in gallery) {
          if (item != null && item.toString().trim().isNotEmpty) {
            loadedGallery.add(item.toString().trim());
          }
        }
      } else if (gallery is String && gallery.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(gallery);
          if (decoded is List) {
            for (final item in decoded) {
              if (item != null && item.toString().trim().isNotEmpty) {
                loadedGallery.add(item.toString().trim());
              }
            }
          }
        } catch (_) {}
      }

      final mainImage = map['image_url']?.toString().trim() ?? '';
      if (mainImage.isNotEmpty && !loadedGallery.contains(mainImage)) {
        loadedGallery.insert(0, mainImage);
      }

      final loadedMenu = <String>[];
      final menu = map['menu_urls'];
      if (menu is List) {
        for (final item in menu) {
          if (item != null && item.toString().trim().isNotEmpty) {
            loadedMenu.add(item.toString().trim());
          }
        }
      }

      final loadedServices = <String>[];
      final servicesData = map['services'];
      if (servicesData is List) {
        for (final item in servicesData) {
          if (item != null && item.toString().trim().isNotEmpty) {
            loadedServices.add(item.toString().trim());
          }
        }
      }

      setState(() {
        restaurant = map;
        galleryUrls = loadedGallery;
        menuUrls = loadedMenu;
        services = loadedServices;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> checkFavorite() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('favorites')
          .select()
          .eq('user_id', user.id)
          .eq('restaurant_id', widget.restaurantId)
          .maybeSingle();

      if (!mounted) return;
      setState(() => isFavorite = data != null);
    } catch (_) {}
  }

  Future<void> toggleFavorite() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez vous connecter pour ajouter un favori.")),
      );
      return;
    }

    try {
      if (isFavorite) {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('restaurant_id', widget.restaurantId);
        if (!mounted) return;
        setState(() => isFavorite = false);
      } else {
        await supabase.from('favorites').insert({
          'user_id': user.id,
          'restaurant_id': widget.restaurantId,
        });
        if (!mounted) return;
        setState(() => isFavorite = true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  Future<void> loadReviews() async {
    try {
      final data = await supabase
          .from('reviews')
          .select('*, profiles (full_name)')
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false);

      final loadedReviews = List<Map<String, dynamic>>.from(data);
      double total = 0;
      for (final review in loadedReviews) {
        final rating = review['rating'];
        if (rating is num) total += rating.toDouble();
      }

      final user = supabase.auth.currentUser;
      Map<String, dynamic>? currentUserReview;
      if (user != null) {
        for (final review in loadedReviews) {
          if (review['user_id']?.toString() == user.id) {
            currentUserReview = review;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        reviews = loadedReviews;
        myReview = currentUserReview;
        totalReviews = loadedReviews.length;
        averageRating = loadedReviews.isEmpty ? 0 : total / loadedReviews.length;
        isLoadingReviews = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingReviews = false);
    }
  }

  Future<void> _shareRestaurant() async {
    final slug = widget.slug.trim();
    if (slug.isEmpty) return;
    final shareUrl = 'https://savora-web-two.vercel.app/restaurant/$slug';
    final shareText = 'Découvrez ${widget.name} sur Savora 🍽️\n$shareUrl';
    await Clipboard.setData(ClipboardData(text: shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Lien copié dans le presse-papier !"),
        backgroundColor: primaryColor,
        action: SnackBarAction(
          label: "PARTAGER",
          textColor: Colors.white,
          onPressed: () => Share.share(shareText),
        ),
      ),
    );
  }

  Future<void> _showOrderDialog() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez vous connecter pour passer une commande.")),
      );
      return;
    }

    String initialPhone = user.phone ?? '';
    try {
      final profileData = await supabase
          .from('profiles')
          .select('phone')
          .eq('id', user.id)
          .maybeSingle();
      
      if (profileData != null && profileData['phone'] != null) {
        initialPhone = profileData['phone'].toString();
      }
    } catch (_) {}

    final itemsController = TextEditingController();
    final phoneController = TextEditingController(text: initialPhone);
    final noteController = TextEditingController();
    String orderType = 'takeaway';
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Passer une commande",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'takeaway',
                            label: Text('À emporter'), 
                            icon: Icon(Icons.takeout_dining)),
                          ButtonSegment(
                            value: 'dine_in',
                            label: Text('Sur place'),
                            icon: Icon(Icons.restaurant)),
                        ],
                        selected: {orderType},
                        onSelectionChanged: (set) => setSheetState(() => orderType = set.first),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: itemsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Votre commande (plats, boissons)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Numéro de téléphone",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: "Instructions particulières (optionnel)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D1B2B)),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (itemsController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                                    return;
                                  }
                                  setSheetState(() => isSubmitting = true);
                                  try {
                                    // 1. Insertion de la commande sécurisée (sans prix saisi par le client)
                                    final res = await supabase.from('orders').insert({
                                      'restaurant_id': widget.restaurantId,
                                      'user_id': user.id,
                                      'phone': phoneController.text.trim(),
                                      'delivery_address': orderType == 'dine_in' ? 'Sur place' : 'À emporter',
                                      'order_type': orderType,
                                      'note': noteController.text.trim(),
                                      'status': 'pending',
                                      'total_amount': 0, 
                                    }).select('id').single();

                                    final orderId = res['id'].toString();

                                    // 2. Ajout des détails textuels de la commande
                                    await supabase.from('order_items').insert({
                                      'order_id': orderId,
                                      'product_name': itemsController.text.trim(),
                                      'quantity': 1,
                                      'unit_price': 0, 
                                    });

                                    // 3. Enregistrement d'une notification pour le restaurant
                                    await supabase.from('notifications').insert({
                                      'restaurant_id': widget.restaurantId,
                                      'title': 'Nouvelle commande ! 📦',
                                      'message': 'Une nouvelle commande vient d\'être passée. Consultez les détails.',
                                      'type': 'order',
                                      'reference_id': orderId,
                                      'is_read': false,
                                    });

                                    if (!mounted) return;
                                    Navigator.pop(sheetContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Commande envoyée avec succès ! Le restaurant a été notifié."), 
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    setSheetState(() => isSubmitting = false);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                          child: isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Envoyer la commande", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openMap() async {
    final lat = _toDouble(restaurant?['latitude']);
    final lng = _toDouble(restaurant?['longitude']);
    final address = restaurant?['address']?.toString() ?? '';

    Uri url = lat != null && lng != null
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  Widget _buildUserReviewSection() {
    final user = supabase.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final commentController = TextEditingController(
      text: myReview != null ? myReview!['comment']?.toString() ?? '' : '',
    );
    int selectedRating = myReview != null ? (myReview!['rating'] as num?)?.toInt() ?? 5 : 5;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  myReview == null ? "Laisser un avis" : "Modifier votre avis",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(5, (index) {
                    int starValue = index + 1;
                    return IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        starValue <= selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 28,
                      ),
                      onPressed: () {
                        setLocalState(() {
                          selectedRating = starValue;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Votre commentaire",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    onPressed: () async {
                      if (commentController.text.trim().isEmpty) return;

                      try {
                        if (myReview == null) {
                          await supabase.from('reviews').insert({
                            'restaurant_id': widget.restaurantId,
                            'user_id': user.id,
                            'rating': selectedRating,
                            'comment': commentController.text.trim(),
                          });
                        } else {
                          await supabase
                              .from('reviews')
                              .update({
                                'rating': selectedRating,
                                'comment': commentController.text.trim(),
                              })
                              .eq('id', myReview!['id']);
                        }

                        await loadReviews();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Avis enregistré avec succès !"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur : $e")),
                        );
                      }
                    },
                    child: Text(
                      myReview == null ? "Publier l'avis" : "Mettre à jour l'avis",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final restaurantName = restaurant!['name'] ?? widget.name;
    final description = restaurant!['description'] ?? '';
    final address = restaurant!['address'] ?? '';
    final category = restaurant!['category'] ?? widget.category;
    final mainImage = restaurant!['image_url'] ?? widget.image;
    final displayedRating = totalReviews > 0 ? averageRating.toStringAsFixed(1) : widget.rating;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.4),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.4),
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareRestaurant,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.4),
            child: IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.white),
              onPressed: toggleFavorite,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showOrderDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text("Commander"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(
                        restaurantId: widget.restaurantId,
                        restaurantName: restaurantName,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.calendar_month, color: Colors.white),
                label: const Text("Réserver", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              mainImage,
              height: 280,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 280, color: Colors.grey.shade300),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          restaurantName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.star, color: Colors.amber, size: 16),
                        label: Text(displayedRating, style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.amber.shade50,
                      ),
                    ],
                  ),
                  Text(category, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 16),

                  ClientPromotionsSection(restaurantId: widget.restaurantId),
                  const SizedBox(height: 20),

                  if (description.isNotEmpty) ...[
                    const Text("À propos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(description, style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
                    const SizedBox(height: 20),
                  ],

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: ListTile(
                      leading: Icon(Icons.location_on, color: primaryColor),
                      title: Text(address.isNotEmpty ? address : "Adresse non renseignée"),
                      trailing: IconButton(
                        icon: Icon(Icons.directions, color: primaryColor),
                        onPressed: _openMap,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RestaurantMenuScreen(
                              restaurantId: widget.restaurantId,
                              isRestaurantOwner: false,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.restaurant_menu),
                      label: const Text("Consulter la carte / Menu"),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildUserReviewSection(),
                  const SizedBox(height: 20),

                  const Text("Avis clients", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  isLoadingReviews
                      ? const Center(child: CircularProgressIndicator())
                      : reviews.isEmpty
                          ? Text("Aucun avis pour le moment.", style: TextStyle(color: Colors.grey.shade600))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: reviews.length,
                              itemBuilder: (context, index) {
                                final review = reviews[index];
                                final profile = review['profiles'];
                                final userName = profile != null ? profile['full_name'] ?? 'Utilisateur' : 'Utilisateur';
                                final comment = review['comment'] ?? '';
                                final rating = (review['rating'] as num?)?.toInt() ?? 5;

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Row(
                                              children: List.generate(
                                                5,
                                                (i) => Icon(
                                                  i < rating ? Icons.star : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (comment.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(comment, style: TextStyle(color: Colors.grey.shade700)),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClientPromotionsSection extends StatefulWidget {
  final String? restaurantId;

  const ClientPromotionsSection({super.key, this.restaurantId});

  @override
  State<ClientPromotionsSection> createState() => _ClientPromotionsSectionState();
}

class _ClientPromotionsSectionState extends State<ClientPromotionsSection> {
  final supabase = Supabase.instance.client;
  static const Color primaryColor = Color(0xFF6D1B2B);

  List<Map<String, dynamic>> promotions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivePromotions();
  }

  Future<void> _loadActivePromotions() async {
    try {
      var query = supabase
          .from('promotions')
          .select('*, restaurants(name, image_url)')
          .eq('is_active', true);

      if (widget.restaurantId != null) {
        query = query.eq('restaurant_id', widget.restaurantId!);
      }

      final data = await query.order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        promotions = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur de chargement des promotions : $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void _showPromotionDetails(BuildContext context, Map<String, dynamic> promo) {
    final imageUrl = promo['image_url'];
    final title = promo['title'] ?? 'Offre spéciale';
    final restaurantName = promo['restaurants']?['name'] ?? '';
    final discount = promo['discount_percentage'];
    final origPrice = promo['original_price'];
    final promoPrice = promo['promo_price'];
    final description = promo['description'] ?? 'Aucune description détaillée pour cette promotion.';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: imageUrl != null && imageUrl.toString().isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: primaryColor.withOpacity(0.1)),
                            )
                          : Container(
                              color: primaryColor.withOpacity(0.1),
                              child: const Icon(Icons.local_offer,
                                  size: 80, color: primaryColor),
                            ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    if (discount != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "-$discount%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (restaurantName.isNotEmpty)
                        Text(
                          restaurantName.toUpperCase(),
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (origPrice != null)
                            Text(
                              "\$$origPrice",
                              style: const TextStyle(
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                                fontSize: 16,
                              ),
                            ),
                          const SizedBox(width: 12),
                          if (promoPrice != null)
                            Text(
                              "\$$promoPrice",
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        "Détails de l'offre",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Fermer",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
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
    if (isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (promotions.isEmpty) {
      return const SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Promotions & Offres 🔥",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promo = promotions[index];
              final imageUrl = promo['image_url'];
              final title = promo['title'] ?? 'Offre spéciale';
              final restaurantName = promo['restaurants']?['name'] ?? '';
              final discount = promo['discount_percentage'];
              final origPrice = promo['original_price'];
              final promoPrice = promo['promo_price'];

              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 14),
                child: Card(
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => _showPromotionDetails(context, promo),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: imageUrl != null && imageUrl.toString().isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(color: primaryColor.withOpacity(0.1)),
                                )
                              : Container(
                                  color: primaryColor.withOpacity(0.1),
                                  child: const Icon(Icons.local_offer,
                                      size: 50, color: primaryColor),
                                ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.85),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (discount != null)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "-$discount%",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (restaurantName.isNotEmpty)
                                Text(
                                  restaurantName,
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (origPrice != null)
                                    Text(
                                      "\$$origPrice",
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        decoration: TextDecoration.lineThrough,
                                        fontSize: 13,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  if (promoPrice != null)
                                    Text(
                                      "\$$promoPrice",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}