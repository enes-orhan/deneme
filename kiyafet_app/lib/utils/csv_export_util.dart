import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/credit_entry.dart';
import '../models/income_expense_entry.dart';
import 'logger.dart';

/// Utility class for CSV export and import operations
class CsvExportUtil {
  static final CsvExportUtil instance = CsvExportUtil._init();
  
  CsvExportUtil._init();

  /// Export products to CSV
  Future<String> exportProductsToCsv(List<Product> products) async {
    try {
      final csvData = <List<dynamic>>[];
      
      // Add headers
      csvData.add([
        'ID',
        'Name',
        'Brand',
        'Model', 
        'Color',
        'Size',
        'Quantity',
        'Region',
        'Barcode',
        'Unit Cost',
        'VAT',
        'Expense Ratio',
        'Final Cost',
        'Average Profit Margin',
        'Recommended Price',
        'Purchase Price',
        'Selling Price',
        'Category',
        'Description',
        'Created At',
        'Updated At'
      ]);

             // Add product data
      for (final product in products) {
        csvData.add([
          product.id,
          product.name,
          product.brand,
          product.model,
          product.color,
          product.size,
          product.quantity,
          product.region,
          product.barcode ?? '',
          product.unitCost,
          product.vat,
          product.expenseRatio,
          product.finalCost,
          product.averageProfitMargin,
          product.recommendedPrice,
          product.purchasePrice,
          product.sellingPrice,
          product.category,
          '', // description placeholder
          '', // createdAt placeholder
          '', // updatedAt placeholder
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final filePath = await _saveToFile(csvString, 'products_export.csv');
      
      Logger.info('Products exported to CSV: $filePath', tag: 'CSV_EXPORT');
      return filePath;
    } catch (e) {
      Logger.error('Failed to export products to CSV', tag: 'CSV_EXPORT', error: e);
      throw CsvExportException('Failed to export products: $e');
    }
  }

  /// Export sales to CSV
  Future<String> exportSalesToCsv(List<Sale> sales) async {
    try {
      final csvData = <List<dynamic>>[];
      
      // Add headers
      csvData.add([
        'Sale ID',
        'Date',
        'Total Amount',
        'Total Cost',
        'Product ID',
        'Product Name',
        'Quantity',
        'Price',
        'Cost'
      ]);

      // Add sales data (each sale item as a separate row)
      for (final sale in sales) {
        for (final item in sale.items) {
          csvData.add([
            sale.id,
            sale.date.toIso8601String(),
            sale.totalAmount,
            sale.totalCost,
            item.productId,
            item.productName,
            item.quantity,
            item.price,
            item.cost,
          ]);
        }
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final filePath = await _saveToFile(csvString, 'sales_export.csv');
      
      Logger.info('Sales exported to CSV: $filePath', tag: 'CSV_EXPORT');
      return filePath;
    } catch (e) {
      Logger.error('Failed to export sales to CSV', tag: 'CSV_EXPORT', error: e);
      throw CsvExportException('Failed to export sales: $e');
    }
  }

  /// Export credit entries to CSV
  Future<String> exportCreditEntriesToCsv(List<CreditEntry> entries) async {
    try {
      final csvData = <List<dynamic>>[];
      
      // Add headers
      csvData.add([
        'ID',
        'Customer Name',
        'Product Name',
        'Quantity',
        'Unit Price',
        'Total Amount',
        'Remaining Amount',
        'Date',
        'Notes'
      ]);

      // Add credit entries data
      for (final entry in entries) {
        csvData.add([
          entry.id,
          entry.customerName,
          entry.productName,
          entry.quantity,
          entry.unitPrice,
          entry.totalAmount,
          entry.remainingAmount,
          entry.date.toIso8601String(),
          entry.notes ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final filePath = await _saveToFile(csvString, 'credit_entries_export.csv');
      
      Logger.info('Credit entries exported to CSV: $filePath', tag: 'CSV_EXPORT');
      return filePath;
    } catch (e) {
      Logger.error('Failed to export credit entries to CSV', tag: 'CSV_EXPORT', error: e);
      throw CsvExportException('Failed to export credit entries: $e');
    }
  }

  /// Export income/expense entries to CSV
  Future<String> exportIncomeExpenseEntriesToCsv(List<IncomeExpenseEntry> entries) async {
    try {
      final csvData = <List<dynamic>>[];
      
      // Add headers
      csvData.add([
        'ID',
        'Type',
        'Category',
        'Amount',
        'Description',
        'Date',
        'Created At'
      ]);

      // Add income/expense entries data
      for (final entry in entries) {
        csvData.add([
          entry.id,
          entry.type.name,
          entry.category,
          entry.amount,
          entry.description,
          entry.date.toIso8601String(),
          entry.createdAt.toIso8601String(),
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final filePath = await _saveToFile(csvString, 'income_expense_export.csv');
      
      Logger.info('Income/Expense entries exported to CSV: $filePath', tag: 'CSV_EXPORT');
      return filePath;
    } catch (e) {
      Logger.error('Failed to export income/expense entries to CSV', tag: 'CSV_EXPORT', error: e);
      throw CsvExportException('Failed to export income/expense entries: $e');
    }
  }

  /// Import products from CSV
  Future<List<Product>> importProductsFromCsv(String csvContent) async {
    try {
      final csvData = const CsvToListConverter().convert(csvContent);
      final products = <Product>[];
      
      if (csvData.isEmpty) {
        throw CsvExportException('CSV file is empty');
      }

      // Skip header row (assuming first row is headers)
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        
        if (row.length < 17) {
          Logger.warn('Skipping incomplete row $i', tag: 'CSV_IMPORT');
          continue;
        }

        try {
          final product = Product(
            id: row[0]?.toString() ?? '',
            name: row[1]?.toString() ?? '',
            brand: row[2]?.toString() ?? '',
            model: row[3]?.toString() ?? '',
            color: row[4]?.toString() ?? '',
            size: row[5]?.toString() ?? '',
            quantity: _parseIntSafely(row[6]),
            region: row[7]?.toString(),
            barcode: row[8]?.toString(),
            unitCost: _parseDoubleSafely(row[9]),
            vat: _parseDoubleSafely(row[10]),
            expenseRatio: _parseDoubleSafely(row[11]),
            finalCost: _parseDoubleSafely(row[12]),
            averageProfitMargin: _parseDoubleSafely(row[13]),
            recommendedPrice: _parseDoubleSafely(row[14]),
            purchasePrice: _parseDoubleSafely(row[15]) ?? 0,
            sellingPrice: _parseDoubleSafely(row[16]) ?? 0,
            category: row.length > 17 ? row[17]?.toString() : null,
            description: row.length > 18 ? row[18]?.toString() : null,
          );
          
          products.add(product);
        } catch (e) {
          Logger.warn('Failed to parse product from row $i: $e', tag: 'CSV_IMPORT');
        }
      }

      Logger.info('Imported ${products.length} products from CSV', tag: 'CSV_IMPORT');
      return products;
    } catch (e) {
      Logger.error('Failed to import products from CSV', tag: 'CSV_IMPORT', error: e);
      throw CsvExportException('Failed to import products: $e');
    }
  }

  /// Save CSV content to file
  Future<String> _saveToFile(String csvContent, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);
      return file.path;
    } catch (e) {
      Logger.error('Failed to save CSV file', tag: 'CSV_EXPORT', error: e);
      throw CsvExportException('Failed to save file: $e');
    }
  }

  /// Safely parse integer from dynamic value
  int _parseIntSafely(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  /// Safely parse double from dynamic value
  double? _parseDoubleSafely(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Get export directory path
  Future<String> getExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Create daily sales summary CSV
  Future<String> exportDailySalesSummary({
    required DateTime date,
    required int totalSales,
    required int totalProducts,
    required double totalAmount,
    required double totalCost,
    required double totalProfit,
    DateTime? openingTime,
    DateTime? closingTime,
  }) async {
    try {
      final csvData = <List<dynamic>>[];
      
      // Add summary headers
      csvData.add(['Daily Sales Summary']);
      csvData.add(['Date', date.toIso8601String().split('T')[0]]);
      csvData.add(['Opening Time', openingTime?.toIso8601String() ?? 'N/A']);
      csvData.add(['Closing Time', closingTime?.toIso8601String() ?? 'N/A']);
      csvData.add(['Total Sales', totalSales]);
      csvData.add(['Total Products Sold', totalProducts]);
      csvData.add(['Total Amount', totalAmount]);
      csvData.add(['Total Cost', totalCost]);
      csvData.add(['Total Profit', totalProfit]);
      csvData.add(['Profit Margin', totalAmount > 0 ? ((totalProfit / totalAmount) * 100).toStringAsFixed(2) + '%' : '0%']);

      final csvString = const ListToCsvConverter().convert(csvData);
      final fileName = 'daily_summary_${date.toIso8601String().split('T')[0]}.csv';
      final filePath = await _saveToFile(csvString, fileName);
      
      Logger.info('Daily sales summary exported: $filePath', tag: 'CSV_EXPORT');
      return filePath;
    } catch (e) {
      Logger.error('Failed to export daily sales summary', tag: 'CSV_EXPORT', error: e);
      throw CsvExportException('Failed to export daily summary: $e');
    }
  }
}

/// Custom exception for CSV operations
class CsvExportException implements Exception {
  final String message;
  
  const CsvExportException(this.message);
  
  @override
  String toString() => 'CsvExportException: $message';
} 