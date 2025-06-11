import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../../models/income_expense_entry.dart';
import '../../services/storage_service.dart';
import '../../widgets/custom_button.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_constants.dart';
import 'providers/income_expense_provider.dart';
import 'components/balance_card.dart';
import 'components/entry_dialog.dart';

/// Refactored Income Expense Details Page using Provider pattern and modular components
class IncomeExpenseDetailsPage extends StatelessWidget {
  final EntryType type;
  final List<IncomeExpenseEntry> entries;
  final StorageService storageService;

  const IncomeExpenseDetailsPage({
    Key? key,
    required this.type,
    required this.entries,
    required this.storageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => IncomeExpenseProvider(storageService, type)..initialize(),
      child: _IncomeExpenseDetailsView(),
    );
  }
}

class _IncomeExpenseDetailsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IncomeExpenseProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.pageTitle),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportToExcel(context, provider),
            tooltip: 'Excel\'e Aktar',
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(context, provider),
                Expanded(
                  child: _buildBalanceCards(context, provider),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar(BuildContext context, IncomeExpenseProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Ara',
          hintText: 'Açıklama veya kategori ara...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: provider.updateSearchQuery,
      ),
    );
  }

  Widget _buildBalanceCards(BuildContext context, IncomeExpenseProvider provider) {
    switch (provider.entryType) {
      case EntryType.gelir:
        return _buildGelirCards(context, provider);
      case EntryType.gider:
        return _buildGiderCards(context, provider);
      case EntryType.mevcut:
        return _buildMevcutCards(context, provider);
      case EntryType.borc:
        return _buildBorcCards(context, provider);
    }
  }

  Widget _buildGelirCards(BuildContext context, IncomeExpenseProvider provider) {
    return ListView(
      children: [
        BalanceCard(
          title: 'Sabit Gelirler',
          icon: Icons.attach_money,
          iconColor: Colors.green,
          entries: provider.filterByCategory('sabit_gelir'),
          totalAmount: provider.totalForCategory('sabit_gelir'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'sabit_gelir',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
        BalanceCard(
          title: 'Günlük Gelirler',
          icon: Icons.trending_up,
          iconColor: Colors.green.shade700,
          entries: provider.filterByCategory('gunluk_gelir'),
          totalAmount: provider.totalForCategory('gunluk_gelir'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'gunluk_gelir',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
      ],
    );
  }

  Widget _buildGiderCards(BuildContext context, IncomeExpenseProvider provider) {
    return ListView(
      children: [
        BalanceCard(
          title: 'Sabit Giderler',
          icon: Icons.money_off,
          iconColor: Colors.red,
          entries: provider.filterByCategory('sabit_gider'),
          totalAmount: provider.totalForCategory('sabit_gider'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'sabit_gider',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
        BalanceCard(
          title: 'Günlük Giderler',
          icon: Icons.trending_down,
          iconColor: Colors.red.shade700,
          entries: provider.filterByCategory('gunluk_gider'),
          totalAmount: provider.totalForCategory('gunluk_gider'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'gunluk_gider',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
      ],
    );
  }

  Widget _buildMevcutCards(BuildContext context, IncomeExpenseProvider provider) {
    return ListView(
      children: [
        BalanceCard(
          title: 'Eldeki Nakit',
          icon: Icons.account_balance_wallet,
          iconColor: Colors.blue,
          entries: provider.filterByCategory('nakit'),
          totalAmount: provider.totalForCategory('nakit'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'nakit',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
        CreditBalanceCard(
          totalAmount: provider.totalCreditAmount,
          creditEntries: provider.creditEntries,
          onAddCredit: () => _showAddCreditDialog(context),
        ),
        _buildStockCard(provider),
      ],
    );
  }

  Widget _buildBorcCards(BuildContext context, IncomeExpenseProvider provider) {
    return ListView(
      children: [
        BalanceCard(
          title: 'Banka Borcu',
          icon: Icons.account_balance,
          iconColor: Colors.orange,
          entries: provider.filterByCategory('banka_borcu'),
          totalAmount: provider.totalForCategory('banka_borcu'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'banka_borcu',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
        BalanceCard(
          title: 'Toptancı Borcu',
          icon: Icons.store,
          iconColor: Colors.orange.shade700,
          entries: provider.filterByCategory('toptanci_borcu'),
          totalAmount: provider.totalForCategory('toptanci_borcu'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'toptanci_borcu',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
        BalanceCard(
          title: 'TL ile Borç',
          icon: Icons.money,
          iconColor: Colors.orange.shade400,
          entries: provider.filterByCategory('tl_borcu'),
          totalAmount: provider.totalForCategory('tl_borcu'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'tl_borcu',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
        BalanceCard(
          title: 'Döviz Borcu',
          icon: Icons.euro,
          iconColor: Colors.orange.shade300,
          entries: provider.filterByCategory('doviz_borcu'),
          totalAmount: provider.totalForCategory('doviz_borcu'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'doviz_borcu',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
        BalanceCard(
          title: 'Emtia Borcu',
          icon: Icons.shopping_basket,
          iconColor: Colors.orange.shade200,
          entries: provider.filterByCategory('emtia_borcu'),
          totalAmount: provider.totalForCategory('emtia_borcu'),
          onAddEntry: () => _showEntryDialog(
            context, 
            provider, 
            category: 'emtia_borcu',
          ),
          onEditEntry: (entry) => _showEntryDialog(context, provider, entry: entry),
          onDeleteEntry: (entry) => _confirmDelete(context, provider, entry),
        ),
      ],
    );
  }

  Widget _buildStockCard(IncomeExpenseProvider provider) {
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade700.withOpacity(0.2), width: 1),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Stok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    NumberFormat.currency(
                      locale: 'tr_TR',
                      symbol: '₺',
                      decimalDigits: 2,
                    ).format(provider.totalStockValue),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.products.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    'Stokta ürün yok',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Text(
                '${provider.products.length} ürün',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEntryDialog(
    BuildContext context,
    IncomeExpenseProvider provider, {
    IncomeExpenseEntry? entry,
    String? category,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => EntryDialog(
        entry: entry,
        category: category,
        title: entry != null ? 'Kayıt Düzenle' : 'Yeni Kayıt Ekle',
        onSave: (description, amount, date) async {
          if (entry != null) {
            final updatedEntry = entry.copyWith(
              description: description,
              amount: amount,
              date: date,
            );
            await provider.updateEntry(updatedEntry);
          } else {
            await provider.addEntry(
              category: category!,
              description: description,
              amount: amount,
              date: date,
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    IncomeExpenseProvider provider,
    IncomeExpenseEntry entry,
  ) async {
    await DeleteConfirmationDialog.show(
      context: context,
      title: 'Kayıt Sil',
      message: 'Bu kaydı silmek istediğinize emin misiniz?',
      onConfirm: () => provider.deleteEntry(entry.id),
    );
  }

  void _showAddCreditDialog(BuildContext context) {
    // Placeholder for add credit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alacak ekleme özelliği henüz hazır değil')),
    );
  }

  Future<void> _exportToExcel(BuildContext context, IncomeExpenseProvider provider) async {
    try {
      final now = DateTime.now();
      final entries = await provider.getEntriesForExport();

      List<List<dynamic>> rows = [
        ['Tarih', 'Tip', 'Açıklama', 'Tutar', 'Kategori']
      ];

      for (final entry in entries) {
        rows.add([
          entry.date.toIso8601String(),
          entry.type,
          entry.description,
          entry.amount,
          entry.category,
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/yorukler_giyim_${provider.entryType.name}_${now.year}_${now.month}.csv');
      await file.writeAsString(csv);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel dosyası kaydedildi: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dışa aktarma hatası: $e')),
        );
      }
    }
  }
} 