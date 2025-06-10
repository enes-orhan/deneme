import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // min fonksiyonu için
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';
import '../models/product.dart';
import '../services/product_service.dart'; // Changed
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'package:uuid/uuid.dart';
import '../services/service_locator.dart'; // Added for getIt
import '../widgets/product_list_widget.dart';
import '../widgets/product_filter_widget.dart';
import '../widgets/product_form_widget.dart';

class InventoryPage extends StatefulWidget {
  // final StorageService storageService; // Removed

  const InventoryPage({
    Key? key,
    // required this.storageService, // Removed
  }) : super(key: key);

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late ProductService _productService; // Added
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterCategory = 'Tümü';
  List<String> _categories = ['Tümü'];
  
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>(); // Added
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getProducts();
      
      // Tüm kategorileri çıkart
      final categories = <String>{'Tümü'};
      for (var product in products) {
        if (product.category.isNotEmpty) {
          categories.add(product.category);
        }
      }
      
      setState(() {
        _products = products;
        _filteredProducts = products;
        _categories = categories.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ürünler yüklenirken bir hata oluştu: $e');
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredProducts = _products.where((product) {
      // Önce arama sorgusuna göre filtrele
      final searchMatch = _searchQuery.isEmpty || 
        product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.model.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.color.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.size.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.region.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (product.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      // Sonra kategoriye göre filtrele
      final categoryMatch = _filterCategory == 'Tümü' || product.category == _filterCategory;
      
      return searchMatch && categoryMatch;
    }).toList();
    
    _sortProducts();
  }

  void _sortProducts() {
    _filteredProducts.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'brand':
          comparison = a.brand.compareTo(b.brand);
          break;
        case 'quantity':
          comparison = a.quantity.compareTo(b.quantity);
          break;
        case 'region':
          comparison = a.region.compareTo(b.region);
          break;
        case 'price':
          comparison = a.finalCost.compareTo(b.finalCost);
          break;
        default:
          comparison = a.name.compareTo(b.name);
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  Future<bool> _requestPermissions() async {
    // Android 13 ve üzeri için farklı izinleri iste
    if (await Permission.storage.status.isDenied ||
        await Permission.manageExternalStorage.status.isDenied) {
      
      if (await Permission.storage.request().isGranted) {
        print("Storage permission granted");
        return true;
      }
      
      // API 33+ için
      final mediaPermissions = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
      
      print("Media permissions: $mediaPermissions");
      
      // Son çare olarak manageExternalStorage iste
      try {
        await Permission.manageExternalStorage.request();
        print("ManageExternalStorage: ${await Permission.manageExternalStorage.status}");
      } catch (e) {
        print("Error requesting manageExternalStorage: $e");
      }
    }
    
    // İzin durumunu kontrol et
    bool hasStoragePermission = await Permission.storage.isGranted;
    bool hasManagePermission = await Permission.manageExternalStorage.isGranted;
    bool hasPhotosPermission = await Permission.photos.isGranted;
    
    print("Permissions: storage=$hasStoragePermission, manage=$hasManagePermission, photos=$hasPhotosPermission");
    
    return hasStoragePermission || hasManagePermission || hasPhotosPermission;
  }

  // Removed local _isValidBarcode and _generateBarcode methods.
  // Barcode generation is handled by ProductService.createProductFromCSV or ProductService.addProduct.
  // Barcode validation, if needed for user input, would require an exposed method in ProductService.

  Future<void> _importFromCSV() async {
    try {
      // Önce izinleri kontrol et
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showError('Dosya erişim izni verilmedi. Lütfen ayarlardan izin verin.');
        return;
      }
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          print('Seçilen dosya yolu: ${file.path}');
          final input = File(file.path!).readAsStringSync();
          print('Dosya içeriği: ${input.substring(0, min(100, input.length))}...'); // İlk 100 karakteri göster
          
          // CSV ayırıcı olarak hem virgül hem de noktalı virgül deneyeceğiz
          List<List<dynamic>> rows = [];
          
          try {
            // Önce noktalı virgül (;) ile deneyelim
            if (input.contains(';')) {
              rows = const CsvToListConverter(fieldDelimiter: ';').convert(input);
              print('Noktalı virgül ayırıcı ile CSV dönüştürüldü. Satır sayısı: ${rows.length}');
            } else {
              // Yoksa normal virgül (,) ile deneyelim
              rows = const CsvToListConverter().convert(input);
              print('Virgül ayırıcı ile CSV dönüştürüldü. Satır sayısı: ${rows.length}');
            }
          } catch (e) {
            print('CSV dönüştürme hatası: $e');
            _showError('CSV dosyası dönüştürülürken bir hata oluştu: $e');
            return;
          }
          
          print('CSV satır sayısı: ${rows.length}');
          if (rows.isEmpty) {
            _showError('CSV dosyası boş görünüyor');
            return;
          }
          
          if (rows.length > 1) { // Başlık satırı + en az bir veri satırı
            // Önce veritabanını sıfırlayalım (ürünler dahil tüm DB sıfırlanır)
            await getIt<AccountingService>().resetDatabase();
            print('Veritabanı sıfırlandı (AccountingService aracılığıyla). CSV içe aktarma başlıyor...');
            
            final products = <Product>[];
            
            // İlk satır başlık satırı, onu atla
            for (var i = 1; i < rows.length; i++) {
              final row = rows[i];
              print('Satır $i: $row');
              
              try {
                // En az gerekli alan sayısı kontrolü
                if (row.length < 8) {
                  print('Satır $i yeterli alana sahip değil. Beklenen: >=8, Bulunan: ${row.length}');
                  continue; // Bu satırı atla ama diğer satırları işlemeye devam et
                }
                
                // Kolon değerlerini sayısal değere çevirirken % işaretini ve benzeri karakterleri temizleyelim
                String cleanValue(dynamic value) {
                  if (value == null) return '';
                  String strValue = value.toString().trim();
                  // Sayısal değeri etkileyecek tüm karakterleri kaldır
                  return strValue
                    .replaceAll('%', '')
                    .replaceAll('TL', '')
                    .replaceAll('₺', '')
                    .replaceAll(',', '.')  // Virgülleri nokta ile değiştir (Türkçe format)
                    .replaceAll(' ', '')
                    .trim();
                }
                
                // Convert dynamic list to List<String> for createProductFromCSV
                final rowAsStringList = row.map((dynamic item) => item.toString()).toList();
                final product = _productService.createProductFromCSV(rowAsStringList);
                products.add(product);
                print('CSV Satırından oluşturulan ürün: ${product.name}, Barkod: ${product.barcode}');
              } catch (e) {
                print('CSV satır $i işleme hatası: $e. Satır verisi: $row');
                // Optionally, show an error to the user for this specific row, or collect errors.
              }
            }
            
            if (products.isNotEmpty) {
              // Assuming ProductService.saveProducts handles existing products appropriately (e.g., updates or skips)
              // or if a reset is done before this, it just saves all.
              await _productService.saveProducts(products);
              await _loadProducts();
              _showSuccess('${products.length} ürün başarıyla içe aktarıldı');
            } else {
              _showError('CSV dosyasında geçerli ürün bulunamadı. Lütfen format ve içeriği kontrol edin.');
            }
          } else {
            _showError('CSV dosyası boş veya geçersiz format');
          }
        } else {
          _showError('Dosya yolu alınamadı');
        }
      }
    } catch (e) {
      print('CSV içe aktarma hatası: $e');
      _showError('CSV dosyası içe aktarılırken bir hata oluştu: $e');
    }
  }

