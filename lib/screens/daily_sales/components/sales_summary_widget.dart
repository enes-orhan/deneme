import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';

/// Widget for displaying daily sales summary information
class SalesSummaryWidget extends StatelessWidget {
  final int totalSales;
  final int totalProducts;
  final double totalAmount;
  final double totalCost;
  final double totalProfit;
  final DateTime? openingTime;
  final DateTime? closingTime;
  final VoidCallback? onExportSummary;

  const SalesSummaryWidget({
    Key? key,
    required this.totalSales,
    required this.totalProducts,
    required this.totalAmount,
    required this.totalCost,
    required this.totalProfit,
    this.openingTime,
    this.closingTime,
    this.onExportSummary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profitMargin = totalAmount > 0 ? (totalProfit / totalAmount) * 100 : 0.0;
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Günlük Satış Özeti',
                  style: AppTextStyles.heading2,
                ),
                if (onExportSummary != null)
                  IconButton(
                    onPressed: onExportSummary,
                    icon: const Icon(Icons.file_download),
                    tooltip: 'Özeti Dışa Aktar',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Time Information
            if (openingTime != null || closingTime != null) ...[
              _buildTimeInfo(),
              const SizedBox(height: 16),
            ],
            
            // Summary Grid
            _buildSummaryGrid(),
            
            const SizedBox(height: 16),
            
            // Profit Information
            _buildProfitInfo(profitMargin),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (openingTime != null)
                  Text(
                    'Açılış: ${DateFormat('HH:mm').format(openingTime!)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                if (closingTime != null)
                  Text(
                    'Kapanış: ${DateFormat('HH:mm').format(closingTime!)}',
                    style: AppTextStyles.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Toplam Satış',
            value: totalSales.toString(),
            icon: Icons.shopping_cart,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            title: 'Satılan Ürün',
            value: totalProducts.toString(),
            icon: Icons.inventory,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitInfo(double profitMargin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: totalProfit >= 0 
              ? [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)]
              : [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: totalProfit >= 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                totalProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                color: totalProfit >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Finansal Özet',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildAmountInfo(
                  label: 'Toplam Gelir',
                  amount: totalAmount,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAmountInfo(
                  label: 'Toplam Maliyet',
                  amount: totalCost,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildAmountInfo(
                  label: 'Net Kar',
                  amount: totalProfit,
                  color: totalProfit >= 0 ? Colors.green : Colors.red,
                  isProfit: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kar Marjı',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${profitMargin.toStringAsFixed(1)}%',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: totalProfit >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInfo({
    required String label,
    required double amount,
    required Color color,
    bool isProfit = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            '${isProfit && amount >= 0 ? '+' : ''}${NumberFormat.currency(
              locale: 'tr_TR',
              symbol: '₺',
              decimalDigits: 2,
            ).format(amount)}',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} 