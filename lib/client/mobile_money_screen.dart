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
  bool _isLoading = false;

  void _processRealPayment() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer votre numéro de téléphone."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Appel d'une Supabase Edge Function sécurisée pour initier le paiement réel
      final response = await supabase.functions.invoke(
        'initiate-payment',
        body: {
          'order_id': widget.orderId,
          'amount': widget.amount,
          'phone': phone,
        },
      );

      if (response.status == 200) {
        if (mounted) {
          setState(() => _isLoading = false);
          
          // Affichage d'une instruction claire pour l'utilisateur
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Vérification en cours"),
              content: const Text(
                "Une demande de paiement a été envoyée sur votre téléphone. Veuillez valider avec votre code PIN.",
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D1B2B)),
                  onPressed: () {
                    Navigator.pop(context); // Ferme la boîte de dialogue
                    Navigator.pop(context); // Quitte l'écran de paiement
                  },
                  child: const Text("J'ai validé", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(response.data['error'] ?? "Erreur lors de l'initialisation du paiement.");
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
        title: const Text("Paiement Mobile Money Sécurisé"),
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
            const Text("Entrez votre numéro de téléphone (M-Pesa, Orange Money, Airtel) :"),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "+243 ...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.phone_iphone),
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
                onPressed: _isLoading ? null : _processRealPayment,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Lancer la demande de paiement", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}