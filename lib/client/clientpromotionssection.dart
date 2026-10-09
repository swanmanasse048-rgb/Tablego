import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientPromotionsSection extends StatefulWidget {
  final String? restaurantId; // Facultatif : filtre par restaurant si renseigné

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

  // Fonction pour afficher la promotion en grand format
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
                // Image en grand avec bouton de fermeture superposé
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
                    // Bouton fermer
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
                    // Badge de réduction si existant
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
                // Détails de l'offre
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
                          color: Colors.black 
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
        height: 160,
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (promotions.isEmpty) {
      return const SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Promotions & Offres 🔥",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
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
                    // Rend la carte cliquable pour ouvrir la vue détaillée
                    onTap: () => _showPromotionDetails(context, promo),
                    child: Stack(
                      children: [
                        // Image de fond de l'offre
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

                        // Gradient assombrissant pour lisibilité du texte
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

                        // Badge Réduction
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

                        // Informations de l'offre
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