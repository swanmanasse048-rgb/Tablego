import 'package:supabase_flutter/supabase_flutter.dart';

class SavoraService {
  final _supabase = Supabase.instance.client;

  // 1. Récupérer toutes les tables d'un restaurant en Temps Réel
  Stream<List<Map<String, dynamic>>> getTablesStream(String restaurantId) {
    return _supabase
        .from('tables')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .order('table_number', ascending: true);
  }

  // 2. Réserver avec attribution intelligente (Appel de la fonction SQL)
  Future<String?> createReservationWithSmartAllocation({
    required String restaurantId,
    required String? preferredTableId,
    required String clientName,
    required String clientPhone,
    required int partySize,
    required DateTime reservationTime,
  }) async {
    // Appel de la fonction PostgreSQL allocate_best_table
    final allocatedTableId = await _supabase.rpc(
      'allocate_best_table',
      params: {
        'p_restaurant_id': restaurantId,
        'p_preferred_table_id': preferredTableId,
        'p_party_size': partySize,
        'p_reservation_time': reservationTime.toIso8601String(),
      },
    );

    if (allocatedTableId == null) {
      throw Exception("Aucune table disponible pour ce créneau et ce nombre de personnes.");
    }

    // Création de la réservation avec la table attribuée
    await _supabase.from('reservations').insert({
      'restaurant_id': restaurantId,
      'table_id': allocatedTableId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'party_size': partySize,
      'reservation_time': reservationTime.toIso8601String(),
      'status': 'confirmee',
    });

    return allocatedTableId;
  }

  // 3. Passer une commande à table (Order & Pay)
  Future<void> placeOrderAtTable({
    required String restaurantId,
    required String tableId,
    required double totalAmount,
    required String paymentMethod, // 'mobile_money' ou 'especes'
    required List<Map<String, dynamic>> items,
  }) async {
    // A. Créer la commande
    final orderResponse = await _supabase.from('orders').insert({
      'restaurant_id': restaurantId,
      'table_id': tableId,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'order_status': 'en_attente',
      'payment_status': paymentMethod == 'mobile_money' ? 'en_attente' : 'en_attente',
    }).select().single();

    final String orderId = orderResponse['id'];

    // B. Insérer les articles de la commande
    final orderItems = items.map((item) => {
      'order_id': orderId,
      'menu_item_id': item['menu_item_id'],
      'quantity': item['quantity'],
      'unit_price': item['unit_price'],
      'notes': item['notes'],
    }).toList();

    await _supabase.from('order_items').insert(orderItems);

    // C. Passer le statut de la table à 'occupee'
    await _supabase
        .from('tables')
        .update({'status': 'occupee'})
        .eq('id', tableId);
  }
}
  void listenToNewOrders(String restaurantId) {
  Supabase.instance.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('restaurant_id', restaurantId)
      .listen((List<Map<String, dynamic>> orders) {
        // Déclencher une notification sonore si une nouvelle commande 'en_attente' arrive
        final newOrders = orders.where((o) => o['order_status'] == 'en_attente').toList();
        if (newOrders.isNotEmpty) {
          // Ex: playNotificationSound();
        }
      });
}