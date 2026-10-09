import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantPromotionsScreen extends StatefulWidget {
  final String restaurantId;

  const RestaurantPromotionsScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantPromotionsScreen> createState() =>
      _RestaurantPromotionsScreenState();
}

class _RestaurantPromotionsScreenState
    extends State<RestaurantPromotionsScreen> {
  final supabase = Supabase.instance.client;
  static const Color primaryColor = Color(0xFF6D1B2B);
  static const Color backgroundColor = Color(0xFFF7F7F8);

  List<Map<String, dynamic>> promotions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('promotions')
          .select()
          .eq('restaurant_id', widget.restaurantId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        promotions = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement promotions: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _togglePromotionStatus(String promoId, bool currentStatus) async {
    try {
      await supabase
          .from('promotions')
          .update({'is_active': !currentStatus})
          .eq('id', promoId);

      _loadPromotions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
      );
    }
  }

  Future<void> _deletePromotion(String promoId) async {
    try {
      await supabase.from('promotions').delete().eq('id', promoId);
      _loadPromotions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Promotion supprimée avec succès"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la suppression : $e")),
      );
    }
  }

  void _onPromotionTap(Map<String, dynamic> promo) {
    final imageUrl = promo['image_url'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.toString().trim().isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo['title'] ?? 'Détails de l\'offre',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      promo['description'] ?? 'Aucune description supplémentaire.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer", style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showAddPromotionModal() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final originalPriceController = TextEditingController();
    final promoPriceController = TextEditingController();

    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    XFile? pickedImage;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyDiscount(int percent) {
              final orig = double.tryParse(originalPriceController.text.trim());
              if (orig != null && orig > 0) {
                final promo = orig * (1 - (percent / 100));
                promoPriceController.text = promo.toStringAsFixed(2);
                setModalState(() {});
              }
            }

            double? calculateDiscount() {
              final orig = double.tryParse(originalPriceController.text.trim());
              final promo = double.tryParse(promoPriceController.text.trim());
              if (orig != null && promo != null && orig > 0 && promo < orig) {
                return ((orig - promo) / orig) * 100;
              }
              return null;
            }

            final discountPercent = calculateDiscount();

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Nouvelle Promotion",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (discountPercent != null)
                          Chip(
                            backgroundColor: primaryColor.withOpacity(0.1),
                            label: Text(
                              "-${discountPercent.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Photo du plat
                    GestureDetector(
                      onTap: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          setModalState(() => pickedImage = image);
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: pickedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(pickedImage!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo_outlined,
                                      size: 24, color: primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Ajouter une photo (facultatif)",
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: "Titre de l'offre (ex: Menu Duo Gourmand)",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Description courte",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Prix
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: originalPriceController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: "Prix normal (\$)",
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: promoPriceController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: "Prix promo (\$)",
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Boutons de réduction rapide en 1 clic
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Text("Réduction rapide :", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ActionChip(
                          label: const Text("-10%"),
                          onPressed: () => applyDiscount(10),
                        ),
                        ActionChip(
                          label: const Text("-20%"),
                          onPressed: () => applyDiscount(20),
                        ),
                        ActionChip(
                          label: const Text("-50%"),
                          onPressed: () => applyDiscount(50),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Raccourcis de durée intelligents
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                startDate = DateTime.now();
                                endDate = DateTime.now().add(const Duration(days: 7));
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Durée fixée à 7 jours")),
                              );
                            },
                            child: const Text("Durée : 7 jours", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                startDate = DateTime.now();
                                endDate = DateTime.now().add(const Duration(days: 30));
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Durée fixée à 30 jours")),
                              );
                            },
                            child: const Text("Durée : 30 jours", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bouton de publication
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isUploading
                            ? null
                            : () async {
                                if (titleController.text.trim().isEmpty ||
                                    originalPriceController.text.trim().isEmpty ||
                                    promoPriceController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Veuillez remplir le titre et les prix"),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isUploading = true);

                                try {
                                  String? imageUrl;

                                  if (pickedImage != null) {
                                    final file = File(pickedImage!.path);
                                    final fileExt = pickedImage!.name.split('.').last;
                                    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                                    final filePath = 'promotions/$fileName';

                                    await supabase.storage
                                        .from('restaurant-media')
                                        .upload(filePath, file);

                                    imageUrl = supabase.storage
                                        .from('restaurant-media')
                                        .getPublicUrl(filePath);
                                  }

                                  final origPrice = double.tryParse(
                                          originalPriceController.text.trim()) ??
                                      0.0;
                                  final promoPrice = double.tryParse(
                                          promoPriceController.text.trim()) ??
                                      0.0;
                                  final calcDiscount = origPrice > 0
                                      ? (((origPrice - promoPrice) / origPrice) *
                                              100)
                                          .round()
                                      : 0;

                                  await supabase.from('promotions').insert({
                                    'restaurant_id': widget.restaurantId,
                                    'title': titleController.text.trim(),
                                    'description': descController.text.trim(),
                                    'original_price': origPrice,
                                    'promo_price': promoPrice,
                                    'discount_percentage': calcDiscount,
                                    'image_url': imageUrl,
                                    'start_date': startDate.toIso8601String(),
                                    'end_date': endDate.toIso8601String(),
                                    'is_active': true,
                                  });

                                  if (!mounted) return;
                                  Navigator.pop(modalContext);
                                  _loadPromotions();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Promotion publiée avec succès !"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint("Erreur création promotion : $e");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Erreur lors de la publication : $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  setModalState(() => isUploading = false);
                                }
                              },
                        child: isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Publier la promotion",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Promotions & Offres", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: _showAddPromotionModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nouvelle offre", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : promotions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_outlined,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        "Aucune promotion active",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Ajoutez une offre pour attirer plus de clients.",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: promotions.length,
                  itemBuilder: (context, index) {
                    final promo = promotions[index];
                    final isActive = promo['is_active'] ?? true;
                    final imageUrl = promo['image_url'];
                    final double? origPrice = promo['original_price'] != null
                        ? double.tryParse(promo['original_price'].toString())
                        : null;
                    final double? promoPrice = promo['promo_price'] != null
                        ? double.tryParse(promo['promo_price'].toString())
                        : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _onPromotionTap(promo),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrl != null &&
                                imageUrl.toString().trim().isNotEmpty)
                              Stack(
                                children: [
                                  Image.network(
                                    imageUrl,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      height: 100,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Icon(Icons.broken_image,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  if (promo['discount_percentage'] != null)
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
                                          "-${promo['discount_percentage']}%",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          promo['title'] ?? 'Offre spéciale',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Switch(
                                        value: isActive,
                                        activeColor: primaryColor,
                                        onChanged: (_) => _togglePromotionStatus(
                                          promo['id'].toString(),
                                          isActive,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (promo['description'] != null &&
                                      promo['description'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        promo['description'],
                                        style: TextStyle(
                                            color: Colors.grey.shade600, fontSize: 13),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (origPrice != null)
                                        Text(
                                          "\$$origPrice",
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      if (promoPrice != null)
                                        Text(
                                          "\$$promoPrice",
                                          style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 20),
                                        onPressed: () => _deletePromotion(
                                          promo['id'].toString(),
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
                    );
                  },
                ),
    );
  }
}