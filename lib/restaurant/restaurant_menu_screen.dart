
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final String restaurantId;

  /// true = espace restaurateur
  /// false = espace client
  final bool isRestaurantOwner;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurantId,
    this.isRestaurantOwner = false,
  });

  @override
  State<RestaurantMenuScreen> createState() =>
      _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState
    extends State<RestaurantMenuScreen> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  static const Color primaryColor = Color(0xFF6D1B2B);
  static const Color backgroundColor = Color(0xFFF7F7F8);

  List<String> menuUrls = [];
  bool isLoading = true;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  // ============================================================
  // CHARGER LE MENU
  // ============================================================

  Future<void> _loadMenu() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('restaurants')
          .select('menu_urls')
          .eq('id', widget.restaurantId)
          .maybeSingle();

      if (response == null) {
        if (!mounted) return;
        setState(() {
          menuUrls = [];
          isLoading = false;
        });
        return;
      }

      final value = response['menu_urls'];
      final loadedUrls = <String>[];

      if (value is List) {
        for (final item in value) {
          if (item != null &&
              item.toString().trim().isNotEmpty) {
            loadedUrls.add(item.toString().trim());
          }
        }
      }

      if (!mounted) return;
      setState(() {
        menuUrls = loadedUrls;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("ERREUR CHARGEMENT MENU : $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      _showError("Impossible de charger le menu.");
    }
  }

  // ============================================================
  // SÉLECTION ET UPLOAD DIRECT (Simplification extrême pour le gérant)
  // ============================================================

  Future<void> _pickAndUploadImages() async {
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1800,
      );

      if (images.isEmpty) return;

      setState(() {
        isUploading = true;
      });

      final uploadedUrls = <String>[];

      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final bytes = await image.readAsBytes();

        final extension = image.name.contains('.')
            ? image.name.split('.').last.toLowerCase()
            : 'jpg';

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '$timestamp-$i.$extension';
        final filePath = '${widget.restaurantId}/menu/$fileName';

        await supabase.storage
            .from('restaurant-images')
            .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(image.name),
            upsert: false,
          ),
        );

        final publicUrl = supabase.storage
            .from('restaurant-images')
            .getPublicUrl(filePath);

        uploadedUrls.add(publicUrl);
      }

      // Mise à jour directe dans Supabase
      final updatedUrls = [...menuUrls, ...uploadedUrls];

      await supabase
          .from('restaurants')
          .update({'menu_urls': updatedUrls})
          .eq('id', widget.restaurantId);

      if (!mounted) return;

      setState(() {
        menuUrls = updatedUrls;
        isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pages ajoutées avec succès !"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("ERREUR AJOUT MENU : $e");
      if (!mounted) return;
      setState(() {
        isUploading = false;
      });
      _showError("Erreur lors de l'envoi des images.");
    }
  }

  String _getContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  // ============================================================
  // SUPPRIMER UNE PAGE
  // ============================================================

  Future<void> _deleteMenuPage(int index) async {
    if (!widget.isRestaurantOwner) return;
    if (index < 0 || index >= menuUrls.length) return;

    final url = menuUrls[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Supprimer cette page ?"),
          content: const Text("Cette page sera définitivement retirée de votre menu."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _deleteStorageFileFromUrl(url);

      final updatedUrls = List<String>.from(menuUrls);
      updatedUrls.removeAt(index);

      await supabase
          .from('restaurants')
          .update({'menu_urls': updatedUrls})
          .eq('id', widget.restaurantId);

      if (!mounted) return;

      setState(() {
        menuUrls = updatedUrls;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Page supprimée."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("ERREUR SUPPRESSION MENU : $e");
      _showError("Impossible de supprimer cette page.");
    }
  }

  Future<void> _deleteStorageFileFromUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('restaurant-images');

      if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
        final filePath = segments.sublist(bucketIndex + 1).join('/');
        await supabase.storage.from('restaurant-images').remove([filePath]);
      }
    } catch (e) {
      debugPrint("ERREUR DELETE STORAGE MENU : $e");
    }
  }

  void _openMenuPage(int index) {
    if (index < 0 || index >= menuUrls.length) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MenuViewerScreen(
          menuUrls: menuUrls,
          initialIndex: index,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          widget.isRestaurantOwner ? "Gestion du Menu" : "Menu du restaurant",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: widget.isRestaurantOwner
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: primaryColor),
                    onPressed: isUploading ? null : _pickAndUploadImages,
                    icon: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          )
                        : const Icon(Icons.add_photo_alternate_rounded, size: 20),
                    label: Text(isUploading ? "Envoi..." : "Ajouter"),
                  ),
                ),
              ]
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : menuUrls.isEmpty
              ? _buildEmptyState()
              : _buildMenuGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_rounded, size: 50, color: primaryColor),
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucune page de menu",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isRestaurantOwner 
               ? "Commencez par ajouter les photos de votre menu papier ou numérique." : 
                 "Ce restaurant n'a pas encore publié son menu.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            if (widget.isRestaurantOwner) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: isUploading ? null : _pickAndUploadImages,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Ajouter des pages", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadMenu,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: menuUrls.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openMenuPage(index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      menuUrls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                        );
                      },
                    ),
                    // Badge numéro de page
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Page ${index + 1}",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // Bouton de suppression rapide pour le propriétaire
                    if (widget.isRestaurantOwner)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: InkWell(
                          onTap: () => _deleteMenuPage(index),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// VISUALISEUR DU MENU (Plein écran avec zoom)
// ================================================================

class _MenuViewerScreen extends StatefulWidget {
  final List<String> menuUrls;
  final int initialIndex;

  const _MenuViewerScreen({
    required this.menuUrls,
    required this.initialIndex,
  });

  @override
  State<_MenuViewerScreen> createState() => _MenuViewerScreenState();
}

class _MenuViewerScreenState extends State<_MenuViewerScreen> {
  late PageController _pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Page ${currentIndex + 1} / ${widget.menuUrls.length}",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.menuUrls.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.menuUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 50),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}