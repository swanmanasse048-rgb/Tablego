import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantStatsScreen extends StatefulWidget {
  final String restaurantId;

  const RestaurantStatsScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantStatsScreen> createState() => _RestaurantStatsScreenState();
}

class _RestaurantStatsScreenState extends State<RestaurantStatsScreen> {
  final supabase = Supabase.instance.client;
  static const Color primaryColor = Color(0xFF6D1B2B);

  bool isLoading = true;
  String selectedFilter = 'all'; // 'today', 'week', 'month', 'all'

  // Statistiques Globales
  int totalReservations = 0;
  int pendingReservations = 0;
  int acceptedReservations = 0;
  int rejectedReservations = 0;
  
  int totalOrders = 0;
  double totalRevenue = 0.0;
  
  // Ventilation du CA par type
  double dineInRevenue = 0.0;
  int dineInOrdersCount = 0;
  double takeawayRevenue = 0.0;
  int takeawayOrdersCount = 0;

  // Top des heures de pointe
  Map<String, int> peakHours = {};

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => isLoading = true);
    try {
      // Calcul des dates limites selon le filtre sélectionné
      DateTime? startDate;
      final now = DateTime.now();
      if (selectedFilter == 'today') {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (selectedFilter == 'week') {
        startDate = now.subtract(const Duration(days: 7));
      } else if (selectedFilter == 'month') {
        startDate = DateTime(now.year, now.month - 1, now.day);
      }

      // 1. Récupération des réservations
      var reservationQuery = supabase
          .from('reservations')
          .select('status, guests, reservation_time, created_at')
          .eq('restaurant_id', widget.restaurantId);

      final reservationsRes = await reservationQuery;
      final List allReservations = reservationsRes as List;

      // Filtrage manuel par date si nécessaire
      List filteredReservations = allReservations;
      if (startDate != null) {
        filteredReservations = allReservations.where((r) {
          final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '') ?? now;
          return createdAt.isAfter(startDate!);
        }).toList();
      }

      totalReservations = filteredReservations.length;
      pendingReservations = filteredReservations.where((r) => r['status'] == 'pending').length;
      acceptedReservations = filteredReservations.where((r) => r['status'] == 'accepted').length;
      rejectedReservations = filteredReservations.where((r) => r['status'] == 'rejected').length;

      // Calcul des horaires les plus fréquentés
      Map<String, int> hoursCount = {};
      for (var res in filteredReservations) {
        final timeString = res['reservation_time']?.toString();
        if (timeString != null && timeString.isNotEmpty) {
          String formattedHour = timeString.length >= 5 ? timeString.substring(0, 5) : timeString;
          hoursCount[formattedHour] = (hoursCount[formattedHour] ?? 0) + 1;
        }
      }

      var sortedHours = hoursCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      peakHours = {for (var e in sortedHours) e.key: e.value};

      // 2. Récupération des commandes payées uniquement ('paid')
      var orderQuery = supabase
          .from('orders')
          .select('total_amount, order_type, created_at, payment_status')
          .eq('restaurant_id', widget.restaurantId)
          .eq('payment_status', 'paid'); // <--- Filtre strict sur l'argent payé

      final ordersRes = await orderQuery;
      final List allOrders = ordersRes as List;

      List filteredOrders = allOrders;
      if (startDate != null) {
        filteredOrders = allOrders.where((o) {
          final createdAt = DateTime.tryParse(o['created_at']?.toString() ?? '') ?? now;
          return createdAt.isAfter(startDate!);
        }).toList();
      }

      totalOrders = filteredOrders.length;
      totalRevenue = 0.0;
      dineInRevenue = 0.0;
      dineInOrdersCount = 0;
      takeawayRevenue = 0.0;
      takeawayOrdersCount = 0;

      for (var order in filteredOrders) {
        final amount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;
        final type = order['order_type']?.toString() ?? 'takeaway';

        totalRevenue += amount;
        if (type == 'dine_in' || type == 'sur place') {
          dineInRevenue += amount;
          dineInOrdersCount++;
        } else {
          takeawayRevenue += amount;
          takeawayOrdersCount++;
        }
      }

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Erreur chargement stats : $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Performances & Activité", style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStatistics,
            tooltip: "Actualiser",
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFilterChip("Tout", "all"),
                _buildFilterChip("Aujourd'hui", "today"),
                _buildFilterChip("7 Jours", "week"),
                _buildFilterChip("30 Jours", "month"),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryColor))
                : RefreshIndicator(
                    color: primaryColor,
                    onRefresh: _loadStatistics,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // SECTION CHIFFRE D'AFFAIRES GLOBAL (Basé sur l'argent payé)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, const Color(0xFF8D2B40)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Chiffre d'affaires encaissé", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Text("${totalRevenue.toStringAsFixed(2)} \$", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _HeaderStatBadge(label: "Commandes payées", value: "$totalOrders"),
                                  _HeaderStatBadge(label: "Réservations", value: "$totalReservations"),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Text("Répartition du CA encaissé", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),

                        // VENTILATION SUR PLACE VS A EMPORTER
                        Row(
                          children: [
                            Expanded(
                              child: _buildRevenueBreakdownCard(
                                title: "Sur place",
                                revenue: dineInRevenue,
                                count: dineInOrdersCount,
                                icon: Icons.restaurant_rounded,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildRevenueBreakdownCard(
                                title: "À emporter",
                                revenue: takeawayRevenue,
                                count: takeawayOrdersCount,
                                icon: Icons.takeout_dining_rounded,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Text("État des Réservations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(child: _buildStatusDetailCard("Acceptées", acceptedReservations, Colors.green.shade700, Colors.green.shade50)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatusDetailCard("En attente", pendingReservations, Colors.orange.shade800, Colors.orange.shade50)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatusDetailCard("Refusées", rejectedReservations, Colors.red.shade700, Colors.red.shade50)),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Text("Top 5 des heures les plus fréquentées", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),

                        // TOP 5 HEURES DE POINTE
                        peakHours.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                child: const Center(child: Text("Pas assez de données pour l'instant", style: TextStyle(color: Colors.grey))),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: peakHours.length > 5 ? 5 : peakHours.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                                  itemBuilder: (context, index) {
                                    final entry = peakHours.entries.elementAt(index);
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: index == 0 ? Colors.amber.shade100 : Colors.grey.shade100,
                                        child: Text("#${index + 1}", style: TextStyle(color: index == 0 ? Colors.amber.shade900 : Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      title: Text("Heure de pointe : ${entry.key}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                        child: Text("${entry.value} ${entry.value > 1 ? 'visites' : 'visite'}", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
      backgroundColor: Colors.grey.shade100,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            selectedFilter = value;
          });
          _loadStatistics();
        }
      },
    );
  }

  Widget _buildRevenueBreakdownCard({required String title, required double revenue, required int count, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          Text("${revenue.toStringAsFixed(2)} \$", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text("$count commande${count > 1 ? 's' : ''}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusDetailCard(String label, int count, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text("$count", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _HeaderStatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text("$label: ", style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}