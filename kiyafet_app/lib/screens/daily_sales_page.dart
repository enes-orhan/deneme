import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/product.dart';
import '../models/sale.dart' as AppSaleModel; // Renamed to avoid conflict with local
import '../services/sales_service.dart'; // Added
import '../services/accounting_service.dart'; // Added
import '../services/product_service.dart'; // Added
import '../services/service_locator.dart'; // Added
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class DailySalesPage extends StatefulWidget {
  // final StorageService storageService; // Removed

  const DailySalesPage({
    Key? key,
    // required this.storageService, // Removed
  }) : super(key: key);

  @override
  State<DailySalesPage> createState() => _DailySalesPageState();
}

class _DailySalesPageState extends State<DailySalesPage> with SingleTickerProviderStateMixin {
  late SalesService _salesService; // Added
  late AccountingService _accountingService; // Added
  late ProductService _productService; // Added

  List<AppSaleModel.Sale> _todaySales = []; // Changed to use AppSaleModel.Sale
  List<AppSaleModel.Sale> _salesHistory = []; // Changed to use AppSaleModel.Sale
  List<Product> _products = [];
  bool _isLoading = true;
  final _barcodeController = TextEditingController();
  Product? _selectedProduct;
  final _quantityController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;
  List<AppSaleModel.Sale> _dailySalesData = []; // Renamed from _dailySales to avoid conflict, stores AppSaleModel.Sale
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
    _salesService = getIt<SalesService>(); // Added
    _accountingService = getIt<AccountingService>(); // Added
    _productService = getIt<ProductService>(); // Added
    _tabController = TabController(length: 2, vsync: this);
    _checkDayStarted(); // This uses SharedPreferences, will address later if it should use a service
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // _checkDayStarted and _startDay still use SharedPreferences directly.
  // This could be moved to AccountingService if a concept of "business day session" is added there.
  // For now, leaving as is, as the primary goal is StorageService replacement.
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
    // Potentially: await _accountingService.startNewBusinessDay(now);
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
          _todaySales = data['sales']; // Expects List<AppSaleModel.Sale>
          _salesHistory = data['history']; // Expects List<AppSaleModel.Sale>
          _products = data['products']; // Expects List<Product>
          _dailySalesData = data['dailySales']; // Expects List<AppSaleModel.Sale>
          _totalAmount = data['totalAmount']; // Expects double
          _totalCost = data['totalCost']; // Expects double
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
      // final storageService = widget.storageService; // Removed
      
      final results = await Future.wait([
        _salesService.getSales().then((salesMaps) => salesMaps.map((map) => AppSaleModel.Sale.fromMap(map)).toList()), // Convert Map to Sale object
        _accountingService.getSalesHistory(), // Returns List<AppSaleModel.Sale>
        _productService.getProducts(), // Returns List<Product>
        _accountingService.getDailySales(date), // Returns List<AppSaleModel.Sale>
        _accountingService.getDailySummary(date), // Returns Future<Map<String, double>>
        _accountingService.getTotalAmount(), // Note: getTotalAmount in AccService might not be date specific. Adjust if needed.
        _accountingService.getTotalCost(),   // Note: getTotalCost in AccService might not be date specific. Adjust if needed.
        _accountingService.getTotalProfit(), // Note: getTotalProfit in AccService might not be date specific. Adjust if needed.
        _accountingService.getTotalSales(),  // Note: getTotalSales in AccService might not be date specific. Adjust if needed.
        _accountingService.getTotalProducts(),// Note: getTotalProducts in AccService might not be date specific. Adjust if needed.
        _accountingService.getOpeningTime(), // Note: getOpeningTime in AccService might not be date specific. Adjust if needed.
      ]);

