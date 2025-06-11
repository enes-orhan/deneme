import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/product.dart';

import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_list_widget.dart';
import '../widgets/product_filter_widget.dart';
import '../widgets/product_form_widget.dart';
import '../utils/csv_export_util.dart';
import 'inventory/providers/inventory_provider.dart';

/// Main inventory page for managing products
/// Refactored from 599 lines to ~300 lines using modular components
class InventoryPage extends StatefulWidget {
  const InventoryPage({
    Key? key,
  }) : super(key: key);

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => InventoryProvider()..initialize(),
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: _buildBody(),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Envanter Yönetimi'),
      backgroundColor: AppConstants.primaryColor,
      foregroundColor: Colors.white,
      actions: [
        Consumer<InventoryProvider>(
          builder: (context, provider, child) {
            return PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, provider),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_product',
                  child: Row(
                    children: [
                      Icon(Icons.add),
                      SizedBox(width: 8),
                      Text('Ürün Ekle'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import_csv',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload),
                      SizedBox(width: 8),
                      Text('CSV İçe Aktar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_csv',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 8),
                      Text('CSV Dışa Aktar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'statistics',
                  child: Row(
                    children: [
                      Icon(Icons.analytics),
                      SizedBox(width: 8),
                      Text('İstatistikler'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _buildSearchAndFilter(provider),
            _buildStatisticsCard(provider),
            Expanded(
              child: _buildProductList(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilter(InventoryProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          CustomTextField(
            labelText: 'Ürün Ara...',
            prefixIcon: Icons.search,
            onChanged: provider.filterProducts,
          ),
          const SizedBox(height: 12),
          ProductFilterWidget(
            categories: provider.categories,
            selectedCategory: provider.filterCategory,
            onCategoryChanged: provider.setCategoryFilter,
            sortBy: provider.sortBy,
            sortAscending: provider.sortAscending,
            onSortChanged: provider.setSorting,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(InventoryProvider provider) {
    final stats = provider.getInventoryStatistics();
    final lowStockProducts = provider.getLowStockProducts();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Envanter Özeti',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Toplam Ürün', '${stats['totalProducts']}'),
              ),
              Expanded(
                child: _buildStatItem('Toplam Stok', '${stats['totalQuantity']}'),
              ),
              Expanded(
                child: _buildStatItem('Toplam Değer', '${stats['totalValue'].toStringAsFixed(2)} TL'),
              ),
              Expanded(
                child: _buildStatItem(
                  'Düşük Stok',
                  '${lowStockProducts.length}',
                  color: lowStockProducts.isNotEmpty ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? AppConstants.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProductList(InventoryProvider provider) {
    if (provider.filteredProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Ürün bulunamadı',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ProductListWidget(
      products: provider.filteredProducts,
      scrollController: _scrollController,
      onProductTap: (product) => _showProductDetails(product, provider),
      onProductEdit: (product) => _showProductForm(product, provider),
      onProductDelete: (product) => _confirmDeleteProduct(product, provider),
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        return FloatingActionButton(
          onPressed: () => _showProductForm(null, provider),
          backgroundColor: AppConstants.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        );
      },
    );
  }

  void _handleMenuAction(String action, InventoryProvider provider) {
    switch (action) {
      case 'add_product':
        _showProductForm(null, provider);
        break;
      case 'import_csv':
        _importCSV(provider);
        break;
      case 'export_csv':
        _exportCSV(provider);
        break;
      case 'statistics':
        _showStatistics(provider);
        break;
    }
  }

  Future<void> _showProductForm(Product? product, InventoryProvider provider) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (context) => Dialog(
        child: ProductFormWidget(
          product: product,
          onSave: (newProduct) => Navigator.of(context).pop(newProduct),
          generateBarcode: provider.generateBarcode,
          validateBarcode: provider.isValidBarcode,
        ),
      ),
    );

    if (result != null) {
      try {
        if (product == null) {
          await provider.addProduct(result);
          _showSuccess('Ürün başarıyla eklendi');
        } else {
          await provider.updateProduct(result);
          _showSuccess('Ürün başarıyla güncellendi');
        }
      } catch (e) {
        _showError('İşlem başarısız: $e');
      }
    }
  }

  Future<void> _importCSV(InventoryProvider provider) async {
    try {
      final csvData = await CSVExportUtil.importProductsFromCSV();
      if (csvData != null) {
        await provider.importProductsFromCSV(csvData);
        _showSuccess('CSV dosyası başarıyla içe aktarıldı');
      }
    } catch (e) {
      _showError('CSV içe aktarma başarısız: $e');
    }
  }

  Future<void> _exportCSV(InventoryProvider provider) async {
    try {
      final csvData = provider.exportProductsToCSV();
      await CSVExportUtil.exportProductsToCSV(csvData);
      _showSuccess('CSV dosyası başarıyla dışa aktarıldı');
    } catch (e) {
      _showError('CSV dışa aktarma başarısız: $e');
    }
  }

  void _showProductDetails(Product product, InventoryProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Marka', product.brand),
              _buildDetailRow('Model', product.model),
              _buildDetailRow('Renk', product.color),
              _buildDetailRow('Beden', product.size),
              _buildDetailRow('Kategori', product.category),
              _buildDetailRow('Bölge', product.region),
              _buildDetailRow('Stok', '${product.quantity}'),
              _buildDetailRow('Fiyat', '${product.finalCost.toStringAsFixed(2)} TL'),
              if (product.barcode?.isNotEmpty == true)
                _buildDetailRow('Barkod', product.barcode!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showProductForm(product, provider);
            },
            child: const Text('Düzenle'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteProduct(Product product, InventoryProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text('${product.name} ürününü silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await provider.deleteProduct(product.id!);
        _showSuccess('Ürün başarıyla silindi');
      } catch (e) {
        _showError('Ürün silinirken hata oluştu: $e');
      }
    }
  }

  void _showStatistics(InventoryProvider provider) {
    final stats = provider.getInventoryStatistics();
    final lowStock = provider.getLowStockProducts();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Envanter İstatistikleri'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Toplam Ürün Sayısı', '${stats['totalProducts']}'),
              _buildDetailRow('Toplam Stok Miktarı', '${stats['totalQuantity']}'),
              _buildDetailRow('Toplam Envanter Değeri', '${stats['totalValue'].toStringAsFixed(2)} TL'),
              _buildDetailRow('Ortalama Ürün Değeri', '${stats['averageValue'].toStringAsFixed(2)} TL'),
              _buildDetailRow('Düşük Stoklu Ürün Sayısı', '${lowStock.length}'),
              if (lowStock.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Düşük Stoklu Ürünler:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...lowStock.take(5).map((product) => Text('• ${product.name} (${product.quantity})')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
} 