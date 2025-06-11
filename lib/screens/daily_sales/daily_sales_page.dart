import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/product.dart';

import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'providers/daily_sales_provider.dart';
import 'components/sales_summary_widget.dart';
import 'components/barcode_scanner_widget.dart';
import 'components/day_management_widget.dart';
import '../../utils/csv_export_util.dart';

/// Refactored daily sales page with modular components
/// TODO: Migrate to Repository pattern - currently using StorageService
class DailySalesPage extends StatefulWidget {
  const DailySalesPage({
    Key? key,
  }) : super(key: key);

  @override
  State<DailySalesPage> createState() => _DailySalesPageState();
}

class _DailySalesPageState extends State<DailySalesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DailySalesProvider _provider;
  
  // Form controllers
  final _barcodeController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _provider = DailySalesProvider();
    
    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Consumer<DailySalesProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!provider.dayStarted) {
              return DayManagementWidget(
                dayStarted: provider.dayStarted,
                dayStartTime: provider.dayStartTime,
                onStartDay: _handleStartDay,
                isLoading: provider.isLoading,
              );
            }

            return Column(
              children: [
                // Day status and management
                DayManagementWidget(
                  dayStarted: provider.dayStarted,
                  dayStartTime: provider.dayStartTime,
                  onEndDay: _handleEndDay,
                  isLoading: provider.isLoading,
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSalesTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Günlük Satışlar'),
      backgroundColor: AppColors.primary,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Satış', icon: Icon(Icons.point_of_sale)),
          Tab(text: 'Geçmiş', icon: Icon(Icons.history)),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _selectDate,
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Tarih Seç',
        ),
      ],
    );
  }

  Widget _buildSalesTab() {
    return Consumer<DailySalesProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          child: Column(
            children: [
              // Sales Summary
              SalesSummaryWidget(
                totalSales: provider.totalSales,
                totalProducts: provider.totalProducts,
                totalAmount: provider.totalAmount,
                totalCost: provider.totalCost,
                totalProfit: provider.totalProfit,
                openingTime: provider.openingTime,
                onExportSummary: _exportSummary,
              ),
              
              // Sales Form
              _buildSalesForm(),
              
              // Today's Sales List
              _buildTodaysSalesList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni Satış',
                style: AppTextStyles.heading2,
              ),
              const SizedBox(height: 16),
              
              // Barcode input with scanner
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _barcodeController,
                      labelText: 'Barkod',
                      onChanged: _onBarcodeChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showBarcodeScanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Barkod Tara',
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Product selection dropdown
              Consumer<DailySalesProvider>(
                builder: (context, provider, child) {
                  return DropdownButtonFormField<Product>(
                    value: provider.selectedProduct,
                    decoration: const InputDecoration(
                      labelText: 'Ürün Seç',
                      border: OutlineInputBorder(),
                    ),
                    items: provider.products.map((product) {
                      return DropdownMenuItem(
                        value: product,
                        child: Text('${product.name} - ${product.brand} (Stok: ${product.quantity})'),
                      );
                    }).toList(),
                    onChanged: provider.setSelectedProduct,
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Quantity input
              CustomTextField(
                controller: _quantityController,
                labelText: 'Adet',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Adet giriniz';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Geçerli bir adet giriniz';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Add sale button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Satış Ekle',
                  onPressed: _addSale,
                  icon: Icons.add_shopping_cart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaysSalesList() {
    return Consumer<DailySalesProvider>(
      builder: (context, provider, child) {
        if (provider.dailySales.isEmpty) {
          return Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz satış yok',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Bugünkü Satışlar',
                  style: AppTextStyles.heading2,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.dailySales.length,
                itemBuilder: (context, index) {
                  final sale = provider.dailySales[index];
                  return _buildSaleItem(sale);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaleItem(Map<String, dynamic> sale) {
    final productName = sale['productName'] ?? 'Bilinmiyor';
    final quantity = int.tryParse(sale['quantity']?.toString() ?? '0') ?? 0;
    final price = double.tryParse(sale['price']?.toString() ?? '0') ?? 0.0;
    final total = quantity * price;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: Icon(Icons.shopping_bag, color: AppColors.primary),
      ),
      title: Text(productName),
      subtitle: Text('Adet: $quantity × ${price.toStringAsFixed(2)} ₺'),
      trailing: Text(
        '${total.toStringAsFixed(2)} ₺',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Consumer<DailySalesProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Date selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tarih: ${DateFormat('dd/MM/yyyy').format(provider.selectedDate)}',
                      style: AppTextStyles.heading3,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Değiştir'),
                  ),
                ],
              ),
            ),
            
            // Sales history list
            Expanded(
              child: provider.salesHistory.isEmpty
                  ? const Center(
                      child: Text('Bu tarihte satış bulunamadı'),
                    )
                  : ListView.builder(
                      itemCount: provider.salesHistory.length,
                      itemBuilder: (context, index) {
                        final sale = provider.salesHistory[index];
                        return _buildSaleItem(sale);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // Event handlers
  Future<void> _handleStartDay() async {
    try {
      final confirmed = await DayManagementWidget.showStartDayConfirmation(context);
      if (confirmed) {
        await _provider.startDay();
        _showSuccess('Gün başarıyla başlatıldı');
      }
    } catch (e) {
      _showError('Gün başlatılırken hata oluştu: $e');
    }
  }

  Future<void> _handleEndDay() async {
    try {
      final confirmed = await DayManagementWidget.showEndDayConfirmation(context);
      if (confirmed) {
        await _provider.endDay();
        _showSuccess('Gün başarıyla bitirildi');
      }
    } catch (e) {
      _showError('Gün bitirilirken hata oluştu: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await _provider.changeSelectedDate(picked);
    }
  }

  void _onBarcodeChanged(String barcode) {
    if (barcode.isEmpty) return;
    
    final product = _provider.findProductByBarcode(barcode);
    if (product != null) {
      _provider.setSelectedProduct(product);
    } else {
      _showError('Barkod bulunamadı: $barcode');
    }
  }

  void _showBarcodeScanner() {
    BarcodeScannerWidget.show(
      context,
      onBarcodeDetected: (barcode) {
        _barcodeController.text = barcode;
        _onBarcodeChanged(barcode);
      },
    );
  }

  Future<void> _addSale() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedProduct = _provider.selectedProduct;
    if (selectedProduct == null) {
      _showError('Lütfen bir ürün seçin');
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      _showError('Geçerli bir adet girin');
      return;
    }

    try {
      await _provider.addSale(
        product: selectedProduct,
        quantity: quantity,
      );

      // Reset form
      _barcodeController.clear();
      _quantityController.text = '1';
      _provider.setSelectedProduct(null);
      
      _showSuccess('Satış başarıyla eklendi');
    } catch (e) {
      _showError('Satış eklenirken hata oluştu: $e');
    }
  }

  Future<void> _exportSummary() async {
    try {
      final filePath = await CsvExportUtil.instance.exportDailySalesSummary(
        date: _provider.selectedDate,
        totalSales: _provider.totalSales,
        totalProducts: _provider.totalProducts,
        totalAmount: _provider.totalAmount,
        totalCost: _provider.totalCost,
        totalProfit: _provider.totalProfit,
        openingTime: _provider.openingTime,
      );
      
      _showSuccess('Özet dışa aktarıldı: $filePath');
    } catch (e) {
      _showError('Özet dışa aktarılırken hata oluştu: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
} 