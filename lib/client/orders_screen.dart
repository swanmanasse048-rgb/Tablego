import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  final supabase = Supabase.instance.client;
  static const Color primaryColor = Color(0xFF6D1B2B);

  late Future<List<Map<String, dynamic>>> _clientOrdersFuture;

  @override
  void initState() {
    super.initState();
    _loadClientOrders();
  }

  void _loadClientOrders() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _clientOrdersFuture = Future.value([]);
      return;
    }

    _clientOrdersFuture = supabase
        .from('orders')
        .select('*, order_items(*), restaurants(name, image_url)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _loadClientOrders();
    });
    await _clientOrdersFuture;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente de validation';
      case 'accepted':
        return 'Acceptée (Facturée)';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête !';
      case 'completed':
        return 'Terminée';
      case 'rejected':
        return 'Rejetée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  void _showPaymentBottomSheet(BuildContext context, Map<String, dynamic> order) {
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final orderId = order['id'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Mode de paiement",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Montant total à régler : \$$totalAmount",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.orange),
              title: const Text("Mobile Money"),
              subtitle: const Text("Payer via Airtel / Orange Money"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MobileMoneyPaymentScreen(
                      orderId: orderId,
                      amount: totalAmount,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: const Text("Payer sur place"),
              subtitle: const Text("Régler directement au comptoir du restaurant"),
              onTap: () async {
                Navigator.pop(context);

                // Mise à jour Supabase pour paiement sur place
                await supabase.from('orders').update({
                  'payment_status': 'cash_on_delivery',
                }).eq('id', orderId);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Commande confirmée pour paiement sur place.")),
                  );
                  _refreshOrders();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Mes Commandes & Factures", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _refreshOrders,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _clientOrdersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }
            if (snapshot.hasError) {
              return Center(child: Text("Erreur : ${snapshot.error}", style: const TextStyle(color: Colors.red)));
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text("Vous n'avez pas encore passé de commande.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                final status = order['status'] ?? 'pending';
                final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                final restaurant = order['restaurants'] as Map<String, dynamic>?;
                final restaurantName = restaurant?['name'] ?? 'Restaurant';
                final items = order['order_items'] as List<dynamic>? ?? [];
                final orderType = order['order_type'] == 'dine_in' ? 'Sur place' : 'À emporter';
                final note = order['note'] ?? '';

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
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                restaurantName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getStatusLabel(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Type : $orderType", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                        ),
                        const Text("Détails de la commande :", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 6),
                        ...items.map((item) {
                          final quantity = item['quantity'] ?? 1;
                          final productName = item['product_name'] ?? 'Plat';
                          final itemPrice = item['price'] != null ? "\$${item['price']}" : "";

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "• $quantity x $productName",
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                                if (itemPrice.isNotEmpty)
                                  Text(itemPrice, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                          );
                        }),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text("Note : $note", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Montant de la facture :",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              totalAmount > 0 ? "\$$totalAmount" : "En attente du prix...",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: totalAmount > 0 ? primaryColor : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                        if (totalAmount > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showPaymentBottomSheet(context, order),
                              child: const Text("Confirmer / Payer la facture"),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class MobileMoneyPaymentScreen extends StatefulWidget {
  final dynamic orderId;
  final double amount;

  const MobileMoneyPaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
  });

  @override
  State<MobileMoneyPaymentScreen> createState() => _MobileMoneyPaymentScreenState();
}

class _MobileMoneyPaymentScreenState extends State<MobileMoneyPaymentScreen> {
  final supabase = Supabase.instance.client;
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  void _processPayment() async {
    if (_phoneController.text.trim().isEmpty || _pinController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulation du délai de paiement Mobile Money
      await Future.delayed(const Duration(seconds: 2));

      // Mise à jour du statut dans Supabase
      await supabase.from('orders').update({
        'payment_status': 'paid',
        'status': 'completed',
      }).eq('id', widget.orderId);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Paiement validé avec succès ! Le restaurant a reçu l'argent."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paiement Mobile Money"),
        backgroundColor: const Color(0xFF6D1B2B),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Montant à payer : \$${widget.amount}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text("Entrez votre numéro de téléphone (Airtel / M-Pesa / Orange) :"),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "+243 ...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Code PIN :"),
            const SizedBox(height: 10),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 5,
              decoration: InputDecoration(
                hintText: "*****",
                counterText: "",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isLoading ? null : _processPayment,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Valider le paiement", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}