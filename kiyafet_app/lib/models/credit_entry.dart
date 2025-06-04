class CreditEntry {
  final String name;
  final String surname;
  final double remainingDebt;
  final double lastPaymentAmount;
  final DateTime lastPaymentDate;

  CreditEntry({
    required this.name,
    required this.surname,
    required this.remainingDebt,
    required this.lastPaymentAmount,
    required this.lastPaymentDate,
  });

  factory CreditEntry.fromMap(Map<String, dynamic> map) {
    return CreditEntry(
      name: map['name'] ?? '',
      surname: map['surname'] ?? '',
      remainingDebt: map['remainingDebt'] is num ? (map['remainingDebt'] as num).toDouble() : double.tryParse(map['remainingDebt'].toString().replaceAll('TL','').trim()) ?? 0.0,
      lastPaymentAmount: map['lastPaymentAmount'] is num ? (map['lastPaymentAmount'] as num).toDouble() : double.tryParse(map['lastPaymentAmount'].toString().replaceAll('TL','').trim()) ?? 0.0,
      lastPaymentDate: map['lastPaymentDate'] is DateTime ? map['lastPaymentDate'] : DateTime.tryParse(map['lastPaymentDate'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'surname': surname,
      'remainingDebt': remainingDebt,
      'lastPaymentAmount': lastPaymentAmount,
      'lastPaymentDate': lastPaymentDate.toIso8601String(),
    };
  }
} 