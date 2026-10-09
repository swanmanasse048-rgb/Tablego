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
  List<String> services = [];
  List<Map<String, dynamic>> reviews = [];

  bool isLoading = true;
  bool isFavorite = false;
  bool isLoadingReviews = true;

  double averageRating = 0;
  int totalReviews = 0;
  Map<String, dynamic>? myReview;

  final Color primaryColor = const Color(0xFF6D1B2B);
  final Color surfaceColor = const Color(0xFFFAFAFA);

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
      }

      final mainImage = map['image_url']?.toString().trim() ?? '';
      if (mainImage.isNotEmpty && !loadedGallery.contains(mainImage)) {
        loadedGallery.insert(0, mainImage);
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
        await supabase.from('favorites').delete().eq('user_id', user.id).eq('restaurant_id', widget.restaurantId);
        if (!mounted) return;
        setState(() => isFavorite = false);
      } else {
        await supabase.from('favorites').insert({'user_id': user.id, 'restaurant_id': widget.restaurantId});
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
    final shareUrl = 'https://savora-web-two.vercel.app/restaurants/$slug';
    final shareText = 'Découvrez ${widget.name} sur Savora 🍽️\n$shareUrl';
    await Clipboard.setData(ClipboardData(text: shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Lien copié ! Partagez cette pépite ✨"),
        backgroundColor: primaryColor,
        action: SnackBarAction(
          label: "PARTAGER",
          textColor: Colors.white,
          onPressed: () => Share.share(shareText),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      await launchUrl(launchUri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de passer l'appel")),
      );
    }
  }

  Future<void> _showOrderDialog() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez vous connecter pour commander.")),
      );
      return;
    }

    String initialPhone = user.phone ?? '';
    try {
      final profileData = await supabase.from('profiles').select('phone').eq('id', user.id).maybeSingle();
      if (profileData != null && profileData['phone'] != null) {
        initialPhone = profileData['phone'].toString();
      }
    } catch (_) {}

    List<Map<String, dynamic>> restaurantTables = [];
    try {
      final tablesData = await supabase
          .from('tables')
          .select('id, name, table_number')
          .eq('restaurant_id', widget.restaurantId);
      restaurantTables = List<Map<String, dynamic>>.from(tablesData);
    } catch (_) {}

    final itemsController = TextEditingController();
    final phoneController = TextEditingController(text: initialPhone);
    final noteController = TextEditingController();
    
    String orderType = 'takeaway';
    String selectedSchedule = 'asap';
    String scheduledTime = 'Dans 15-20 min';
    String? selectedTableId;
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
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Commander en un clin d'œil",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'takeaway', label: Text('À emporter'), icon: Icon(Icons.takeout_dining)),
                          ButtonSegment(value: 'dine_in', label: Text('Sur place'), icon: Icon(Icons.restaurant)),
                        ],
                        selected: {orderType},
                        onSelectionChanged: (set) => setSheetState(() => orderType = set.first),
                      ),
                      const SizedBox(height: 20),
                      if (orderType == 'dine_in') ...[
                        DropdownButtonFormField<String>(
                          value: selectedTableId,
                          decoration: InputDecoration(
                            labelText: "Sélectionner la table",
                            prefixIcon: Icon(Icons.table_bar_rounded, color: primaryColor),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          items: restaurantTables.map((table) {
                            final tableName = table['name'] != null && table['name'].toString().isNotEmpty
                                ? table['name']
                                : 'Table ${table['table_number']}';
                            return DropdownMenuItem<String>(
                              value: table['id'].toString(),
                              child: Text(tableName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setSheetState(() => selectedTableId = val);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (orderType == 'takeaway') ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryColor.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 18, color: primaryColor),
                                  const SizedBox(width: 8),
                                  const Text("Moment du retrait", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      label: const Text("Au plus tôt (~20 min)"),
                                      selected: selectedSchedule == 'asap',
                                      selectedColor: primaryColor,
                                      labelStyle: TextStyle(
                                        color: selectedSchedule == 'asap' ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      onSelected: (val) {
                                        setSheetState(() {
                                          selectedSchedule = 'asap';
                                          scheduledTime = 'Dans 15-20 min';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ChoiceChip(
                                      label: const Text("Plus tard (Heure fixe)"),
                                      selected: selectedSchedule == 'scheduled',
                                      selectedColor: primaryColor,
                                      labelStyle: TextStyle(
                                        color: selectedSchedule == 'scheduled' ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      onSelected: (val) async {
                                        final TimeOfDay? picked = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.now(),
                                        );
                                        if (picked != null) {
                                          setSheetState(() {
                                            selectedSchedule = 'scheduled';
                                            scheduledTime = 'Pour ${picked.format(context)}';
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: itemsController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: "Votre sélection (plats, boissons...)",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: "Téléphone de contact",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (itemsController.text.trim().isEmpty || phoneController.text.trim().isEmpty) return;
                                  if (orderType == 'dine_in' && selectedTableId == null) return;

                                  setSheetState(() => isSubmitting = true);
                                  try {
                                    final String finalAddressContext = orderType == 'dine_in'
                                        ? 'Sur place'
                                        : 'À emporter ($scheduledTime)';

                                    final res = await supabase.from('orders').insert({
                                      'restaurant_id': widget.restaurantId,
                                      'user_id': user.id,
                                      'phone': phoneController.text.trim(),
                                      'delivery_address': finalAddressContext,
                                      'special_request': orderType == 'takeaway' ? scheduledTime : null,
                                      'order_type': orderType,
                                      'note': noteController.text.trim(),
                                      'status': 'pending',
                                      'total_amount': 0,
                                      'table_id': orderType == 'dine_in' ? selectedTableId : null,
                                    }).select('id').single();

                                    final orderId = res['id'].toString();

                                    await supabase.from('order_items').insert({
                                      'order_id': orderId,
                                      'product_name': itemsController.text.trim(),
                                      'quantity': 1,
                                      'unit_price': 0,
                                    });

                                    await supabase.from('notifications').insert({
                                      'restaurant_id': widget.restaurantId,
                                      'title': orderType == 'dine_in' ? 'Nouvelle table ! 🍽️' : 'À emporter ! 🛍️',
                                      'message': orderType == 'dine_in' ? 'Commande sur place' : 'Retrait : $scheduledTime',
                                      'type': 'order',
                                      'reference_id': orderId,
                                      'is_read': false,
                                    });

                                    if (!mounted) return;
                                    Navigator.pop(sheetContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Commande transmise avec succès ! 🎉"), backgroundColor: Colors.green),
                                    );
                                  } catch (e) {
                                    setSheetState(() => isSubmitting = false);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
                                  }
                                },
                          child: isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Valider la commande", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(backgroundColor: surfaceColor, body: Center(child: CircularProgressIndicator(color: primaryColor)));
    }

    final restaurantName = restaurant!['name'] ?? widget.name;
    final description = restaurant!['description'] ?? '';
    final address = restaurant!['address'] ?? '';
    final category = restaurant!['category'] ?? widget.category;
    final mainImage = restaurant!['image_url'] ?? widget.image;
    final displayedRating = totalReviews > 0 ? averageRating.toStringAsFixed(1) : widget.rating;
    
    final restaurantPhone = restaurant?['phone']?.toString() ?? restaurant?['telephone']?.toString() ?? '';

    return Scaffold(
      backgroundColor: surfaceColor,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showOrderDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: const Text("Commander", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(restaurantId: widget.restaurantId, restaurantName: restaurantName),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                  label: const Text("Réserver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.3),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.3),
                child: IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  onPressed: _shareRestaurant,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFavorite ? Colors.redAccent : Colors.white,
                      size: 18,
                    ),
                    onPressed: toggleFavorite,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  mainImage.isNotEmpty
                      ? Image.network(mainImage, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade300),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 25, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      category.toUpperCase(),
                                      style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    restaurantName,
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.amber.shade200, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(displayedRating, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor.withOpacity(0.08),
                                  foregroundColor: primaryColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RestaurantMenuScreen(restaurantId: widget.restaurantId, isRestaurantOwner: false),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                                label: const Text("Menu & Carte", style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50,
                                  foregroundColor: Colors.blue.shade700,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: _openMap,
                                icon: const Icon(Icons.near_me_rounded, size: 18),
                                label: const Text("Itinéraire", style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CARTE GALERIE DE PHOTOS
                  if (galleryUrls.isNotEmpty) ...[
                    const Text("Photos du restaurant 📸", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: galleryUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.grey.shade200,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              galleryUrls[index],
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Carte Adresse
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.location_on_rounded, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Adresse", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                address.isNotEmpty ? address : "Adresse non renseignée",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Carte Téléphone
                  if (restaurantPhone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.phone_rounded, color: Colors.green, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Téléphone", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  restaurantPhone,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _makePhoneCall(restaurantPhone),
                            icon: const Icon(Icons.call, color: Colors.green),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text("Services disponibles ✨", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: services.map((service) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: primaryColor, size: 16),
                              const SizedBox(width: 8),
                              Text(service, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),
                  ClientPromotionsSection(restaurantId: widget.restaurantId),

                  const SizedBox(height: 24),
                  if (description.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("À propos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Text(description, style: TextStyle(color: Colors.grey.shade600, height: 1.6, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  _UserReviewSection(
                    restaurantId: widget.restaurantId,
                    initialReview: myReview,
                    onReviewSubmitted: loadReviews,
                  ),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Avis de la communauté", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            Text("$totalReviews avis", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        isLoadingReviews
                            ? const Center(child: CircularProgressIndicator())
                            : reviews.isEmpty
                                ? Text("Soyez le premier à laisser un avis !", style: TextStyle(color: Colors.grey.shade500))
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

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: primaryColor.withOpacity(0.1),
                                                      child: Text(
                                                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(userName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                                  ],
                                                ),
                                                Row(
                                                  children: List.generate(
                                                    5,
                                                    (i) => Icon(
                                                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                                      color: Colors.amber,
                                                      size: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (comment.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(comment, style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5)),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserReviewSection extends StatefulWidget {
  final String restaurantId;
  final Map<String, dynamic>? initialReview;
  final Future<void> Function() onReviewSubmitted;

  const _UserReviewSection({
    required this.restaurantId,
    required this.initialReview,
    required this.onReviewSubmitted,
  });

  @override
  State<_UserReviewSection> createState() => _UserReviewSectionState();
}

class _UserReviewSectionState extends State<_UserReviewSection> {
  late final TextEditingController commentController;
  late int selectedRating;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    commentController = TextEditingController(
      text: widget.initialReview != null ? widget.initialReview!['comment']?.toString() ?? '' : '',
    );
    selectedRating = widget.initialReview != null ? (widget.initialReview!['rating'] as num?)?.toInt() ?? 5 : 5;
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    const Color primaryColor = Color(0xFF6D1B2B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initialReview == null ? "Partagez votre expérience ✨" : "Modifier votre avis",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              int starValue = index + 1;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  starValue <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    selectedRating = starValue;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: commentController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: "Qu'avez-vous pensé de ce lieu ?",
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (commentController.text.trim().isEmpty) return;
                      setState(() => isSubmitting = true);
                      try {
                        if (widget.initialReview == null) {
                          await supabase.from('reviews').insert({
                            'restaurant_id': widget.restaurantId,
                            'user_id': user.id,
                            'rating': selectedRating,
                            'comment': commentController.text.trim(),
                          });
                        } else {
                          await supabase.from('reviews').update({
                            'rating': selectedRating,
                            'comment': commentController.text.trim(),
                          }).eq('id', widget.initialReview!['id']);
                        }
                        await widget.onReviewSubmitted();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Avis publié avec succès !"), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setState(() => isSubmitting = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
                      }
                    },
              child: isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(widget.initialReview == null ? "Publier" : "Mettre à jour", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
      var query = supabase.from('promotions').select('*, restaurants(name, image_url)').eq('is_active', true);
      if (widget.restaurantId != null) {
        query = query.eq('restaurant_id', widget.restaurantId!);
      }
      final data = await query.order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        promotions = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Indéterminé';
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _showPromotionDetails(BuildContext context, Map<String, dynamic> promo) {
    final imageUrl = promo['image_url'];
    final title = promo['title'] ?? 'Offre spéciale';
    final discount = promo['discount_percentage'];
    final origPrice = promo['original_price'];
    final promoPrice = promo['promo_price'];
    final description = promo['description'] ?? 'Aucune description.';
    
    final startDate = promo['start_date'] ?? promo['date_debut'];
    final endDate = promo['end_date'] ?? promo['date_fin'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: imageUrl != null && imageUrl.toString().isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Container(color: primaryColor.withOpacity(0.1)),
                    ),
                    if (discount != null)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                          child: Text("-$discount%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (origPrice != null)
                            Text("\$$origPrice", style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 15)),
                          const SizedBox(width: 12),
                          if (promoPrice != null)
                            Text("\$$promoPrice", style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 22)),
                        ],
                      ),
                      
                      if (startDate != null || endDate != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range_rounded, size: 20, color: primaryColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Valide du ${_formatDate(startDate)} au ${_formatDate(endDate)}",
                                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Divider(height: 32),
                      Text(description, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Fermer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    if (isLoading || promotions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Promotions & Offres 🔥", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promo = promotions[index];
              final imageUrl = promo['image_url'];
              final title = promo['title'] ?? 'Offre';
              final discount = promo['discount_percentage'];
              final promoPrice = promo['promo_price'];

              return Container(
                width: 230,
                margin: const EdgeInsets.only(right: 14),
                child: Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: InkWell(
                    onTap: () => _showPromotionDetails(context, promo),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: imageUrl != null && imageUrl.toString().isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : Container(color: primaryColor.withOpacity(0.1)),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                              ),
                            ),
                          ),
                        ),
                        if (discount != null)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
                              child: Text("-$discount%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                            ),
                          ),
                        Positioned(
                          bottom: 14,
                          left: 14,
                          right: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                              if (promoPrice != null) ...[
                                const SizedBox(height: 2),
                                Text("\$$promoPrice", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 15)),
                              ],
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