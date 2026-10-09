import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateRestaurantScreen extends StatefulWidget {
  const CreateRestaurantScreen({super.key});

  @override
  State<CreateRestaurantScreen> createState() =>
      _CreateRestaurantScreenState();
}

class _CreateRestaurantScreenState
    extends State<CreateRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final openingController = TextEditingController();
  final closingController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> selectedImages = [];
  bool isLoading = false;

  static const Color primaryColor = Color(0xFF6D1B2B);
  static const Color backgroundColor = Color(0xFFF7F7F8);

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    phoneController.dispose();
    openingController.dispose();
    closingController.dispose();
    super.dispose();
  }

  // ============================================================
  // GENERATEUR DE SLUG
  // ============================================================

  String _generateSlug(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  // ============================================================
  // SÉLECTION DES HEURES (TimePicker)
  // ============================================================

  Future<void> _selectTime(
      BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hours = picked.hour.toString().padLeft(2, '0');
      final minutes = picked.minute.toString().padLeft(2, '0');
      setState(() {
        controller.text = "$hours:$minutes";
      });
    }
  }

  // ============================================================
  // SELECTION DES PHOTOS
  // ============================================================

  Future<void> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1800,
      );

      if (images.isEmpty) return;

      setState(() {
        selectedImages.addAll(images);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible de sélectionner les photos : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  // ============================================================
  // UPLOAD DES PHOTOS
  // ============================================================

  Future<List<String>> uploadImages(String restaurantId) async {
    final supabase = Supabase.instance.client;
    List<String> imageUrls = [];

    for (int i = 0; i < selectedImages.length; i++) {
      final image = selectedImages[i];
      final file = File(image.path);
      final extension = image.path.split('.').last.toLowerCase();
      final fileName =
          '${restaurantId}_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';
      final filePath = '$restaurantId/$fileName';

      await supabase.storage.from('restaurant-images').upload(
            filePath,
            file,
            fileOptions: FileOptions(
              contentType: _getContentType(extension),
              upsert: false,
            ),
          );

      final publicUrl = supabase.storage
          .from('restaurant-images')
          .getPublicUrl(filePath);

      imageUrls.add(publicUrl);
    }

    return imageUrls;
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ============================================================
  // CREATION DU RESTAURANT
  // ============================================================

  Future<void> createRestaurant() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner au moins une photo du restaurant."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vous devez être connecté pour créer un restaurant."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final restaurantName = nameController.text.trim();
      final slug = _generateSlug(restaurantName);

      final restaurant = await supabase
          .from('restaurants')
          .insert({
            'owner_id': user.id,
            'name': restaurantName,
            'slug': slug,
            'description': descriptionController.text.trim(),
            'address': addressController.text.trim(),
            'phone': phoneController.text.trim(),
            'opening_time': openingController.text.trim(),
            'closing_time': closingController.text.trim(),
          })
          .select()
          .single();

      final restaurantId = restaurant['id'].toString();
      final imageUrls = await uploadImages(restaurantId);

      if (imageUrls.isEmpty) {
        throw Exception("Aucune image n'a pu être envoyée.");
      }

      await supabase
          .from('restaurants')
          .update({
            'image_url': imageUrls.first,
            'gallery_urls': imageUrls,
          })
          .eq('id', restaurantId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Restaurant créé avec succès !"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // WIDGET CHAMP DE FORMULAIRE
  // ============================================================

  Widget buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Champ obligatoire";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:  const BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GALERIE PHOTO DESIGN
  // ============================================================

  Widget buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Photos de l'établissement",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          "La première photo sera la couverture principale.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 135,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: isLoading ? null : pickImages,
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 26,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Ajouter",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...selectedImages.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;

                return Container(
                  width: 135,
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(image.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "Principale",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: InkWell(
                          onTap: () => removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Créer mon restaurant",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: isLoading
          ? Stack(
              children: [
                _buildForm(),
                Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.all(30),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: primaryColor,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Création en cours...",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Envoi des images vers le serveur...",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Informations générales",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            buildField(
              controller: nameController,
              label: "Nom du restaurant",
              icon: Icons.restaurant_rounded,
            ),
            buildField(
              controller: descriptionController,
              label: "Description (ambiance, spécialités...)",
              icon: Icons.description_rounded,
              maxLines: 3,
            ),
            buildField(
              controller: addressController,
              label: "Adresse complète",
              icon: Icons.location_on_rounded,
            ),
            buildField(
              controller: phoneController,
              label: "Téléphone de contact",
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            buildImageGallery(),
            const Text(
              "Horaires d'ouverture",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: buildField(
                    controller: openingController,
                    label: "Ouverture",
                    icon: Icons.access_time_rounded,
                    readOnly: true,
                    onTap: () => _selectTime(context, openingController),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildField(
                    controller: closingController,
                    label: "Fermeture",
                    icon: Icons.access_time_filled_rounded,
                    readOnly: true,
                    onTap: () => _selectTime(context, closingController),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : createRestaurant,
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: const Text(
                  "Enregistrer le restaurant",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}