  Future<void> _exportToCSV() async {
    try {
      // Önce izinleri kontrol et
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showError('Dosya erişim izni verilmedi. Lütfen ayarlardan izin verin.');
        return;
      }
      
      final products = await _productService.getProducts(); // Changed
      
      if (products.isEmpty) {
        _showError('Dışa aktarılacak ürün bulunamadı');
        return;
      }

      final csvData = [
        ['Ürün Adı', 'Marka', 'Model', 'Renk', 'Beden', 'Adet', 'Bölge', 'Barkod', 'Adet Maliyeti', 'KDV', 'Gider Oranı', 'Son Maliyet', 'Kar Marjı', 'Tavsiye Fiyat', 'Kategori'],
        ...products.map((p) => [
          p.name,
          p.brand,
          p.model,
          p.color,
          p.size,
          p.quantity.toString(),
          p.region,
          p.barcode ?? '',
          p.unitCost.toString(),
          p.vat.toString(),
          p.expenseRatio.toString(),
          p.finalCost.toString(),
          p.averageProfitMargin.toString(),
          p.recommendedPrice.toString(),
          p.category,
        ]),
      ];

      // Türkçe tablo programları için noktalı virgül (;) ayırıcısı kullanarak CSV oluşturuyoruz
      final csvString = const ListToCsvConverter(fieldDelimiter: ';').convert(csvData);
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'CSV Dosyasını Kaydet',
        fileName: 'envanter_${DateTime.now().toString().split(' ')[0]}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(csvString, encoding: utf8);
        print('CSV dosyası kaydedildi: $result');
        _showSuccess('Ürünler başarıyla dışa aktarıldı');
      }
    } catch (e) {
      print('CSV dışa aktarma hatası: $e');
      _showError('CSV dosyası dışa aktarılırken bir hata oluştu: $e');
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

  void _showProductForm([Product? product]) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ProductFormWidget(
          product: product,
          onSubmit: (updatedProduct) async {
            try {
              if (product == null) {
                // Potentially use _productService._generateBarcode internally if product.barcode is empty
                // Or ensure ProductFormWidget calls a service method to generate it before submitting.
                // For now, assuming updatedProduct comes with a barcode if needed.
                await _productService.addProduct(updatedProduct); // Changed
                _showSuccess('Ürün başarıyla eklendi');
              } else {
                await _productService.updateProduct(updatedProduct); // Changed
                _showSuccess('Ürün başarıyla güncellendi');
              }
              _loadProducts();
            } catch (e) {
              _showError('Ürün kaydedilirken bir hata oluştu: $e');
            }
          },
        ),
                      ),
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text('${product.name} ürününü silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _productService.deleteProduct(product.id); // Changed
                _showSuccess('Ürün başarıyla silindi');
                _loadProducts();
                Navigator.pop(context);
              } catch (e) {
                _showError('Ürün silinirken bir hata oluştu: $e');
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.inventory),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importFromCSV,
            tooltip: 'CSV İçe Aktar',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportToCSV,
            tooltip: 'CSV Dışa Aktar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
                ProductFilterWidget(
                  searchQuery: _searchQuery,
                  sortBy: _sortBy,
                  sortAscending: _sortAscending,
                  filterCategory: _filterCategory,
                  categories: _categories,
                  onSearchChanged: _filterProducts,
                  onSortChanged: (value) {
                                setState(() {
                                  _sortBy = value;
                                  _sortProducts();
                                });
                  },
                  onSortDirectionChanged: (value) {
                        setState(() {
                      _sortAscending = value;
                          _sortProducts();
                        });
                      },
                  onCategoryChanged: (value) {
                                  setState(() {
                      _filterCategory = value;
                      _applyFilters();
                                  });
                                },
                              ),
                Expanded(
                  child: ProductListWidget(
                    products: _filteredProducts,
                    scrollController: _scrollController,
                    onProductTap: _showProductForm,
                    onProductLongPress: _showDeleteConfirmation,
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text('Yeni Ürün'),
      ),
    );
  }
} 