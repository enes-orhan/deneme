class CreditEntry {
  final String id;
  final String name;
  final String surname;
  final double remainingDebt;
  final double lastPaymentAmount;
  final DateTime? lastPaymentDate;

  CreditEntry({
    required this.id,
    required this.name,
    required this.surname,
    required this.remainingDebt,
    required this.lastPaymentAmount,
    this.lastPaymentDate,
  });

  factory CreditEntry.fromMap(Map<String, dynamic> map) {
    return CreditEntry(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      surname: map['surname'] ?? '',
      remainingDebt: map['remainingDebt'] is num ? (map['remainingDebt'] as num).toDouble() : double.tryParse(map['remainingDebt'].toString().replaceAll('TL','').trim()) ?? 0.0,
      lastPaymentAmount: map['lastPaymentAmount'] is num ? (map['lastPaymentAmount'] as num).toDouble() : double.tryParse(map['lastPaymentAmount'].toString().replaceAll('TL','').trim()) ?? 0.0,
      lastPaymentDate: map['lastPaymentDate'] != null ? (map['lastPaymentDate'] is DateTime ? map['lastPaymentDate'] : DateTime.tryParse(map['lastPaymentDate'].toString())) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'remainingDebt': remainingDebt,
      'lastPaymentAmount': lastPaymentAmount,
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
    };
  }
} 