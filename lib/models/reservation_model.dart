class Reservation {
  final String id;
  final String userId;
  final String restaurantId;
  final DateTime reservationDate;
  final String reservationTime;
  final int guests;
  final String status;
  final String? specialRequest;

  Reservation({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.reservationDate,
    required this.reservationTime,
    required this.guests,
    required this.status,
    this.specialRequest,
  });

  factory Reservation.fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: map['id'],
      userId: map['user_id'],
      restaurantId: map['restaurant_id'],
      reservationDate: DateTime.parse(map['reservation_date']),
      reservationTime: map['reservation_time'],
      guests: map['guests'],
      status: map['status'],
      specialRequest: map['special_request'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'restaurant_id': restaurantId,
      'reservation_date': reservationDate.toIso8601String(),
      'reservation_time': reservationTime,
      'guests': guests,
      'status': status,
      'special_request': specialRequest,
    };
  }
}