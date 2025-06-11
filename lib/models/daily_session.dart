/// Model for daily session management
/// Used to track day start/end status and session data in SQLite
class DailySession {
  final String id;
  final String date;
  final bool sessionStarted;
  final DateTime? startTime;
  final DateTime? endTime;
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final int totalSales;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailySession({
    required this.id,
    required this.date,
    required this.sessionStarted,
    this.startTime,
    this.endTime,
    this.totalRevenue = 0.0,
    this.totalCost = 0.0,
    this.totalProfit = 0.0,
    this.totalSales = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from database map
  factory DailySession.fromMap(Map<String, dynamic> map) {
    return DailySession(
      id: map['id'] as String,
      date: map['date'] as String,
      sessionStarted: (map['session_started'] as int) == 1,
      startTime: map['start_time'] != null ? DateTime.parse(map['start_time'] as String) : null,
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      totalRevenue: (map['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (map['total_profit'] as num?)?.toDouble() ?? 0.0,
      totalSales: (map['total_sales'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'session_started': sessionStarted ? 1 : 0,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'total_revenue': totalRevenue,
      'total_cost': totalCost,
      'total_profit': totalProfit,
      'total_sales': totalSales,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create copy with updated values
  DailySession copyWith({
    String? id,
    String? date,
    bool? sessionStarted,
    DateTime? startTime,
    DateTime? endTime,
    double? totalRevenue,
    double? totalCost,
    double? totalProfit,
    int? totalSales,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailySession(
      id: id ?? this.id,
      date: date ?? this.date,
      sessionStarted: sessionStarted ?? this.sessionStarted,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalCost: totalCost ?? this.totalCost,
      totalProfit: totalProfit ?? this.totalProfit,
      totalSales: totalSales ?? this.totalSales,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DailySession(id: $id, date: $date, sessionStarted: $sessionStarted, startTime: $startTime, endTime: $endTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailySession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 