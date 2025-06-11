import 'dart:math';
import 'package:uuid/uuid.dart';

class Product {
  final String id;
  final String name;
  final String brand;
  final String model;
  final String color;
  final String size;
  final int quantity;
  final String region;
  String? barcode;
  final double unitCost;
  final double vat;
  final double expenseRatio;
  final double finalCost;
  final double averageProfitMargin;
  final double recommendedPrice;
  final double purchasePrice;
  final double sellingPrice;
  final String category;

  // SQLite sorgularında kullanılacak sütun isimleri
  static final List<String> columns = [
    'id', 'name', 'brand', 'model', 'color', 'size', 'quantity', 
    'region', 'barcode', 'unitCost', 'vat', 'expenseRatio', 'finalCost', 
    'averageProfitMargin', 'recommendedPrice', 'purchasePrice', 
    'sellingPrice', 'category'
  ];

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.color,
    required this.size,
    required this.quantity,
    required this.region,
    this.barcode,
    this.unitCost = 0.0,
    this.vat = 0.0,
    this.expenseRatio = 0.0,
    this.finalCost = 0.0,
    this.averageProfitMargin = 0.0,
    this.recommendedPrice = 0.0,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.category,
  });

  static String _generateBarcode() {
    // 8 haneli benzersiz barkod oluştur
    final random = Random();
    final barcode = StringBuffer();
    
    // İlk 2 hane: Marka kodu (01-99)
    barcode.write((random.nextInt(99) + 1).toString().padLeft(2, '0'));
    
    // Sonraki 2 hane: Ürün kategorisi (01-99)
    barcode.write((random.nextInt(99) + 1).toString().padLeft(2, '0'));
    
    // Sonraki 3 hane: Sıra numarası (001-999)
    barcode.write((random.nextInt(999) + 1).toString().padLeft(3, '0'));
    
    // Son hane: Kontrol hanesi (Luhn algoritması)
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      int digit = int.parse(barcode.toString()[i]);
      if (i % 2 == 0) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit ~/ 10) + (digit % 10);
        }
      }
      sum += digit;
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    barcode.write(checkDigit.toString());
    
    return barcode.toString();
  }

  // Fabrika metodu, Map'ten Product oluşturur
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String? ?? const Uuid().v4(),
      name: map['name'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      color: map['color'] as String? ?? '',
      size: map['size'] as String? ?? '',
      quantity: map['quantity'] is int ? map['quantity'] as int : int.tryParse(map['quantity'].toString()) ?? 0,
      region: map['region'] as String? ?? '',
      barcode: map['barcode'] as String?,
      unitCost: _parseDouble(map['unitCost']),
      vat: _parseDouble(map['vat']),
      expenseRatio: _parseDouble(map['expenseRatio']),
      finalCost: _parseDouble(map['finalCost']),
      averageProfitMargin: _parseDouble(map['averageProfitMargin']),
      recommendedPrice: _parseDouble(map['recommendedPrice']),
      purchasePrice: _parseDouble(map['purchasePrice']),
      sellingPrice: _parseDouble(map['sellingPrice']),
      category: map['category'] as String? ?? '',
    );
  }

  // Yardımcı metot, sayısal değerleri güvenli şekilde dönüştürür
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // Bu ürünün kopyasını oluşturur, belirtilen alanlarla günceller
  Product copyWith({
    String? id,
    String? name,
    String? brand,
    String? model,
    String? color,
    String? size,
    int? quantity,
    String? region,
    String? barcode,
    double? unitCost,
    double? vat,
    double? expenseRatio,
    double? finalCost,
    double? averageProfitMargin,
    double? recommendedPrice,
    double? purchasePrice,
    double? sellingPrice,
    String? category,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color ?? this.color,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      region: region ?? this.region,
      barcode: barcode ?? this.barcode,
      unitCost: unitCost ?? this.unitCost,
      vat: vat ?? this.vat,
      expenseRatio: expenseRatio ?? this.expenseRatio,
      finalCost: finalCost ?? this.finalCost,
      averageProfitMargin: averageProfitMargin ?? this.averageProfitMargin,
      recommendedPrice: recommendedPrice ?? this.recommendedPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      category: category ?? this.category,
    );
  }

  // Ürünü Map'e dönüştürür
  Map<String, dynamic> toMap() {
    // Sadece veritabanında var olan alanları ekle
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'model': model,
      'color': color,
      'size': size,
      'quantity': quantity,
      'region': region,
      'barcode': barcode,
      'unitCost': unitCost,
      'vat': vat,
      'expenseRatio': expenseRatio,
      'finalCost': finalCost,
      'averageProfitMargin': averageProfitMargin,
      'recommendedPrice': recommendedPrice,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'category': category,
    };
  }

  // Ürün özelliklerini güzel bir şekilde göster
  String get fullDetails => '$name $brand $model $color $size';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  bool isValid() {
    return name.isNotEmpty &&
        brand.isNotEmpty &&
        model.isNotEmpty &&
        color.isNotEmpty &&
        size.isNotEmpty &&
        quantity >= 0 &&
        region.isNotEmpty &&
        barcode?.isNotEmpty == true;
  }

  String get displayName => '$name - $brand - $model';
} 