import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditRestaurantScreen extends StatefulWidget {
  final String restaurantId;

  const EditRestaurantScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  State<EditRestaurantScreen> createState() => _EditRestaurantScreenState();
}

class _EditRestaurantScreenState extends State<EditRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final imageController = TextEditingController();
  final openingController = TextEditingController();
  final closingController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadRestaurant();
  }

  Future<void> loadRestaurant() async {
    try {
      // FIX: Query by 'id' to match saveRestaurant (or change both to 'owner_id' if passing user ID)
      final data = await Supabase.instance.client
          .from('restaurants')
          .select()
          .eq('id', widget.restaurantId)
          .maybeSingle();

      if (data == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Restaurant introuvable."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Early return prevents accessing null data below
      }

      nameController.text = data["name"]?.toString() ?? "";
      descriptionController.text = data["description"]?.toString() ?? "";
      addressController.text = data["address"]?.toString() ?? "";
      phoneController.text = data["phone"]?.toString() ?? "";
      imageController.text = data["image_url"]?.toString() ?? "";
      openingController.text = data["opening_time"]?.toString() ?? "";
      closingController.text = data["closing_time"]?.toString() ?? "";

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("ERREUR LOAD RESTAURANT : $e");

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors du chargement : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> saveRestaurant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('restaurants')
          .update({
            "name": nameController.text.trim(),
            "description": descriptionController.text.trim(),
            "address": addressController.text.trim(),
            "phone": phoneController.text.trim(),
            "image_url": imageController.text.trim(),
            "opening_time": openingController.text.trim(),
            "closing_time": closingController.text.trim(),
          })
          .eq("id", widget.restaurantId)
          .select();

      if (response.isEmpty) {
        throw Exception(
          "Aucune modification effectuée. Vérifie les permissions Row Level Security (RLS).",
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Restaurant modifié avec succès ✅"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("UPDATE ERROR : $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Champ obligatoire";
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier le restaurant"),
        backgroundColor: const Color(0xFF6D1B2B),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    buildField(nameController, "Nom", Icons.restaurant),
                    buildField(
                      descriptionController,
                      "Description",
                      Icons.description,
                      required: false,
                    ),
                    buildField(
                      addressController,
                      "Adresse",
                      Icons.location_on,
                      required: false,
                    ),
                    buildField(
                      phoneController,
                      "Téléphone",
                      Icons.phone,
                      required: false,
                    ),
                    buildField(
                      imageController,
                      "Image URL",
                      Icons.image,
                      required: false,
                    ),
                    buildField(
                      openingController,
                      "Heure d'ouverture",
                      Icons.schedule,
                      required: false,
                    ),
                    buildField(
                      closingController,
                      "Heure de fermeture",
                      Icons.schedule,
                      required: false,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : saveRestaurant,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D1B2B),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Enregistrer",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    phoneController.dispose();
    imageController.dispose();
    openingController.dispose();
    closingController.dispose();
    super.dispose();
  }
}