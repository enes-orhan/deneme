import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../constants/app_constants.dart';
import 'custom_text_field.dart';

class ProductFormWidget extends StatefulWidget {
  final Product? product;
  final Function(Product) onSubmit;

  const ProductFormWidget({
    Key? key,
    this.product,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<ProductFormWidget> createState() => _ProductFormWidgetState();
}

class _ProductFormWidgetState extends State<ProductFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _colorController;
  late TextEditingController _sizeController;
  late TextEditingController _quantityController;
  late TextEditingController _regionController;
  late TextEditingController _barcodeController;
  late TextEditingController _unitCostController;
  late TextEditingController _vatController;
  late TextEditingController _expenseRatioController;
  late TextEditingController _finalCostController;
  late TextEditingController _averageProfitMarginController;
  late TextEditingController _recommendedPriceController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _brandController = TextEditingController(text: widget.product?.brand ?? '');
    _modelController = TextEditingController(text: widget.product?.model ?? '');
    _colorController = TextEditingController(text: widget.product?.color ?? '');
    _sizeController = TextEditingController(text: widget.product?.size ?? '');
    _quantityController = TextEditingController(text: widget.product?.quantity.toString() ?? '0');
    _regionController = TextEditingController(text: widget.product?.region ?? '');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    _unitCostController = TextEditingController(text: widget.product?.unitCost.toString() ?? '0');
    _vatController = TextEditingController(text: widget.product?.vat.toString() ?? '0');
    _expenseRatioController = TextEditingController(text: widget.product?.expenseRatio.toString() ?? '0');
    _finalCostController = TextEditingController(text: widget.product?.finalCost.toString() ?? '0');
    _averageProfitMarginController = TextEditingController(text: widget.product?.averageProfitMargin.toString() ?? '0');
    _recommendedPriceController = TextEditingController(text: widget.product?.recommendedPrice.toString() ?? '0');
    _purchasePriceController = TextEditingController(text: widget.product?.purchasePrice.toString() ?? '0');
    _sellingPriceController = TextEditingController(text: widget.product?.sellingPrice.toString() ?? '0');
    _categoryController = TextEditingController(text: widget.product?.category ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    _quantityController.dispose();
    _regionController.dispose();
    _barcodeController.dispose();
    _unitCostController.dispose();
    _vatController.dispose();
    _expenseRatioController.dispose();
    _finalCostController.dispose();
    _averageProfitMarginController.dispose();
    _recommendedPriceController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _calculateFinalCost() {
    try {
      final unitCost = double.parse(_unitCostController.text);
      final vat = double.parse(_vatController.text);
      final expenseRatio = double.parse(_expenseRatioController.text);
      
      final vatAmount = unitCost * (vat / 100);
      final expenseAmount = (unitCost + vatAmount) * (expenseRatio / 100);
      final finalCost = unitCost + vatAmount + expenseAmount;
      
      setState(() {
        _finalCostController.text = finalCost.toStringAsFixed(2);
        _calculateRecommendedPrice();
      });
    } catch (e) {
      // Hata durumunda işlem yapma
    }
  }

  void _calculateRecommendedPrice() {
    try {
      final finalCost = double.parse(_finalCostController.text);
      final profitMargin = double.parse(_averageProfitMarginController.text);
      
      final recommendedPrice = finalCost * (1 + (profitMargin / 100));
      
      setState(() {
        _recommendedPriceController.text = recommendedPrice.toStringAsFixed(2);
        _sellingPriceController.text = recommendedPrice.toStringAsFixed(2);
      });
    } catch (e) {
      // Hata durumunda işlem yapma
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product == null ? 'Yeni Ürün' : 'Ürün Düzenle',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _nameController,
              label: 'Ürün Adı',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen ürün adını girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _brandController,
              label: 'Marka',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen marka girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _modelController,
              label: 'Model',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen model girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _colorController,
                    label: 'Renk',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen renk girin';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: _sizeController,
                    label: 'Beden',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen beden girin';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _quantityController,
                    label: 'Stok',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen stok girin';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Geçerli bir sayı girin';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: _regionController,
                    label: 'Bölge',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen bölge girin';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _barcodeController,
              label: 'Barkod',
            ),
            const SizedBox(height: 16),
            Text(
              'Maliyet Bilgileri',
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _unitCostController,
                    label: 'Birim Maliyet',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateFinalCost(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen birim maliyet girin';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Geçerli bir sayı girin';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: _vatController,
                    label: 'KDV (%)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateFinalCost(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen KDV girin';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Geçerli bir sayı girin';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _expenseRatioController,
                    label: 'Gider Oranı (%)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateFinalCost(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen gider oranı girin';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Geçerli bir sayı girin';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: _finalCostController,
                    label: 'Toplam Maliyet',
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Fiyat Bilgileri',
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _averageProfitMarginController,
                    label: 'Kar Marjı (%)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateRecommendedPrice(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen kar marjı girin';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Geçerli bir sayı girin';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: _recommendedPriceController,
                    label: 'Önerilen Fiyat',
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _purchasePriceController,
                    label: 'Alış Fiyatı',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen alış fiyatı girin';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Geçerli bir sayı girin';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: _sellingPriceController,
                    label: 'Satış Fiyatı',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen satış fiyatı girin';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Geçerli bir sayı girin';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _categoryController,
              label: 'Kategori',
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final product = Product(
                        id: widget.product?.id ?? const Uuid().v4(),
                        name: _nameController.text,
                        brand: _brandController.text,
                        model: _modelController.text,
                        color: _colorController.text,
                        size: _sizeController.text,
                        quantity: int.parse(_quantityController.text),
                        region: _regionController.text,
                        barcode: _barcodeController.text,
                        unitCost: double.parse(_unitCostController.text),
                        vat: double.parse(_vatController.text),
                        expenseRatio: double.parse(_expenseRatioController.text),
                        finalCost: double.parse(_finalCostController.text),
                        averageProfitMargin: double.parse(_averageProfitMarginController.text),
                        recommendedPrice: double.parse(_recommendedPriceController.text),
                        purchasePrice: double.parse(_purchasePriceController.text),
                        sellingPrice: double.parse(_sellingPriceController.text),
                        category: _categoryController.text,
                      );
                      widget.onSubmit(product);
                      Navigator.pop(context);
                    }
                  },
                  child: Text(widget.product == null ? 'Ekle' : 'Güncelle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 