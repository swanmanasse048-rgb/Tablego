import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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
      // Simulation simple du traitement réseau
      await Future.delayed(const Duration(seconds: 2));

      // Mise à jour instantanée du statut dans Supabase
      await supabase.from('orders').update({
        'payment_status': 'paid',
        'status': 'completed',
      }).eq('id', widget.orderId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Paiement validé ! Le restaurant a reçu l'argent."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            Text("Montant : \$${widget.amount}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Numéro de téléphone",
                hintText: "+243...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 5,
              decoration: const InputDecoration(
                labelText: "Code PIN",
                hintText: "*****",
                counterText: "",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
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
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Valider le paiement", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}