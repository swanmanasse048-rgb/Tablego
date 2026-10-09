class Restaurant {
  final String id;
  final String name;
  final String image;
  final String category;
  final double rating;

  Restaurant({
    required this.id,
    required this.name,
    required this.image,
    required this.category,
    required this.rating,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'],
      name: map['name'],
      image: map['image_url'],
      category: map['category'],
      rating: (map['rating'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image_url': image,
      'category': category,
      'rating': rating,
    };
  }
}