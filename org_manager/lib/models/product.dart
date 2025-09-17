enum ProductType { goods, service }

class Product {
  final String id;
  final String name;
  final String description;
  final ProductType type;
  final double price;
  final String? imageUrl;
  final String organizationId;
  final bool isAvailableForSale;
  final bool isAvailableForRent;
  final double? rentPricePerDay;
  final int quantityAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.price,
    this.imageUrl,
    required this.organizationId,
    required this.isAvailableForSale,
    required this.isAvailableForRent,
    this.rentPricePerDay,
    required this.quantityAvailable,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: ProductType.values.firstWhere((e) => e.toString() == 'ProductType.${json['type']}'),
      price: json['price'].toDouble(),
      imageUrl: json['imageUrl'],
      organizationId: json['organizationId'],
      isAvailableForSale: json['isAvailableForSale'],
      isAvailableForRent: json['isAvailableForRent'],
      rentPricePerDay: json['rentPricePerDay']?.toDouble(),
      quantityAvailable: json['quantityAvailable'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'price': price,
      'imageUrl': imageUrl,
      'organizationId': organizationId,
      'isAvailableForSale': isAvailableForSale,
      'isAvailableForRent': isAvailableForRent,
      'rentPricePerDay': rentPricePerDay,
      'quantityAvailable': quantityAvailable,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    ProductType? type,
    double? price,
    String? imageUrl,
    String? organizationId,
    bool? isAvailableForSale,
    bool? isAvailableForRent,
    double? rentPricePerDay,
    int? quantityAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      organizationId: organizationId ?? this.organizationId,
      isAvailableForSale: isAvailableForSale ?? this.isAvailableForSale,
      isAvailableForRent: isAvailableForRent ?? this.isAvailableForRent,
      rentPricePerDay: rentPricePerDay ?? this.rentPricePerDay,
      quantityAvailable: quantityAvailable ?? this.quantityAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}