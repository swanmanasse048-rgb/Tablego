import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

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
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  late RealtimeChannel _ordersChannel;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _setupRealtimeSubscription();
  }

  // On fait la jointure avec 'profiles(full_name)' et 'tables(name)'
  void _loadOrders() {
    _ordersFuture = supabase
        .from('orders')
        .select('''
          *,
          order_items(*),
          profiles!fk_orders_profiles(full_name, phone),
          tables!fk_orders_tables(name, table_number)
        ''')
        .eq('restaurant_id', widget.restaurantId)
        .order('created_at', ascending: false)
        .then((response) => List<Map<String, dynamic>>.from(response));
  }

  void _setupRealtimeSubscription() {
    _ordersChannel = supabase
        .channel('public:orders:${widget.restaurantId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: widget.restaurantId,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              _triggerNewOrderAlert();
            }

            if (mounted) {
              setState(() {
                _loadOrders();
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _triggerNewOrderAlert() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 1000);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint("Erreur alerte : $e");
    }
  }

  @override
  void dispose() {
    supabase.removeChannel(_ordersChannel);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', orderId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Statut mis à jour : ${_getStatusLabel(newStatus)}"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPricingDialog(Map<String, dynamic> order) {
    final priceController = TextEditingController(
      text: order['total_amount'] != null && order['total_amount'] > 0 
          ? order['total_amount'].toString() 
          : '',
    );

    final profileData = order['profiles'];
    final customerName = profileData != null && profileData['full_name'] != null
        ? profileData['full_name']
        : (order['client_name'] ?? order['customer_name'] ?? order['name'] ?? 'Client');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Chiffrer la commande", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Client : $customerName", style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Montant total (\$)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final price = double.tryParse(priceController.text.trim());
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Veuillez entrer un montant valide.")),
                );
                return;
              }

              try {
                await supabase.from('orders').update({
                  'total_amount': price,
                  'status': 'accepted', 
                }).eq('id', order['id']);

                if (order['user_id'] != null) {
                  await supabase.from('notifications').insert({
                    'user_id': order['user_id'],
                    'title': 'Facture disponible ! 🧾',
                    'message': 'Le montant de votre commande est de : \$$price',
                    'type': 'invoice',
                    'reference_id': order['id'],
                    'is_read': false,
                  });
                }

                if (!mounted) return;
                Navigator.pop(context);
                setState(() {
                  _loadOrders();
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Facture envoyée avec succès !"), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur : $e")),
                );
              }
            },
            child: const Text("Envoyer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted':
      case 'preparing': return Colors.blue;
      case 'ready': return Colors.purple;
      case 'completed': return Colors.green;
      case 'rejected':
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'accepted': return 'Acceptée';
      case 'preparing': return 'En préparation';
      case 'ready': return 'Prête';
      case 'completed': return 'Terminée';
      case 'rejected': return 'Rejetée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text("Commandes reçues", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('Toutes', 'all'),
                  _buildFilterChip('En attente', 'pending'),
                  _buildFilterChip('En cours', 'preparing'),
                  _buildFilterChip('Prêtes', 'ready'),
                  _buildFilterChip('Terminées', 'completed'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Erreur : ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }

                var orders = snapshot.data ?? [];

                if (selectedFilter != 'all') {
                  if (selectedFilter == 'preparing') {
                    orders = orders.where((o) => o['status'] == 'preparing' || o['status'] == 'accepted').toList();
                  } else {
                    orders = orders.where((o) => o['status'] == selectedFilter).toList();
                  }
                }

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text("Aucune commande trouvée", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final status = order['status'] ?? 'pending';
                    final items = order['order_items'] as List<dynamic>? ?? [];
                    final paymentStatus = order['payment_status'] ?? 'unpaid';
                    
                    final profileData = order['profiles'];
                    final customerName = (profileData != null && profileData['full_name'] != null && profileData['full_name'].toString().isNotEmpty)
                        ? profileData['full_name']
                        : (order['client_name'] ?? order['customer_name'] ?? order['name'] ?? order['user_name'] ?? 'Client');

                    final phone = (profileData != null && profileData['phone'] != null && profileData['phone'].toString().isNotEmpty)
                        ? profileData['phone']
                        : (order['phone'] ?? order['customer_phone'] ?? '');

                    final orderType = order['order_type'] ?? order['type'] ?? 'takeaway';
                    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                    
                    final tableData = order['tables'];
                    String? displayTableText;

                    if (tableData != null) {
                      final tName = tableData['name']?.toString() ?? '';
                      final tNumber = tableData['table_number']?.toString() ?? '';

                      if (tName.isNotEmpty && tNumber.isNotEmpty) {
                        displayTableText = 'Table $tNumber ($tName)';
                      } else if (tNumber.isNotEmpty) {
                        displayTableText = 'Table $tNumber';
                      } else if (tName.isNotEmpty) {
                        displayTableText = tName;
                      }
                    }

                    final tableName = displayTableText ?? (order['table_name'] ?? order['table_number']?.toString());
                    final guestsCount = order['guests_count'];
                    final specialRequest = order['special_request'] ?? order['note'];
                    
                    final scheduledTime = order['scheduled_time'] ?? 
                        order['pickup_time'] ?? 
                        order['reservation_time'] ?? 
                        order['time'] ?? 
                        order['delivery_time'];

                    final isDineIn = orderType == 'dine_in' || orderType == 'sur place';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Cmd #${order['id'].toString().substring(0, 6).toUpperCase()}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getStatusLabel(status),
                                    style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Badge Statut de Paiement pour le Gérant
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: paymentStatus == 'paid' 
                                    ? Colors.green.withOpacity(0.1) 
                                    : paymentStatus == 'cash_on_delivery' 
                                        ? Colors.blue.withOpacity(0.1) 
                                        : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    paymentStatus == 'paid' 
                                        ? Icons.check_circle 
                                        : paymentStatus == 'cash_on_delivery' 
                                            ? Icons.money 
                                            : Icons.hourglass_empty,
                                    size: 14,
                                    color: paymentStatus == 'paid' 
                                        ? Colors.green 
                                        : paymentStatus == 'cash_on_delivery' 
                                            ? Colors.blue 
                                            : Colors.orange.shade800,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    paymentStatus == 'paid' 
                                        ? "Payé par Mobile Money" 
                                        : paymentStatus == 'cash_on_delivery' 
                                            ? "À payer sur place (Espèces)" 
                                            : "Non payé",
                                    style: TextStyle(
                                      color: paymentStatus == 'paid' 
                                          ? Colors.green 
                                          : paymentStatus == 'cash_on_delivery' 
                                              ? Colors.blue 
                                              : Colors.orange.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Infos Client
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                    ],
                                  ),
                                  if (phone.toString().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(phone.toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Badges (Type, Table, Heure)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDineIn ? primaryColor.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(isDineIn ? Icons.restaurant : Icons.shopping_bag, size: 14, color: isDineIn ? primaryColor : Colors.orange.shade800),
                                      const SizedBox(width: 6),
                                      Text(isDineIn ? 'Sur place' : 'À emporter', style: TextStyle(color: isDineIn ? primaryColor : Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                if (tableName != null && tableName.toString().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.table_bar, size: 14, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text("Table : $tableName", style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                if (guestsCount != null && guestsCount > 1)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text("$guestsCount pers.", style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                if (scheduledTime != null && scheduledTime.toString().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.access_time, size: 14, color: Colors.deepOrange),
                                        const SizedBox(width: 4),
                                        Text("Heure : $scheduledTime", style: const TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            if (specialRequest != null && specialRequest.toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text("Note : $specialRequest", style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontStyle: FontStyle.italic)),
                            ],

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                            ),

                            // Articles
                            ...items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Text(
                                    "${item['quantity'] ?? 1}x ${item['product_name'] ?? 'Article'}",
                                    style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                                  ),
                                )),

                            if (items.isNotEmpty) const SizedBox(height: 12),

                            // Bloc Total & Facturation
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Total", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text(
                                        totalAmount > 0 ? "\$$totalAmount" : "En attente",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: totalAmount > 0 ? primaryColor : Colors.orange.shade800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: totalAmount > 0 ? Colors.teal : primaryColor,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () => _showPricingDialog(order),
                                    icon: Icon(totalAmount > 0 ? Icons.edit : Icons.attach_money, size: 16, color: Colors.white),
                                    label: Text(
                                      totalAmount > 0 ? "Modifier" : "Chiffrer / Facturer",
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Actions de statut
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'pending') ...[
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _updateOrderStatus(order['id'].toString(), 'rejected'),
                                    child: const Text("Rejeter", style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _updateOrderStatus(order['id'].toString(), 'preparing'),
                                    child: const Text("Accepter", style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
                                if (status == 'accepted' || status == 'preparing') ...[
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _updateOrderStatus(order['id'].toString(), 'ready'),
                                    child: const Text("Marquer Prête", style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
                                if (status == 'ready') ...[
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _updateOrderStatus(order['id'].toString(), 'completed'),
                                    child: const Text("Terminer", style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
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
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: primaryColor,
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w500,
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