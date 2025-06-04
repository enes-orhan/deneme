class Sale {
  final String id;
  final DateTime date;
  final double totalAmount;
  final double totalCost;
  final List<SaleItem> items;

  Sale({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.totalCost,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'totalAmount': totalAmount,
      'totalCost': totalCost,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      date: DateTime.parse(map['date']),
      totalAmount: map['totalAmount'],
      totalCost: map['totalCost'],
      items: (map['items'] as List).map((item) => SaleItem.fromMap(item)).toList(),
    );
  }
}

class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double cost;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.cost,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'cost': cost,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'],
      productName: map['productName'],
      quantity: map['quantity'],
      price: map['price'],
      cost: map['cost'],
    );
  }
} 