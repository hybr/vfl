enum SaleStatus { pending, confirmed, shipped, delivered, cancelled }

class SaleItem {
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  SaleItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productId: json['productId'],
      quantity: json['quantity'],
      unitPrice: json['unitPrice'].toDouble(),
      totalPrice: json['totalPrice'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}

class Sale {
  final String id;
  final String organizationId;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final List<SaleItem> items;
  final double totalAmount;
  final SaleStatus status;
  final DateTime saleDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Sale({
    required this.id,
    required this.organizationId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.saleDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'],
      organizationId: json['organizationId'],
      customerId: json['customerId'],
      customerName: json['customerName'],
      customerEmail: json['customerEmail'],
      items: (json['items'] as List<dynamic>).map((itemJson) => SaleItem.fromJson(itemJson)).toList(),
      totalAmount: json['totalAmount'].toDouble(),
      status: SaleStatus.values.firstWhere((e) => e.toString() == 'SaleStatus.${json['status']}'),
      saleDate: DateTime.parse(json['saleDate']),
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
      'saleDate': saleDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Sale copyWith({
    String? id,
    String? organizationId,
    String? customerId,
    String? customerName,
    String? customerEmail,
    List<SaleItem>? items,
    double? totalAmount,
    SaleStatus? status,
    DateTime? saleDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      saleDate: saleDate ?? this.saleDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}