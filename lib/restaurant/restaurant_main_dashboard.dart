import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:savora/restaurant/restaurant_menu_screen.dart';
import 'package:savora/restaurant/restaurant_orders_screen.dart';
import 'package:savora/restaurant/restaurant_promotions_screen.dart';
import 'package:savora/restaurant/restaurant_notifications_screen.dart';
import 'package:savora/restaurant/restaurant_tables_screen.dart';
import 'package:savora/restaurant/create_restaurant_screen.dart';
import 'package:savora/restaurant/restaurantreviewsScreen.dart';
import 'package:savora/widgets/restaurantQrCodeDialog.dart';
import '../models/restaurant_service.dart';
import 'package:savora/services/notifications_service.dart';
import 'package:savora/restaurant/restaurant_stats_screen.dart';

class RestaurantMainDashboard extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String restaurantSlug;

  const RestaurantMainDashboard({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantSlug,
  });

  @override
  State<RestaurantMainDashboard> createState() => _RestaurantMainDashboardState();
}

class _RestaurantMainDashboardState extends State<RestaurantMainDashboard> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  static const Color primaryColor = Color(0xFF6D1B2B);
  static const Color backgroundColor = Color(0xFFF8F9FA);

  int _currentIndex = 0;

  Map<String, dynamic>? restaurantData;
  List<Map<String, dynamic>> reservations = [];
  List<String> restaurantPhotos = [];

  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingPhoto = false;
  String? errorMessage;

  RealtimeChannel? _reservationChannel;
  StreamSubscription? _notificationChannel;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final openingController = TextEditingController();
  final closingController = TextEditingController();
  final categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _checkAuthAndLoadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    if (_reservationChannel != null) {
      supabase.removeChannel(_reservationChannel!);
    }
    _notificationChannel?.cancel();
    nameController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    addressController.dispose();
    openingController.dispose();
    closingController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadData() async {
    if (mounted) setState(() { isLoading = true; errorMessage = null; });
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = "Veuillez vous connecter pour accéder à votre espace.";
      });
      return;
    }

    try {
      final response = await supabase
          .from('restaurants')
          .select()
          .eq('owner_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        setState(() { restaurantData = null; reservations = []; isLoading = false; });
        return;
      }

      final restaurant = Map<String, dynamic>.from(response);
      _fillRestaurantData(restaurant);

      String rawGallery = restaurant['gallery_urls']?.toString() ?? '';
      List<String> parsedPhotos = [];
      if (rawGallery.isNotEmpty) {
        parsedPhotos = rawGallery.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      setState(() { 
        restaurantData = restaurant;
        restaurantPhotos = parsedPhotos;
      });

      final restId = restaurant['id'].toString();
      await _loadReservations(restId);
      _listenToRealtimeChannels(restId);

      if (!mounted) return;
      setState(() { isLoading = false; });
      _fadeController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() { isLoading = false; errorMessage = "Erreur de chargement : $e"; });
    }
  }

  // Fonction dédiée pour le rafraîchissement (Pull-to-refresh)
  Future<void> _handleRefresh() async {
    if (restaurantData != null) {
      await _loadReservations(restaurantData!['id'].toString());
    } else {
      await _checkAuthAndLoadData();
    }
  }

  void _listenToRealtimeChannels(String restaurantId) {
    if (_reservationChannel != null) {
      supabase.removeChannel(_reservationChannel!);
    }
    _notificationChannel?.cancel();

    _reservationChannel = supabase
        .channel('public:reservations:restaurant_id=$restaurantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (payload) {
            _loadReservations(restaurantId);
          },
        )
        .subscribe();

    final user = supabase.auth.currentUser;
    if (user == null) return;

    _notificationChannel = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) async {
          for (var row in data) {
            final notificationId = row['id'];
            final targetUserId = row['user_id'];
            final targetRestaurantId = row['restaurant_id'];
            final isRead = row['is_read'] ?? false;

            if ((targetUserId == user.id || targetRestaurantId == restaurantId) && !isRead) {
              NotificationService.triggerLocalAlert(
                row['title'] ?? 'Notification Savora',
                row['message'] ?? '',
              );

              try {
                await supabase
                    .from('notifications')
                    .update({'is_read': true})
                    .eq('id', notificationId);
              } catch (e) {
                debugPrint("Erreur lors du marquage de la notification comme lue : $e");
              }

              _loadReservations(restaurantId);
            }
          }
        }, onError: (error) {
          debugPrint("Erreur flux notifications Realtime (Dashboard) : $error");
        });
  }

  void _fillRestaurantData(Map<String, dynamic> restaurant) {
    nameController.text = restaurant['name']?.toString() ?? '';
    categoryController.text = restaurant['category']?.toString() ?? '';
    descriptionController.text = restaurant['description']?.toString() ?? '';
    phoneController.text = restaurant['phone']?.toString() ?? '';
    addressController.text = restaurant['address']?.toString() ?? '';
    openingController.text = restaurant['opening_time']?.toString() ?? '';
    closingController.text = restaurant['closing_time']?.toString() ?? '';
  }

  Future<void> _loadReservations(String restaurantId) async {
    try {
      final reservationsData = await supabase
          .from('reservations')
          .select('*')
          .eq('restaurant_id', restaurantId)
          .order('reservation_date', ascending: false);

      List<Map<String, dynamic>> enrichedReservations = [];

      for (var res in List<Map<String, dynamic>>.from(reservationsData)) {
        Map<String, dynamic> enriched = Map.from(res);

        if (res['user_id'] != null) {
          final profileRes = await supabase
              .from('profiles')
              .select('full_name, phone')
              .eq('id', res['user_id'])
              .maybeSingle();
          enriched['profiles'] = profileRes;
        }

        if (res['table_id'] != null) {
          final tableRes = await supabase
              .from('tables')
              .select('id, table_number, name')
              .eq('id', res['table_id'])
              .maybeSingle();
          enriched['tables'] = tableRes;
        }

        enrichedReservations.add(enriched);
      }

      if (!mounted) return;
      setState(() { 
        reservations = enrichedReservations; 
      });
    } catch (e) {
      debugPrint("ERREUR RESERVATIONS : $e");
    }
  }

  Future<void> _updateReservationStatus(String reservationId, String newStatus) async {
    try {
      final updatedReservation = await supabase
          .from('reservations')
          .update({'status': newStatus})
          .eq('id', reservationId)
          .select('id, restaurant_id, user_id')
          .maybeSingle();

      if (updatedReservation != null && updatedReservation['user_id'] != null) {
        final isAccepted = newStatus == 'accepted';
        final restaurantName = restaurantData!['name']?.toString() ?? widget.restaurantName;

        await NotificationService.notifyClientReservationStatus(
          clientId: updatedReservation['user_id'].toString(),
          reservationId: updatedReservation['id'].toString(),
          restaurantName: restaurantName,
          isAccepted: isAccepted,
        );
      }

      if (restaurantData != null && mounted) {
        await _loadReservations(restaurantData!['id'].toString());
      }

      // Affichage du message de confirmation (ScaffoldMessenger)
      if (!mounted) return;
      final statusMessage = newStatus == 'accepted' 
          ? "Réservation acceptée ! Réponse envoyée au client." 
          : "Réservation refusée. Réponse envoyée au client.";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(statusMessage),
          backgroundColor: newStatus == 'accepted' ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

    } catch (e) {
      _showError("Erreur : $e");
    }
  }
   
  Future<void> _saveRestaurantProfile() async {
    if (restaurantData == null) return;
    setState(() => isSaving = true);

    try {
      final restaurantId = restaurantData!['id'].toString();
      final galleryString = restaurantPhotos.join(',');

      await supabase.from('restaurants').update({
        'name': nameController.text.trim(),
        'category': categoryController.text.trim(),
        'description': descriptionController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'opening_time': openingController.text.trim(),
        'closing_time': closingController.text.trim(),
        'gallery_urls': galleryString,
      }).eq('id', restaurantId);

      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour !")));
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showError("Erreur : $e");
    }
  }

  Future<void> _pickAndUploadMultiplePhotos() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 70);

    if (pickedFiles.isEmpty) return;

    setState(() => isUploadingPhoto = true);

    try {
      List<String> newUploadedUrls = [];

      for (var file in pickedFiles) {
        final bytes = await file.readAsBytes();
        final fileExt = file.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'restaurant_photos/$fileName';

        await supabase.storage.from('restaurants').uploadBinary(filePath, bytes);
        final imageUrl = supabase.storage.from('restaurants').getPublicUrl(filePath);
        newUploadedUrls.add(imageUrl);
      }

      setState(() {
        restaurantPhotos.addAll(newUploadedUrls);
        isUploadingPhoto = false;
      });

      await _saveRestaurantProfile(); 
    } catch (e) {
      setState(() => isUploadingPhoto = false);
      _showError("Erreur lors de l'upload des images : $e");
    }
  }

  void _removePhoto(int index) {
    setState(() {
      restaurantPhotos.removeAt(index);
    });
    _saveRestaurantProfile();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor, 
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (errorMessage != null || restaurantData == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(restaurantData == null ? Icons.storefront : Icons.error_outline, size: 60, color: primaryColor),
                const SizedBox(height: 16),
                Text(errorMessage ?? "Aucun restaurant associé", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                  onPressed: () => restaurantData == null 
                      ? Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRestaurantScreen())).then((_) => _checkAuthAndLoadData()) 
                      : _checkAuthAndLoadData(),
                  child: Text(restaurantData == null ? "Créer mon restaurant" : "Réessayer"),
                )
              ],
            ),
          ),
        ),
      );
    }

    final String restId = restaurantData!['id'].toString();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: IndexedStack(
            key: ValueKey<int>(_currentIndex),
            index: _currentIndex,
            children: [
              _buildActivityTab(restId),
              RestaurantTablesScreen(restaurantId: restId, restaurantSlug: widget.restaurantSlug, restaurantName: widget.restaurantName),
              RestaurantMenuScreen(restaurantId: restId, isRestaurantOwner: true),
              _buildProfileTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            restaurantData!['name']?.toString() ?? "Savora", 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          Text(
            restaurantData!['category']?.toString() ?? "Restaurant", 
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_2, color: Colors.black87),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => RestaurantTableQrCodeDialog(
              restaurantSlug: widget.restaurantSlug, 
              restaurantName: widget.restaurantName,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87),
          onPressed: () => Navigator.push(
            context, MaterialPageRoute(
              builder: (_) => const RestaurantNotificationsScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) {
        setState(() => _currentIndex = idx);
      },
      backgroundColor: Colors.white,
      indicatorColor: primaryColor.withOpacity(0.12),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: primaryColor), label: 'Activité'),
        NavigationDestination(icon: Icon(Icons.table_bar_outlined), selectedIcon: Icon(Icons.table_bar, color: primaryColor), label: 'Tables'),
        NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu, color: primaryColor), label: 'Menu'),
        NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store, color: primaryColor), label: 'Restaurant'),
      ],
    );
  }

  Widget _buildActivityTab(String restId) {
    final pending = reservations.where((r) => r['status'] == 'pending').length;

    // Intégration du RefreshIndicator pour permettre le rafraîchissement par glissement vers le bas
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _handleRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickCard("Commandes", Icons.shopping_bag_outlined, Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantOrdersScreen(restaurantId: restId)));
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickCard("Promos", Icons.local_offer_outlined, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantPromotionsScreen(restaurantId: restId)));
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickCard("Stats", Icons.bar_chart_rounded, primaryColor, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantStatsScreen(restaurantId: restId)));
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReviewsCard(restId),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Réservations (Temps Réel)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (pending > 0)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Text("$pending en attente", style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (reservations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text("Aucune réservation pour le moment", style: TextStyle(color: Colors.grey))),
            )
          else
            ...reservations.map(_buildReservationCard),
        ],
      ),
    );
  }

  Widget _buildQuickCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title, 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsCard(String restId) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantReviewsScreen(restaurantId: restId)));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star_rounded, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Avis & Réputation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 2),
                    Text("Voir la note moyenne et les commentaires clients", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> res) {
    final name = res['client_name']?.toString().isNotEmpty == true 
        ? res['client_name'] 
        : (res['profiles']?['full_name'] ?? "Client");
        
    final phone = res['phone']?.toString().isNotEmpty == true
        ? res['phone']
        : (res['profiles']?['phone'] ?? "Aucun téléphone");

    final tableInfo = res['tables'];
    final status = res['status'] ?? 'pending';

    final String tableName = tableInfo is Map
        ? (tableInfo["name"] != null && tableInfo["name"].toString().isNotEmpty
            ? "${tableInfo["name"]} (Table n°${tableInfo["table_number"] ?? '--'})"
            : "Table n°${tableInfo["table_number"] ?? '--'}")
        : "Non assignée";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("${res['reservation_date']} à ${res['reservation_time']}", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 16),
                  const Icon(Icons.people, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("${res['guests']} pers.", style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.table_restaurant, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(tableName, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _updateReservationStatus(res['id'].toString(), 'rejected'),
                        child: const Text("Refuser"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _updateReservationStatus(res['id'].toString(), 'accepted'),
                        child: const Text("Accepter"),
                      ),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = Colors.orange.shade50;
    Color text = Colors.orange.shade800;
    String label = "En attente";

    if (status == 'accepted') { 
      bg = Colors.green.shade50; 
      text = Colors.green.shade800; 
      label = "Acceptée"; 
    } else if (status == 'rejected') { 
      bg = Colors.red.shade50; 
      text = Colors.red.shade800; 
      label = "Refusée"; 
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Informations Établissement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),

        _buildTextField(nameController, "Nom du restaurant", Icons.store),
        _buildTextField(categoryController, "Catégorie", Icons.category),
        _buildTextField(phoneController, "Téléphone", Icons.phone, keyboardType: TextInputType.phone),
        _buildTextField(addressController, "Adresse", Icons.location_on),
        Row(
          children: [
            Expanded(child: _buildTextField(openingController, "Ouverture", Icons.access_time)),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(closingController, "Fermeture", Icons.access_time)),
          ],
        ),
        _buildTextField(descriptionController, "Description", Icons.description, maxLines: 3),

        const SizedBox(height: 10),

        const Text("Photos de la galerie", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: restaurantPhotos.length + 1,
            itemBuilder: (context, index) {
              if (index == restaurantPhotos.length) {
                return InkWell(
                  onTap: isUploadingPhoto ? null : _pickAndUploadMultiplePhotos,
                  child: Container(
                    width: 110,
                    height: 110,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Center(
                      child: isUploadingPhoto
                          ? const CircularProgressIndicator(color: primaryColor)
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: Colors.grey),
                                SizedBox(height: 4),
                                Text("Ajouter", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                );
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 110,
                height: 110,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(restaurantPhotos[index]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor, 
              foregroundColor: Colors.white, 
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: isSaving ? null : _saveRestaurantProfile,
            child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Enregistrer les modifications"),
          ),
        ),

        const SizedBox(height: 24),
        RestaurantServicesCard(
          restaurantId: restaurantData!['id'].toString(),
          initialServices: (restaurantData?['services'] as List?)?.map((e) => e.toString()).toList() ?? [],
          primaryColor: primaryColor,
        ),

        const SizedBox(height: 20),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async {
            await supabase.auth.signOut();
            _checkAuthAndLoadData();
          },
          icon: const Icon(Icons.logout),
          label: const Text("Se déconnecter"),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class RestaurantServicesCard extends StatefulWidget {
  final String restaurantId;
  final List<String> initialServices;
  final Color primaryColor;

  const RestaurantServicesCard({
    super.key, 
    required this.restaurantId, 
    required this.initialServices, 
    required this.primaryColor,
  });

  @override
  State<RestaurantServicesCard> createState() => _RestaurantServicesCardState();
}

class _RestaurantServicesCardState extends State<RestaurantServicesCard> {
  late List<String> _selectedServices;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedServices = List.from(widget.initialServices);
  }

  @override
  Widget build(BuildContext context) {
    final services = RestaurantService.availableServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Services & Équipements", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: services.map((service) {
            final isExpanded = _selectedServices.contains(service.id);
            return FilterChip(
              label: Text("${service.icon} ${service.label}"),
              selected: isExpanded,
              selectedColor: widget.primaryColor.withOpacity(0.2),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedServices.add(service.id);
                  } else {
                    _selectedServices.remove(service.id);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isSaving ? null : () async {
              setState(() => _isSaving = true);
              await Supabase.instance.client
                  .from('restaurants')
                  .update({'services': _selectedServices})
                  .eq('id', widget.restaurantId);
              if (mounted) setState(() => _isSaving = false);
            },
            child: const Text("Sauvegarder les services"),
          ),
        ),
      ],
    );
  }
}