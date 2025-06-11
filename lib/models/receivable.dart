import 'dart:convert';

class Receivable {
  final String id;
  final String customerName;
  final double amount;
  final DateTime date;
  final String? description;
  final bool isPaid;

  Receivable({
    required this.id,
    required this.customerName,
    required this.amount,
    required this.date,
    this.description,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'isPaid': isPaid,
    };
  }

  factory Receivable.fromMap(Map<String, dynamic> map) {
    return Receivable(
      id: map['id'] as String,
      customerName: map['customerName'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String?,
      isPaid: map['isPaid'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory Receivable.fromJson(String source) => Receivable.fromMap(json.decode(source));
} 