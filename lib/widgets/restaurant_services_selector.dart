import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant_service.dart';

class RestaurantServicesSelector extends StatefulWidget {
  final String restaurantId;
  final List<String> initialServices;

  const RestaurantServicesSelector({
    super.key,
    required this.restaurantId,
    this.initialServices = const [],
  });

  @override
  State<RestaurantServicesSelector> createState() =>
      _RestaurantServicesSelectorState();
}

class _RestaurantServicesSelectorState
    extends State<RestaurantServicesSelector> {
  late List<String> _selectedServices;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedServices = List.from(widget.initialServices);
  }

  @override
  void didUpdateWidget(covariant RestaurantServicesSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialServices != widget.initialServices) {
      setState(() {
        _selectedServices = List.from(widget.initialServices);
      });
    }
  }

  Future<void> _saveServices() async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('restaurants')
          .update({'services': _selectedServices})
          .eq('id', widget.restaurantId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Services mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Services & Équipements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Sélectionnez les options proposées dans votre restaurant :',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: RestaurantService.availableServices.length,
              itemBuilder: (context, index) {
                final service = RestaurantService.availableServices[index];
                final isSelected = _selectedServices.contains(service.id);

                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFFD97706),
                  title: Text('${service.icon}  ${service.label}'),
                  value: isSelected,
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedServices.add(service.id);
                      } else {
                        _selectedServices.remove(service.id);
                      }
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveServices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Enregistrer les services',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}