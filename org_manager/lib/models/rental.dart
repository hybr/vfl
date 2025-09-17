enum RentalStatus { pending, confirmed, active, returned, cancelled }

class RentalItem {
  final String productId;
  final int quantity;
  final double dailyRate;
  final int durationDays;
  final double totalPrice;

  RentalItem({
    required this.productId,
    required this.quantity,
    required this.dailyRate,
    required this.durationDays,
    required this.totalPrice,
  });

  factory RentalItem.fromJson(Map<String, dynamic> json) {
    return RentalItem(
      productId: json['productId'],
      quantity: json['quantity'],
      dailyRate: json['dailyRate'].toDouble(),
      durationDays: json['durationDays'],
      totalPrice: json['totalPrice'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'dailyRate': dailyRate,
      'durationDays': durationDays,
      'totalPrice': totalPrice,
    };
  }
}

class Rental {
  final String id;
  final String organizationId;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final List<RentalItem> items;
  final double totalAmount;
  final RentalStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? returnDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Rental({
    required this.id,
    required this.organizationId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.returnDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Rental.fromJson(Map<String, dynamic> json) {
    return Rental(
      id: json['id'],
      organizationId: json['organizationId'],
      customerId: json['customerId'],
      customerName: json['customerName'],
      customerEmail: json['customerEmail'],
      items: (json['items'] as List<dynamic>).map((itemJson) => RentalItem.fromJson(itemJson)).toList(),
      totalAmount: json['totalAmount'].toDouble(),
      status: RentalStatus.values.firstWhere((e) => e.toString() == 'RentalStatus.${json['status']}'),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      returnDate: json['returnDate'] != null ? DateTime.parse(json['returnDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'returnDate': returnDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Rental copyWith({
    String? id,
    String? organizationId,
    String? customerId,
    String? customerName,
    String? customerEmail,
    List<RentalItem>? items,
    double? totalAmount,
    RentalStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? returnDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rental(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      returnDate: returnDate ?? this.returnDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}