import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantOrdersScreen extends StatefulWidget {
  final String restaurantId;

  const RestaurantOrdersScreen({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantOrdersScreen> createState() => _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends State<RestaurantOrdersScreen> {
  final supabase = Supabase.instance.client;
  static const Color primaryColor = Color(0xFF6D1B2B);

  String selectedFilter = 'all';

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Statut mis à jour : $newStatus"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de mise à jour : $e")),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Commandes reçues"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtres par statut
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Toutes', 'all'),
                _buildFilterChip('En attente', 'pending'),
                _buildFilterChip('En prépa', 'preparing'),
                _buildFilterChip('Prêtes', 'ready'),
                _buildFilterChip('Terminées', 'completed'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Liste des commandes en temps réel
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('orders')
                  .select('*, order_items(*), tables(name)')
                  .eq('restaurant_id', widget.restaurantId)
                  .order('created_at', ascending: false)
                  .asStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Erreur : ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                var orders = snapshot.data!;

                if (selectedFilter != 'all') {
                  orders = orders
                      .where((o) => o['status'] == selectedFilter)
                      .toList();
                }

                if (orders.isEmpty) {
                  return const Center(
                    child: Text(
                      "Aucune commande pour le moment.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final status = order['status'] ?? 'pending';
                    final items = order['order_items'] as List<dynamic>? ?? [];

                    // Données client et mode de commande
                    final customerName = order['client_name'] ?? order['customer_name'] ?? 'Client';
                    final phone = order['phone'] ?? '';
                    final orderType = order['order_type'] ?? order['fulfillment_type'] ?? 'takeaway';
                    final tableName = order['tables'] != null ? order['tables']['name'] : null;

                    final isDineIn = orderType == 'dine_in' || orderType == 'sur_place';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Commande #${order['id'].toString().substring(0, 8)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getStatusLabel(status),
                                    style: TextStyle(
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Nom du client et téléphone
                            Text(
                              "Client : $customerName ${phone.isNotEmpty ? '($phone)' : ''}",
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Badges : Mode de commande et Table (si sur place)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isDineIn ? 'Sur place' : 'À emporter',
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isDineIn && tableName != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Table : $tableName",
                                      style: const TextStyle(
                                        color: primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Divider(height: 20),

                            // Détail des articles
                            ...items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${item['quantity'] ?? 1}x ${item['product_name'] ?? 'Article'}",
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text("${item['unit_price'] ?? 0} \$"),
                                    ],
                                  ),
                                )),

                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Total",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "${order['total_amount'] ?? 0} \$",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Actions sur le statut
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'pending')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                    onPressed: () => _updateOrderStatus(
                                      order['id'].toString(),
                                      'preparing',
                                    ),
                                    child: const Text("Accepter (En prépa)",
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                if (status == 'preparing')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                    ),
                                    onPressed: () => _updateOrderStatus(
                                      order['id'].toString(),
                                      'ready',
                                    ),
                                    child: const Text("Marquer comme Prête",
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                if (status == 'ready')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    onPressed: () => _updateOrderStatus(
                                      order['id'].toString(),
                                      'completed',
                                    ),
                                    child: const Text("Terminer la commande",
                                        style: TextStyle(color: Colors.white)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
        ),
        onSelected: (_) {
          setState(() {
            selectedFilter = value;
          });
        },
      ),
    );
  }
}