      return {
        'sales': results[0] as List<AppSaleModel.Sale>, // _todaySales (all sales for current session)
        'history': results[1] as List<AppSaleModel.Sale>, // _salesHistory
        'products': results[2] as List<Product>, // _products
        'dailySales': results[3] as List<AppSaleModel.Sale>, // _dailySalesData (sales for the selected date)
        'summary': results[4] as Map<String, double>?, // summary for selected date
        'totalAmount': results[5] as double,
        'totalCost': results[6] as double,
        'totalProfit': results[7] as double,
        'totalSales': results[8] as int, // This is count of sales
        'totalProducts': results[9] as int, // This is sum of quantities of products sold
        'openingTime': results[10] as DateTime?,
      };
    } catch (e) {
      print('Arka plan veri yükleme hatası: $e');
      return {
        'sales': <AppSaleModel.Sale>[],
        'history': <AppSaleModel.Sale>[],
        'products': <Product>[],
        'dailySales': <AppSaleModel.Sale>[],
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
    _totalSales = 0;    // Number of sale transactions
    _totalProducts = 0; // Total quantity of items sold
    _totalAmount = 0;   // Total revenue from sales
    _totalCost = 0;     // Total cost of goods sold
    _totalProfit = 0;

    for (var sale in _dailySalesData) { // Use _dailySalesData which is List<AppSaleModel.Sale>
      _totalSales++;
      for (var item in sale.items) {
        _totalProducts += item.quantity;
        _totalAmount += item.price * item.quantity; // Assuming item.price is selling price
        _totalCost += item.cost * item.quantity;   // Assuming item.cost is cost price
      }
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

      // Create SaleItem
      final saleItem = AppSaleModel.SaleItem(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        quantity: quantity,
        price: _selectedProduct!.sellingPrice, // Assuming sellingPrice is the sale price
        cost: _selectedProduct!.finalCost,    // Assuming finalCost is the cost price
      );

      // Create Sale object
      final appSale = AppSaleModel.Sale(
        id: getIt<Uuid>().v4(), // Generate new ID
        date: now,
        totalAmount: saleItem.price * saleItem.quantity,
        totalCost: saleItem.cost * saleItem.quantity,
        items: [saleItem],
      );

      // Stok güncelleme
      final updatedProduct = _selectedProduct!.copyWith(
        quantity: _selectedProduct!.quantity - quantity,
      );

      // Veritabanını güncelle
      _productService.updateProduct(updatedProduct).then((_) {
        // Satışı ekle (SalesService expects Map<String, dynamic> for addSale)
        // So, convert AppSaleModel.Sale to Map.
        // However, SalesService.addSales (plural) takes List<Map<String, dynamic>>
        // Let's assume SalesService.addSale is what we want for a single sale.
        // If SalesService.addSale expects a Map, we convert appSale.toMap().
        // For now, let's assume _salesService.addSale takes the Map version.
        // A better SalesService would take AppSaleModel.Sale object.
        _salesService.addSale(appSale.toMap()).then((_) {
          setState(() {
            final index = _products.indexWhere((p) => p.id == _selectedProduct!.id);
            if (index != -1) {
              _products[index] = updatedProduct;
            }
            
            _salesHistory.add(appSale);
            if (DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(now)) {
              _dailySalesData.add(appSale);
            }
            
            _selectedProduct = null;
            _barcodeController.clear();
            
            _calculateDailySummary(); // Recalculate based on _dailySalesData
          });

          _showSuccess('Satış başarıyla kaydedildi');
        }).catchError((error) {
          // If addSale expects a Map, appSale.toMap() should be used.
          // The error "type 'Sale' is not a subtype of type 'Map<String, dynamic>'" would indicate this.
          print('Satış kaydedilirken hata oluştu: $error, veri: ${appSale.toMap()}');
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
    if (_dailySalesData.isEmpty) {
      _showError('Bugüne ait satış bulunmamaktadır.');
      return;
    }

    // Recalculate summary based on current _dailySalesData just to be sure.
    _calculateDailySummary();
    // _totalAmount, _totalCost, _totalProducts, _totalSales are now up-to-date by _calculateDailySummary

    final now = DateTime.now();
    // The summary map structure needs to align with what AccountingService might expect for a daily summary,
    // or if we are still saving it as a 'sale' of type 'summary' via SalesService.
    // For now, let's assume we are creating a special Map to be saved via _salesService.addSale,
    // similar to the old StorageService behavior.
    // Ideally, AccountingService would have a method like `saveDailyFinancialSummary`.

    // This map is for the 'summary' type sale entry.
    final summaryMap = {
      'id': getIt<Uuid>().v4(),
      'date': DateFormat('yyyy-MM-dd').format(now),
      'timestamp': now.toIso8601String(),
      'openingTime': _dayStartTime?.toIso8601String(),
      'closingTime': now.toIso8601String(),
      'totalSales': _totalAmount.toString(), // total revenue
      'totalCost': _totalCost.toString(),   // total cost of goods sold
      'totalProducts': _totalProducts.toString(), // total quantity of items
      'cashAmount': '0', // These will be filled by the dialog
      'cardAmount': '0',
      'marketAmount': '0',
      'type': 'summary', // Special type for summary entries
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
                // All individual sales in _dailySalesData should already be saved when they were added.
                // So, here we only need to save the summary.
                // SalesService.addSale expects Map<String, dynamic>
                await _salesService.addSale(summaryMap);
              
                // Update local state if necessary, then reload from service for consistency
                _loadData(); // This will refresh all data from services.

              Navigator.pop(context);
                _showSuccess('Gün sonu başarıyla kaydedildi');

                _tabController.animateTo(1); // Navigate to sales history
            },
            text: 'Tamamla',
            semanticLabel: 'Tamamla Butonu',
          ),
        ],
      ),
    );

    // Gün bitince flag'i sıfırla
    final prefs = await SharedPreferences.getInstance();
    // Day start/end flags
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('day_started', false);
    await prefs.remove('day_start_time');
    // Potentially: await _accountingService.endBusinessDay(now, summaryMap);
    setState(() {
      _dayStarted = false;
      _dayStartTime = null;
      _dailySalesData.clear(); // Clear today's sales from local list
      _calculateDailySummary(); // Recalculate, should be zero
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
              height: 400, // Consider making this dynamic or using Expanded
              child: _buildSalesList(
                _dailySalesData, // Use the renamed list
                'Bugün için satış bulunmamaktadır.',
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

Widget _buildSalesList(List<AppSaleModel.Sale> sales, String emptyMessage) { // Changed to use AppSaleModel.Sale
  if (sales.isEmpty) {
    return Center(child: Text(emptyMessage, style: AppTextStyles.body));
  }

  return ListView.builder(
    itemCount: sales.length,
    itemBuilder: (context, index) {
      final sale = sales[index]; // This is now an AppSaleModel.Sale object

      // Displaying individual sale items from the Sale object
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
                  Text(
                    'Satış ID: ${sale.id.substring(0, 8)}', // Display part of Sale ID
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(sale.date),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Toplam Tutar: ${sale.totalAmount.toStringAsFixed(2)} TL', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              Text('Toplam Maliyet: ${sale.totalCost.toStringAsFixed(2)} TL'),
              const SizedBox(height: 8),
              const Text('Ürünler:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...sale.items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('- ${item.productName} (${item.quantity} adet x ${item.price.toStringAsFixed(2)} TL)'),
                    Text('  Maliyet: ${(item.cost * item.quantity).toStringAsFixed(2)} TL', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      );
    },
  );
}


Widget _buildSalesHistoryList() {
  if (_salesHistory.isEmpty) { // _salesHistory is List<AppSaleModel.Sale>
    return const Center(child: Text('Henüz satış kaydı bulunmamaktadır.'));
  }

  // Group sales by date
  final Map<String, List<AppSaleModel.Sale>> groupedSales = {};
  for (final sale in _salesHistory) {
    final dateKey = DateFormat('yyyy-MM-dd').format(sale.date);
    groupedSales.putIfAbsent(dateKey, () => []).add(sale);
  }

  final sortedDates = groupedSales.keys.toList()..sort((a, b) => b.compareTo(a));

  return ListView.builder(
    itemCount: sortedDates.length,
    itemBuilder: (context, index) {
      final dateKey = sortedDates[index];
      final salesOnDate = groupedSales[dateKey]!;

      // Calculate daily totals for display in ExpansionTile title
      double dailyTotalAmount = salesOnDate.fold(0, (sum, sale) => sum + sale.totalAmount);
      int dailyTotalItems = salesOnDate.fold(0, (sum, sale) => sum + sale.items.fold(0, (itemSum, item) => itemSum + item.quantity));

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ExpansionTile(
          title: Text(
            DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.parse(dateKey)),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$dailyTotalItems ürün, Toplam: ${dailyTotalAmount.toStringAsFixed(2)} TL'),
          children: salesOnDate.map((sale) {
            // This is similar to _buildSalesList item builder
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text('Satış ID: ${sale.id.substring(0,8)} (${DateFormat('HH:mm').format(sale.date)})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sale.items.map((item) => Text('${item.productName} x${item.quantity} @ ${item.price.toStringAsFixed(2)} TL')).toList(),
                ),
                trailing: Text('${sale.totalAmount.toStringAsFixed(2)} TL', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          }).toList(),
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