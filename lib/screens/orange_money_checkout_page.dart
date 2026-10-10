import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class OrangeMoneyCheckoutPage extends StatefulWidget {
  final String orderId;
  final double amount;

  const OrangeMoneyCheckoutPage({
    Key? key,
    required this.orderId,
    required this.amount,
  }) : super(key: key);

  @override
  _OrangeMoneyCheckoutPageState createState() => _OrangeMoneyCheckoutPageState();
}

class _OrangeMoneyCheckoutPageState extends State<OrangeMoneyCheckoutPage> {
  final TextEditingController _phoneController = TextEditingController();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;

  void _handlePayment() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un numéro Orange Money validé (ex: 0891234567)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _paymentService.payWithOrangeMoney(
      orderId: widget.orderId,
      amount: widget.amount,
      phoneNumber: phone,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Validation requise'),
          content: Text(result['message']),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // Retour au menu principal
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement Orange Money'),
        backgroundColor: Colors.orange[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                children: [
                  const Text('Montant à payer', style: TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text('\$${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro Orange Money',
                hintText: '089XXXXXXX ou 084XXXXXXX',
                prefixIcon: Icon(Icons.phone, color: Colors.orange),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Payer avec Orange Money', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}