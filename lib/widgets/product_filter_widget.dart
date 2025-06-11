import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class ProductFilterWidget extends StatelessWidget {
  final String searchQuery;
  final String sortBy;
  final bool sortAscending;
  final String filterCategory;
  final List<String> categories;
  final Function(String) onSearchChanged;
  final Function(String) onSortChanged;
  final Function(bool) onSortDirectionChanged;
  final Function(String) onCategoryChanged;

  const ProductFilterWidget({
    Key? key,
    required this.searchQuery,
    required this.sortBy,
    required this.sortAscending,
    required this.filterCategory,
    required this.categories,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onSortDirectionChanged,
    required this.onCategoryChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtreler',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Ürün ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: sortBy,
                    decoration: InputDecoration(
                      labelText: 'Sıralama',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('İsim')),
                      DropdownMenuItem(value: 'brand', child: Text('Marka')),
                      DropdownMenuItem(value: 'quantity', child: Text('Stok')),
                      DropdownMenuItem(value: 'region', child: Text('Bölge')),
                      DropdownMenuItem(value: 'price', child: Text('Fiyat')),
                    ],
                    onChanged: (value) {
                      if (value != null) onSortChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                  onPressed: () => onSortDirectionChanged(!sortAscending),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: filterCategory,
              decoration: InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) onCategoryChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
} 