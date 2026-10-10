import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Lance le paiement Orange Money via l'Edge Function
  Future<Map<String, dynamic>> payWithOrangeMoney({
    required String orderId,
    required double amount,
    required String phoneNumber,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'initiate-payment',
        body: {
          'order_id': orderId,
          'amount': amount,
          'phone': phoneNumber,
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': true,
          'message': data['message'] ?? 'Paiement initié avec succès.',
        };
      } else {
        final errorData = response.data;
        return {
          'success': false,
          'message': errorData['error'] ?? 'Erreur lors du paiement.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion : $e',
      };
    }
  }
}