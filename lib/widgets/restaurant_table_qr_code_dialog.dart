import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RestaurantTableQrCodeDialog extends StatelessWidget {
  final String restaurantSlug;
  final String restaurantName;
  final String? tableId;      // Rendu optionnel avec ?
  final int? tableNumber;     // Rendu optionnel avec ?

  const RestaurantTableQrCodeDialog({
    super.key,
    required this.restaurantSlug,
    required this.restaurantName,
    this.tableId,
    this.tableNumber,
  });

  @override
  Widget build(BuildContext context) {
    // Encodage propre du slug pour éviter les erreurs d'espaces ou de caractères
    final String cleanSlug = Uri.encodeComponent(restaurantSlug);

    // Si une table est spécifiée, on l'ajoute à l'URL. Sinon, URL générale du restaurant.
    final String tableBookingUrl = (tableId != null && tableNumber != null)
        ? "https://savora-web-two.vercel.app/restaurants/$cleanSlug?tableId=$tableId&tableNumber=$tableNumber"
        : "https://savora-web-two.vercel.app/restaurants/$cleanSlug";

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Text(
            restaurantName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if (tableNumber != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Table N° $tableNumber",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tableNumber != null
                ? "Scannez pour commander & réserver à cette table :"
                : "Scannez pour accéder au menu & réserver :",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: QrImageView(
              data: tableBookingUrl,
              version: QrVersions.auto,
              size: 200.0,
              gapless: false,
            ),
          ),
          const SizedBox(height: 15),
          SelectableText(
            tableBookingUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Fermer"),
        ),
      ],
    );
  }
}