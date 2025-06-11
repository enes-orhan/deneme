import 'package:flutter/material.dart';
import '../models/product.dart';
import '../constants/app_constants.dart';

class ProductListWidget extends StatelessWidget {
  final List<Product> products;
  final ScrollController scrollController;
  final Function(Product) onProductTap;
  final Function(Product) onProductLongPress;

  const ProductListWidget({
    Key? key,
    required this.products,
    required this.scrollController,
    required this.onProductTap,
    required this.onProductLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: products.length,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        final isLowStock = product.quantity <= 3;
        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isLowStock ? Colors.red[50] : AppColors.backgroundSecondary,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onProductTap(product),
            onLongPress: () => onProductLongPress(product),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${product.brand} • ${product.model}',
                              style: AppTextStyles.body.copyWith(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sell, color: AppColors.primary, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '${product.sellingPrice.toStringAsFixed(2)} ₺',
                                  style: AppTextStyles.heading2.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.inventory_2, color: Colors.grey[600], size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'Stok: ${product.quantity}',
                                  style: TextStyle(
                                    color: isLowStock ? Colors.red : Colors.grey[800],
                                    fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildInfoChip(Icons.color_lens, product.color, Colors.deepPurple),
                      _buildInfoChip(Icons.straighten, product.size, Colors.teal),
                      _buildInfoChip(Icons.place, product.region, Colors.orange),
                      if (product.barcode != null && product.barcode!.isNotEmpty)
                        _buildInfoChip(Icons.qr_code, product.barcode!, Colors.blueGrey),
                      if (product.category.isNotEmpty)
                        _buildInfoChip(Icons.category, product.category, Colors.indigo),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.green[700], size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Maliyet: ${product.finalCost.toStringAsFixed(2)} ₺',
                        style: AppTextStyles.body.copyWith(color: Colors.green[700], fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.percent, color: Colors.amber[800], size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Kâr: ${product.averageProfitMargin.toStringAsFixed(1)}%',
                        style: AppTextStyles.body.copyWith(color: Colors.amber[800], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      backgroundColor: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
} 