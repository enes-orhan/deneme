import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/product.dart';
import '../services/storage_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class DailySalesPage extends StatefulWidget {
  final StorageService storageService;

  const DailySalesPage({
    Key? key,
    required this.storageService,
  }) : super(key: key);

  @override
  State<DailySalesPage> createState() => _DailySalesPageState();
}

class _DailySalesPageState extends State<DailySalesPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _todaySales = [];
  List<Map<String, dynamic>> _salesHistory = [];
  List<Product> _products = [];
  bool _isLoading = true;
  final _barcodeController = TextEditingController();
  Product? _selectedProduct;
  final _quantityController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;
  List<Map<String, dynamic>> _dailySales = [];
  double _totalAmount = 0;
  double _totalCost = 0;
  double _totalProfit = 0;
  int _totalSales = 0;
  int _totalProducts = 0;
  DateTime? _openingTime;
  bool _dayStarted = false;
  DateTime? _dayStartTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkDayStarted();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkDayStarted() async {
    final prefs = await SharedPreferences.getInstance();
    final started = prefs.getBool('day_started') ?? false;
    final startTimeMillis = prefs.getInt('day_start_time');
    setState(() {
      _dayStarted = started;
      _dayStartTime = startTimeMillis != null ? DateTime.fromMillisecondsSinceEpoch(startTimeMillis) : null;
    });
    if (started) {
      await _loadData();
    }
  }

  Future<void> _startDay() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setBool('day_started', true);
    await prefs.setInt('day_start_time', now.millisecondsSinceEpoch);
    setState(() {
      _dayStarted = true;
      _dayStartTime = now;
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // compute yerine doğrudan çağır
      final data = await _loadDataInBackground(_selectedDate);
      
      if (mounted) {
        setState(() {
          _todaySales = data['sales'];
          _salesHistory = data['history'];
          _products = data['products'];
          _dailySales = data['dailySales'];
          _totalAmount = data['totalAmount'];
          _totalCost = data['totalCost'];
          _totalProfit = data['totalProfit'];
          _totalSales = data['totalSales'];
          _totalProducts = data['totalProducts'];
          _openingTime = data['openingTime'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Veri yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Veriler yüklenirken bir hata oluştu: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _loadDataInBackground(DateTime date) async {
    try {
      final storageService = widget.storageService;
      
      // Tüm verileri paralel olarak yükle
      final results = await Future.wait([
        storageService.getSales(),
        storageService.getSalesHistory(),
        storageService.getProducts(),
        storageService.getDailySales(date),
        storageService.getDailySummary(date),
        storageService.getTotalAmount(date),
        storageService.getTotalCost(date),
        storageService.getTotalProfit(date),
        storageService.getTotalSales(date),
        storageService.getTotalProducts(date),
        storageService.getOpeningTime(date),
      ]);

      // Sonuçları döndür
      return {
        'sales': results[0],
        'history': results[1],
        'products': results[2],
        'dailySales': results[3],
        'summary': results[4],
        'totalAmount': results[5],
        'totalCost': results[6],
        'totalProfit': results[7],
        'totalSales': results[8],
        'totalProducts': results[9],
        'openingTime': results[10] is int 
            ? DateTime.fromMillisecondsSinceEpoch(results[10] as int)
            : results[10] is String 
                ? DateTime.tryParse(results[10] as String) 
                : null,
      };
    } catch (e) {
      print('Arka plan veri yükleme hatası: $e');
      // Hata durumunda boş veri döndür
      return {
        'sales': [],
        'history': [],
        'products': [],
        'dailySales': [],
        'summary': null,
        'totalAmount': 0.0,
        'totalCost': 0.0,
        'totalProfit': 0.0,
        'totalSales': 0,
        'totalProducts': 0,
        'openingTime': null,
      };
    }
  }

  void _calculateDailySummary() {
    _totalSales = 0;
    _totalProducts = 0;
    _totalAmount = 0;
    _totalCost = 0;
    _totalProfit = 0;

    for (var sale in _dailySales) {
      if (sale['type'] == 'summary') continue;
      
      final quantity = sale['quantity'] is int 
          ? sale['quantity'] as int 
          : int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0;
      
      final price = sale['price'] is num 
          ? (sale['price'] as num).toDouble() 
          : double.tryParse(sale['price']?.toString() ?? '0') ?? 0.0;
      
      final finalCost = sale['finalCost'] is num 
          ? (sale['finalCost'] as num).toDouble() 
          : double.tryParse(sale['finalCost']?.toString() ?? '0') ?? 0.0;
      
      _totalSales++;
      _totalProducts += quantity;
      _totalAmount += price * quantity;
      _totalCost += finalCost * quantity;
    }
    
    _totalProfit = _totalAmount - _totalCost;
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    
    if (value is DateTime) return value;
    
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (e) {
        print('Timestamp dönüştürme hatası (int): $e');
        return DateTime.now();
      }
    }
    
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Timestamp dönüştürme hatası (String): $e');
        return DateTime.now();
      }
    }
    
    print('Bilinmeyen timestamp formatı: $value');
    return DateTime.now();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadData();
      
      // Eğer seçilen tarih bugün değilse ve günlük satışlar tabında değilsek, günlük satışlara dön
      final now = DateTime.now();
      final isToday = picked.year == now.year && picked.month == now.month && picked.day == now.day;
      if (!isToday && _tabController.index != 0) {
        _tabController.animateTo(0);
      }
    }
  }

  void _addSale() {
    if (_selectedProduct == null) {
      _showError('Lütfen bir ürün seçin');
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      _showError('Geçerli bir adet girin');
      return;
    }

    if (quantity > _selectedProduct!.quantity) {
      _showError('Yetersiz stok');
      return;
    }

    try {
      final now = DateTime.now();
      final sale = {
        'id': null, // ID'nin StorageService'de UUID olarak atanmasını sağla
        'productId': _selectedProduct!.id.toString(),
        'productName': _selectedProduct!.name?.toString() ?? '',
        'brand': _selectedProduct!.brand?.toString() ?? '',
        'model': _selectedProduct!.model?.toString() ?? '',
        'color': _selectedProduct!.color?.toString() ?? '',
        'size': _selectedProduct!.size?.toString() ?? '',
        'quantity': quantity.toString(),
        'price': (_selectedProduct!.finalCost ?? 0.0).toString(),
        'finalCost': (_selectedProduct!.finalCost ?? 0.0).toString(),
        'barcode': _selectedProduct!.barcode?.toString() ?? '',
        'unitCost': (_selectedProduct!.unitCost ?? 0.0).toString(),
        'vat': (_selectedProduct!.vat ?? 0.0).toString(),
        'expenseRatio': (_selectedProduct!.expenseRatio ?? 0.0).toString(),
        'averageProfitMargin': (_selectedProduct!.averageProfitMargin ?? 0.0).toString(),
        'recommendedPrice': (_selectedProduct!.recommendedPrice ?? 0.0).toString(),
        'purchasePrice': (_selectedProduct!.purchasePrice ?? 0.0).toString(),
        'category': _selectedProduct!.category?.toString() ?? '',
        'date': DateFormat('yyyy-MM-dd').format(now),
        'timestamp': now.toIso8601String(),
        'type': 'sale',
      };

      // Stok güncelleme
      final updatedProduct = _selectedProduct!.copyWith(
        quantity: _selectedProduct!.quantity - quantity,
      );

      // Veritabanını güncelle
      widget.storageService.updateProduct(updatedProduct).then((_) {
        // Satışı ekle
        widget.storageService.addSales([sale]).then((_) {
          setState(() {
            // Ürün listesini güncelle
            final index = _products.indexWhere((p) => p.id == _selectedProduct!.id);
            if (index != -1) {
              _products[index] = updatedProduct;
            }
            
            // Satışları ekle
            _salesHistory.add(sale);
            _dailySales.add(sale);
            
            // Formu sıfırla
            _quantityController.text = '1';
            _selectedProduct = null;
            _barcodeController.clear();
            
            // Günlük özeti güncelle
            _calculateDailySummary();
          });

          _showSuccess('Satış başarıyla kaydedildi');
        }).catchError((error) {
          print('Satış kaydedilirken hata oluştu: $error, veri: $sale');
          _showError('Satış kaydedilirken hata oluştu: $error');
        });
      }).catchError((error) {
        _showError('Stok güncellenirken hata oluştu: $error');
      });
    } catch (e) {
      _showError('Satış eklenirken bir hata oluştu: $e');
    }
  }

  void _showBarcodeScanner() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Barkod Tara', style: AppTextStyles.heading2),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            _barcodeController.text = barcode.rawValue!;
                            _onBarcodeChanged(barcode.rawValue!);
                            Navigator.pop(context);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.cancel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onBarcodeChanged(String barcode) {
    if (barcode.isEmpty) return;
    
    try {
      final product = _products.firstWhere(
        (p) => p.barcode == barcode,
        orElse: () => throw Exception('Ürün bulunamadı'),
      );
      
      setState(() {
        _selectedProduct = product;
        _quantityController.text = '1';
      });
    } catch (e) {
      _showError('Ürün bulunamadı: $e');
      setState(() {
        _selectedProduct = null;
        _quantityController.text = '1';
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _endDay() async {
    if (_dailySales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Günlük satış bulunamadı')),
      );
      return;
    }

    final totalSales = _dailySales.fold<double>(
      0,
      (sum, sale) => sum + (double.tryParse(sale['price']?.toString() ?? '0') ?? 0) * (int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0),
    );

    final totalCost = _dailySales.fold<double>(
      0,
      (sum, sale) => sum + (double.tryParse(sale['finalCost']?.toString() ?? '0') ?? 0) * (int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0),
    );

    final totalProducts = _dailySales.fold<int>(
      0,
      (sum, sale) => sum + (int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0),
    );

    final now = DateTime.now();
    final summary = {
      'id': null, // ID'nin StorageService'de UUID olarak atanmasını sağla
      'date': DateFormat('yyyy-MM-dd').format(now),
      'timestamp': now.toIso8601String(),
      'openingTime': _dayStartTime?.toIso8601String() ?? '',
      'closingTime': now.toIso8601String(),
      'totalSales': totalSales.toString(),
      'totalCost': totalCost.toString(),
      'totalProducts': totalProducts.toString(),
      'cashAmount': '0',
      'cardAmount': '0',
      'marketAmount': '0',
      'type': 'summary',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gün Sonu Özeti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Satış Sayısı: ${_dailySales.length}'),
            Text('Satılan Ürün Adedi: $totalProducts'),
            Text('Toplam Maliyet: ${totalCost.toStringAsFixed(2)} TL'),
            Text('Toplam Satış: ${totalSales.toStringAsFixed(2)} TL'),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Nakit',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0.0;
                summary['cashAmount'] = amount.toString();
              },
              semanticLabel: 'Nakit Alanı',
              autofillHints: const [AutofillHints.name],
            ),
            CustomTextField(
              label: 'Kart',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0.0;
                summary['cardAmount'] = amount.toString();
              },
              semanticLabel: 'Kart Alanı',
              autofillHints: const [AutofillHints.name],
            ),
            CustomTextField(
              label: 'Pazar',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0.0;
                summary['marketAmount'] = amount.toString();
              },
              semanticLabel: 'Pazar Alanı',
              autofillHints: const [AutofillHints.name],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          CustomButton(
            onPressed: () async {
              // Önce günlük satışları ekle
              if (_todaySales.isNotEmpty) {
                // Günlük satışları ana satışlar tablosuna ekle
                final salesToSave = _todaySales.map((sale) {
                  final newSaleMap = Map<String, dynamic>.from(sale);
                  newSaleMap['id'] = null; // StorageService'in yeni UUID atamasını garantile
                  newSaleMap['type'] = 'sale'; // Günü bitirirken 'sale' olarak işaretle
                  newSaleMap['date'] = DateFormat('yyyy-MM-dd').format(now);
                  newSaleMap['time'] ??= DateFormat('HH:mm:ss').format(now);
                  newSaleMap['timestamp'] ??= now.toIso8601String();
                  return newSaleMap;
                }).toList();

                await widget.storageService.addSales(salesToSave);
              }
              // Sonra özet bilgilerini ekle
              await widget.storageService.addSales([summary]);
              
              setState(() {
                _salesHistory.addAll(_dailySales);
                _salesHistory.add(summary);
                _dailySales.clear();
                _calculateDailySummary();
              });
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gün sonu başarıyla kaydedildi')),
              );

              // Satış geçmişine yönlendir
              _tabController.animateTo(1);
            },
            text: 'Tamamla',
            semanticLabel: 'Tamamla Butonu',
          ),
        ],
      ),
    );

    // Gün bitince flag'i sıfırla
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('day_started', false);
    await prefs.remove('day_start_time');
    setState(() {
      _dayStarted = false;
      _dayStartTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_dayStarted) {
      // Giriş ekranı: iki ana buton
      return Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.dailySales),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomButton(
                text: 'Yeni Gün Başlat',
                icon: Icons.play_arrow,
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
                onPressed: _startDay,
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Satış Geçmişi',
                icon: Icons.history,
                backgroundColor: AppColors.accent,
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _tabController.index = 1;
                  });
                  setState(() {
                    _dayStarted = true; // Sadece geçmişi göstermek için
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.dailySales),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
            tooltip: 'Tarih Seç',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Günlük Satışlar'),
            Tab(text: 'Satış Geçmişi'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Günlük Satışlar Tab
                _buildDailySalesTab(),
                // Satış Geçmişi Tab
                _buildSalesHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildDailySalesTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.padding),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate),
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: AppSizes.spacing),
            _buildSalesForm(),
            const SizedBox(height: AppSizes.spacing),
            SizedBox(
              height: 400,
              child: _buildSalesList(
                _dailySales,
                'Bugün için satış bulunmamaktadır',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            label: 'Barkod',
            controller: _barcodeController,
            onChanged: _onBarcodeChanged,
            validator: _barcodeValidator,
            suffixIcon: IconButton(
              icon: const Icon(AppIcons.barcode),
              onPressed: _showBarcodeScanner,
              tooltip: 'Barkod Tara',
            ),
            semanticLabel: 'Barkod Alanı',
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: AppSizes.spacing),
          DropdownButtonFormField<Product>(
            value: _selectedProduct,
            decoration: const InputDecoration(
              labelText: 'Ürün',
              border: OutlineInputBorder(),
            ),
            items: _products.map((product) {
              return DropdownMenuItem(
                value: product,
                child: Text(product.fullDetails),
              );
            }).toList(),
            onChanged: (product) {
              setState(() {
                _selectedProduct = product;
                if (product != null) {
                  _barcodeController.text = product.barcode ?? '';
                }
              });
            },
          ),
          const SizedBox(height: AppSizes.spacing),
          CustomTextField(
            label: 'Adet',
            controller: _quantityController,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen adet girin';
              }
              final quantity = int.tryParse(value);
              if (quantity == null || quantity <= 0) {
                return 'Geçerli bir adet girin';
              }
              if (_selectedProduct != null &&
                  quantity > _selectedProduct!.quantity) {
                return 'Yetersiz stok';
              }
              return null;
            },
            semanticLabel: 'Adet Alanı',
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: AppSizes.spacing),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: _addSale,
                  text: 'Satış Ekle',
                  icon: Icons.add,
                  backgroundColor: AppColors.primary,
                  textColor: Colors.white,
                  semanticLabel: 'Satış Ekle Butonu',
                ),
              ),
              const SizedBox(width: AppSizes.spacing),
              Expanded(
                child: CustomButton(
                  onPressed: _endDay,
                  text: 'Günü Bitir',
                  icon: Icons.check,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  semanticLabel: 'Günü Bitir Butonu',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHistoryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomButton(
                text: "Excel'e Aktar",
                icon: Icons.download,
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
                onPressed: _exportToExcel,
              ),
            ],
          ),
        ),
        Expanded(child: _buildSalesHistoryList()),
      ],
    );
  }

  Widget _buildSalesList(List<Map<String, dynamic>> sales, String emptyMessage) {
    if (sales.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: AppTextStyles.body,
        ),
      );
    }

    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        if (sale['type'] == 'summary') {
          try {
            final date = sale['date'] != null 
                ? DateTime.parse(sale['date'].toString()) 
                : DateTime.now();
            
            final totalSales = (sale['totalSales'] is num) 
                ? (sale['totalSales'] as num).toDouble() 
                : double.tryParse(sale['totalSales']?.toString() ?? '0') ?? 0.0;
            
            final totalCost = (sale['totalCost'] is num) 
                ? (sale['totalCost'] as num).toDouble() 
                : double.tryParse(sale['totalCost']?.toString() ?? '0') ?? 0.0;
            
            final totalProducts = (sale['totalProducts'] is int) 
                ? sale['totalProducts'] as int 
                : int.tryParse(sale['totalProducts']?.toString() ?? '0') ?? 0;
            
            final cashAmount = (sale['cashAmount'] is num) 
                ? (sale['cashAmount'] as num).toDouble() 
                : double.tryParse(sale['cashAmount']?.toString() ?? '0') ?? 0.0;
            
            final cardAmount = (sale['cardAmount'] is num) 
                ? (sale['cardAmount'] as num).toDouble() 
                : double.tryParse(sale['cardAmount']?.toString() ?? '0') ?? 0.0;
            
            final marketAmount = (sale['marketAmount'] is num) 
                ? (sale['marketAmount'] as num).toDouble() 
                : double.tryParse(sale['marketAmount']?.toString() ?? '0') ?? 0.0;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gün Sonu Özeti',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          DateFormat('dd.MM.yyyy').format(date),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Toplam Satış: ${totalSales.toStringAsFixed(2)} TL'),
                    Text('Toplam Maliyet: ${totalCost.toStringAsFixed(2)} TL'),
                    Text('Satılan Ürün Adedi: $totalProducts'),
                    const SizedBox(height: 8),
                    Text('Nakit: ${cashAmount.toStringAsFixed(2)} TL'),
                    Text('Kart: ${cardAmount.toStringAsFixed(2)} TL'),
                    Text('Pazar: ${marketAmount.toStringAsFixed(2)} TL'),
                  ],
                ),
              ),
            );
          } catch (e) {
            print('Özet kartı oluşturulurken hata: $e');
            return const SizedBox.shrink();
          }
        }

        try {
          final productName = sale['productName']?.toString() ?? '';
          final brand = sale['brand']?.toString() ?? '';
          final model = sale['model']?.toString() ?? '';
          final color = sale['color']?.toString() ?? '';
          final size = sale['size']?.toString() ?? '';
          final barcode = sale['barcode']?.toString() ?? '';
          
          final quantity = (sale['quantity'] is int) 
              ? sale['quantity'] as int 
              : int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0;
          
          final price = (sale['price'] is num) 
              ? (sale['price'] as num).toDouble() 
              : double.tryParse(sale['price']?.toString() ?? '0') ?? 0.0;
          
          final total = quantity * price;
          
          final time = sale['timestamp'] != null 
              ? DateFormat('HH:mm').format(DateTime.parse(sale['timestamp'].toString())) 
              : '';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(time, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Marka/Model: $brand / $model'),
                  Text('Renk/Beden: $color / $size'),
                  Text('Barkod: $barcode'),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Adet: ${quantity.toStringAsFixed(0)}'),
                      Text('Birim Fiyat: ${price.toStringAsFixed(2)} ₺'),
                      Text(
                        'Toplam: ${total.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        } catch (e) {
          print('Satış kartı oluşturulurken hata: $e');
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildSalesHistoryList() {
    if (_salesHistory.isEmpty) {
      return const Center(
        child: Text('Henüz satış kaydı bulunmamaktadır.'),
      );
    }

    final dailySales = <String, List<Map<String, dynamic>>>{};
    final dailySummaries = <String, Map<String, dynamic>>{};

    for (final sale in _salesHistory) {
      try {
        if (sale['type'] == 'summary') {
          final date = _parseDateStringOrMillis(sale['timestamp']);
          dailySummaries[date] = sale;
        } else {
          final date = _parseDateStringOrMillis(sale['timestamp']);
          dailySales.putIfAbsent(date, () => []).add(sale);
        }
      } catch (e) {
        print('Satış verisi işlenirken hata: $e');
        continue;
      }
    }

    final sortedDates = dailySales.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final sales = dailySales[date]!;
        final summary = dailySummaries[date];

        double totalAmount = 0;
        int totalProducts = 0;
        double totalCost = 0;
        double cashAmount = 0;
        double cardAmount = 0;
        double marketAmount = 0;
        double totalCollection = 0;

        if (summary != null) {
          try {
            totalAmount = (summary['totalAmount'] is num) 
                ? (summary['totalAmount'] as num).toDouble() 
                : double.tryParse(summary['totalAmount']?.toString() ?? '0') ?? 0.0;
            
            totalProducts = (summary['totalProducts'] is int) 
                ? summary['totalProducts'] as int 
                : int.tryParse(summary['totalProducts']?.toString() ?? '0') ?? 0;
            
            totalCost = (summary['totalCost'] is num) 
                ? (summary['totalCost'] as num).toDouble() 
                : double.tryParse(summary['totalCost']?.toString() ?? '0') ?? 0.0;
            
            cashAmount = (summary['cashAmount'] is num) 
                ? (summary['cashAmount'] as num).toDouble() 
                : double.tryParse(summary['cashAmount']?.toString() ?? '0') ?? 0.0;
            
            cardAmount = (summary['cardAmount'] is num) 
                ? (summary['cardAmount'] as num).toDouble() 
                : double.tryParse(summary['cardAmount']?.toString() ?? '0') ?? 0.0;
            
            marketAmount = (summary['marketAmount'] is num) 
                ? (summary['marketAmount'] as num).toDouble() 
                : double.tryParse(summary['marketAmount']?.toString() ?? '0') ?? 0.0;

            totalCollection = cashAmount + cardAmount + marketAmount;
          } catch (e) {
            print('Özet verisi işlenirken hata: $e');
          }
        } else {
          for (final sale in sales) {
            try {
              final q = (sale['quantity'] is int) 
                  ? sale['quantity'] as int 
                  : int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0;
              
              final c = (sale['finalCost'] is num) 
                  ? (sale['finalCost'] as num).toDouble() 
                  : (sale['price'] is num) 
                      ? (sale['price'] as num).toDouble() 
                      : double.tryParse(sale['finalCost']?.toString() ?? '0') ?? 0.0;
              
              totalAmount += q * c;
              totalProducts += q;
              totalCost += q * c;
            } catch (e) {
              print('Satış verisi işlenirken hata: $e');
              continue;
            }
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            title: Text(
              DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.parse(date)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('$totalProducts ürün'),
                    const SizedBox(width: 16),
                    Icon(Icons.currency_lira, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${totalAmount.toStringAsFixed(2)} TL'),
                  ],
                ),
              ],
            ),
            children: [
              if (summary != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Günlük Özet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Açılış Saati: ' + (summary['openingTime'] ?? '')),
                      Text('Kapanış Saati: ' + (summary['closingTime'] ?? '')),
                      _buildSummaryRow('Nakit Tahsilat', cashAmount),
                      _buildSummaryRow('Kart Tahsilatı', cardAmount),
                      _buildSummaryRow('Pazar Tahsilatı', marketAmount),
                      const Divider(),
                      _buildSummaryRow('Toplam Tahsilat', totalCollection, isTotal: true),
                      _buildSummaryRow('Toplam Maliyet', totalCost),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Durum',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.currency_lira, size: 20, color: Colors.grey[800]),
                              const SizedBox(width: 4),
                              Text(
                                '${(totalCollection - totalCost).toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              SingleChildScrollView(
                child: Column(
                  children: sales.map((sale) {
                    try {
                      final quantity = (sale['quantity'] is int) 
                          ? sale['quantity'] as int 
                          : int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0;
                      
                      final finalCost = (sale['finalCost'] is num) 
                          ? (sale['finalCost'] as num).toDouble() 
                          : (sale['price'] is num) 
                              ? (sale['price'] as num).toDouble() 
                              : double.tryParse(sale['finalCost']?.toString() ?? '0') ?? 0.0;
                      
                      final totalPrice = quantity * finalCost;
                      final barcode = sale['barcode']?.toString() ?? '';
                      final productName = sale['productName']?.toString() ?? '';
                      final brand = sale['brand']?.toString() ?? '';
                      final model = sale['model']?.toString() ?? '';
                      final color = sale['color']?.toString() ?? '';
                      final size = sale['size']?.toString() ?? '';
                      final time = sale['timestamp'] != null 
                          ? DateFormat('HH:mm').format(DateTime.parse(sale['timestamp'].toString())) 
                          : '';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: ListTile(
                            title: Text('$productName ($brand/$model)'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Renk/Beden: $color/$size'),
                                Text('Barkod: $barcode'),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${totalPrice.toStringAsFixed(2)} TL',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('$quantity adet'),
                                Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      print('Satış kartı oluşturulurken hata: $e');
                      return const SizedBox.shrink();
                    }
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, bool isProfit = false, String extra = ''}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Row(
            children: [
              Text(
                '${amount.toStringAsFixed(2)} TL',
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 16 : 14,
                  color: isProfit ? (amount >= 0 ? Colors.green : Colors.red) : null,
                ),
              ),
              if (extra.isNotEmpty) ...[
                SizedBox(width: 6),
                Text(extra, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ]
            ],
          ),
        ],
      ),
    );
  }

  String _parseDateStringOrMillis(dynamic value) {
    if (value == null) return DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (value is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(value);
      return DateFormat('yyyy-MM-dd').format(dt);
    }
    if (value is String) {
      try {
        final dt = DateTime.parse(value);
        return DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {
        return value.split('T')[0];
      }
    }
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  String? _barcodeValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Barkod gerekli';
    }
    return null;
  }

  Future<void> _exportToExcel() async {
    try {
      // Sadece seçili ayın satışlarını ve özetlerini dışa aktar
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      final filtered = _salesHistory.where((sale) {
        final dateStr = sale['date'] ?? '';
        if (dateStr.isEmpty) return false;
        final date = DateTime.tryParse(dateStr);
        return date != null && date.month == month && date.year == year;
      }).toList();

      List<List<dynamic>> rows = [];
      rows.add([
        'Tarih', 'Ürün', 'Adet', 'Birim Fiyat', 'Toplam', 'Maliyet', 'Nakit', 'Kart', 'Pazar', 'Açılış', 'Kapanış', 'Tip'
      ]);
      for (final sale in filtered) {
        if (sale['type'] == 'summary') {
          rows.add([
            sale['date'] ?? '',
            '', '', '', '',
            sale['totalCost'] ?? '',
            sale['cashAmount'] ?? '',
            sale['cardAmount'] ?? '',
            sale['marketAmount'] ?? '',
            sale['openingTime'] ?? '',
            sale['closingTime'] ?? '',
            'Özet',
          ]);
        } else {
          final quantity = int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0;
          final price = double.tryParse(sale['price']?.toString() ?? '0') ?? 0.0;
          final total = quantity * price;
          rows.add([
            sale['date'] ?? '',
            sale['productName'] ?? '',
            quantity,
            price,
            total,
            sale['finalCost'] ?? '',
            '', '', '', '', '',
            'Satış',
          ]);
        }
      }
      String csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/yorukler_giyim_${year}_${month}.csv');
      await file.writeAsString(csv);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel dosyası kaydedildi: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dışa aktarma hatası: $e')),
      );
    }
  }
}

class Sale {
  final String productName;
  final int quantity;
  final double price;
  final DateTime timestamp;
  final String barcode;

  Sale({
    required this.productName,
    required this.quantity,
    required this.price,
    required this.timestamp,
    required this.barcode,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      productName: (map['productName'] ?? '') as String,
      quantity: map['quantity'] is int
          ? map['quantity'] as int
          : int.tryParse(map['quantity']?.toString() ?? '') ?? 0,
      price: map['price'] is double
          ? map['price'] as double
          : map['price'] is int
              ? (map['price'] as int).toDouble()
              : double.tryParse(map['price']?.toString() ?? '') ?? 0.0,
      timestamp: map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      barcode: (map['barcode'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'barcode': barcode,
    };
  }
}