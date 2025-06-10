import 'package:uuid/uuid.dart';

class CreditEntry {
  final String id;
  final String name;
  final String surname;
  final double remainingDebt;
  final double lastPaymentAmount;
  final DateTime lastPaymentDate;

  CreditEntry({
    String? id, // Added id parameter
    required this.name,
    required this.surname,
    required this.remainingDebt,
    required this.lastPaymentAmount,
    required this.lastPaymentDate,
  }) : id = id ?? Uuid().v4(); // Initialize id

  factory CreditEntry.fromMap(Map<String, dynamic> map) {
    return CreditEntry(
      id: map['id'] as String? ?? Uuid().v4(), // Read id, generate if missing
      name: map['name'] ?? '',
      surname: map['surname'] ?? '',
      remainingDebt: map['remainingDebt'] is num ? (map['remainingDebt'] as num).toDouble() : double.tryParse(map['remainingDebt'].toString().replaceAll('TL','').trim()) ?? 0.0,
      lastPaymentAmount: map['lastPaymentAmount'] is num ? (map['lastPaymentAmount'] as num).toDouble() : double.tryParse(map['lastPaymentAmount'].toString().replaceAll('TL','').trim()) ?? 0.0,
      lastPaymentDate: map['lastPaymentDate'] is DateTime
          ? map['lastPaymentDate']
          : (map['lastPaymentDate'] is String
              ? DateTime.tryParse(map['lastPaymentDate'])
              : null) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Added id
      'name': name,
      'surname': surname,
      'remainingDebt': remainingDebt,
      'lastPaymentAmount': lastPaymentAmount,
      'lastPaymentDate': lastPaymentDate.toIso8601String(),
    };
  }
} 