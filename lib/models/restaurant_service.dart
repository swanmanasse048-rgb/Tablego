import 'dart:convert';

class RestaurantService {
  final String id;
  final String label;
  final String icon;

  const RestaurantService({
    required this.id,
    required this.label,
    required this.icon,
  });

  // ---------------------------------------------------------------------------
  // Liste globale des services disponibles
  // ---------------------------------------------------------------------------
  static const List<RestaurantService> availableServices = [
    RestaurantService(id: 'wifi', label: 'Wi-Fi Gratuit', icon: '📶'),
    RestaurantService(id: 'parking', label: 'Parking Sécurisé', icon: '🅿️'),
    RestaurantService(id: 'ac', label: 'Climatisation', icon: '❄️'),
    RestaurantService(id: 'terrace', label: 'Terrasse / Jardin', icon: '🌳'),
    RestaurantService(id: 'vip_room', label: 'Salon VIP / Affaires', icon: '👔'),
    RestaurantService(id: 'live_music', label: 'Musique Live', icon: '🎶'),
    RestaurantService(id: 'mobile_money', label: 'M-Pesa / Mobile Money', icon: '📲'),
    RestaurantService(id: 'card_payment', label: 'Carte Bancaire', icon: '💳'),
  ];

  // ---------------------------------------------------------------------------
  // Méthodes Utilitaires & Sérialisation
  // ---------------------------------------------------------------------------

  /// Convertit une instance en Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'icon': icon,
    };
  }

  /// Reconstruit un objet depuis une Map (ex: réponse Supabase JSON)
  factory RestaurantService.fromMap(Map<String, dynamic> map) {
    return RestaurantService(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      icon: map['icon'] ?? '✨',
    );
  }

  String toJson() => json.encode(toMap());

  factory RestaurantService.fromJson(String source) =>
      RestaurantService.fromMap(json.decode(source));

  /// Retrouve une instance de [RestaurantService] par son ID.
  /// Renvoie un fallback personnalisé si l'ID n'est pas répertorié.
  static RestaurantService getById(String id) {
    final cleanId = id.trim().toLowerCase();
    return availableServices.firstWhere(
      (s) => s.id == cleanId,
      orElse: () => RestaurantService(
        id: cleanId,
        label: id,
        icon: '✨',
      ),
    );
  }

  /// Permet de filtrer la liste globale à partir d'une liste d'IDs (ex: depuis BDD).
  static List<RestaurantService> fromIds(List<String> ids) {
    return ids.map((id) => getById(id)).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RestaurantService && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$icon $label ($id)';
}