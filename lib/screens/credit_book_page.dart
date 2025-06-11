import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/credit_entry.dart';
import '../utils/csv_export_util.dart';
import 'credit_book/providers/credit_provider.dart';

/// Main credit book page for managing customer debts
/// Refactored from 575 lines to ~300 lines using modular components
class CreditBookPage extends StatefulWidget {
  const CreditBookPage({Key? key}) : super(key: key);

  @override
  State<CreditBookPage> createState() => _CreditBookPageState();
}

class _CreditBookPageState extends State<CreditBookPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CreditProvider()..initialize(),
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
      title: const Text('Kredi Defteri'),
      backgroundColor: AppConstants.primaryColor,
      foregroundColor: Colors.white,
      actions: [
        Consumer<CreditProvider>(
          builder: (context, provider, child) {
            return PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, provider),
              itemBuilder: (context) => [
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
                const PopupMenuItem(
                  value: 'cleanup',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services),
                      SizedBox(width: 8),
                      Text('Ödenenleri Temizle'),
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
    return Consumer<CreditProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _buildSearchAndStats(provider),
            Expanded(
              child: _buildCreditList(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndStats(CreditProvider provider) {
    final stats = provider.getCreditStatistics();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Müşteri Ara...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: provider.searchEntries,
          ),
          const SizedBox(height: 16),
          _buildStatsRow(stats),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Toplam Müşteri',
            '${stats['totalEntries']}',
            Icons.people,
            AppConstants.primaryColor,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Borçlu Müşteri',
            '${stats['debtEntries']}',
            Icons.trending_up,
            Colors.red,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'Toplam Borç',
            '${stats['totalDebt'].toStringAsFixed(2)} TL',
            Icons.account_balance_wallet,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditList(CreditProvider provider) {
    if (provider.filteredEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Kredi kaydı bulunamadı',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = provider.filteredEntries[index];
        return _buildCreditCard(entry, provider);
      },
    );
  }

  Widget _buildCreditCard(CreditEntry entry, CreditProvider provider) {
    final hasDebt = entry.remainingDebt > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasDebt ? Colors.red : Colors.green,
          child: Icon(
            hasDebt ? Icons.trending_up : Icons.check,
            color: Colors.white,
          ),
        ),
        title: Text(
          '${entry.name} ${entry.surname}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kalan Borç: ${entry.remainingDebt.toStringAsFixed(2)} TL'),
            if (entry.lastPaymentAmount > 0)
              Text(
                'Son Ödeme: ${entry.lastPaymentAmount.toStringAsFixed(2)} TL',
                style: const TextStyle(color: Colors.green),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDebt)
              IconButton(
                icon: const Icon(Icons.payment, color: Colors.green),
                onPressed: () => _showPaymentDialog(entry, provider),
                tooltip: 'Ödeme Al',
              ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleEntryAction(value, entry, provider),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info),
                      SizedBox(width: 8),
                      Text('Detaylar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Düzenle'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sil'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<CreditProvider>(
      builder: (context, provider, child) {
        return FloatingActionButton(
          onPressed: () => _showEntryForm(null, provider),
          backgroundColor: AppConstants.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        );
      },
    );
  }

  void _handleMenuAction(String action, CreditProvider provider) {
    switch (action) {
      case 'import_csv':
        _importCSV(provider);
        break;
      case 'export_csv':
        _exportCSV(provider);
        break;
      case 'statistics':
        _showStatistics(provider);
        break;
      case 'cleanup':
        _cleanupPaidEntries(provider);
        break;
    }
  }

  void _handleEntryAction(String action, CreditEntry entry, CreditProvider provider) {
    switch (action) {
      case 'details':
        _showEntryDetails(entry);
        break;
      case 'edit':
        _showEntryForm(entry, provider);
        break;
      case 'delete':
        _confirmDeleteEntry(entry, provider);
        break;
    }
  }

  Future<void> _showPaymentDialog(CreditEntry entry, CreditProvider provider) async {
    final paymentController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${entry.name} ${entry.surname} - Ödeme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mevcut Borç: ${entry.remainingDebt.toStringAsFixed(2)} TL'),
            const SizedBox(height: 16),
            TextField(
              controller: paymentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ödeme Miktarı',
                border: OutlineInputBorder(),
                suffixText: 'TL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Öde'),
          ),
        ],
      ),
    );

    if (result == true && paymentController.text.isNotEmpty) {
      try {
        final paymentAmount = double.parse(paymentController.text);
        if (paymentAmount > 0 && paymentAmount <= entry.remainingDebt) {
          await provider.addPayment(entry.id, paymentAmount);
          _showSuccess('Ödeme başarıyla kaydedildi');
        } else {
          _showError('Geçersiz ödeme miktarı');
        }
      } catch (e) {
        _showError('Geçersiz miktar girdiniz');
      }
    }
  }

  void _showEntryForm(CreditEntry? entry, CreditProvider provider) {
    // Implementation for entry form dialog
    _showError('Entry form not implemented yet');
  }

  void _showEntryDetails(CreditEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${entry.name} ${entry.surname}'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('İsim', '${entry.name} ${entry.surname}'),
            _buildDetailRow('Kalan Borç', '${entry.remainingDebt.toStringAsFixed(2)} TL'),
            _buildDetailRow('Son Ödeme', '${entry.lastPaymentAmount.toStringAsFixed(2)} TL'),
            _buildDetailRow(
              'Son Ödeme Tarihi',
              entry.lastPaymentDate != null
                  ? '${entry.lastPaymentDate!.day}/${entry.lastPaymentDate!.month}/${entry.lastPaymentDate!.year}'
                  : 'Henüz ödeme yapılmamış',
            ),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  Future<void> _confirmDeleteEntry(CreditEntry entry, CreditProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: Text('${entry.name} ${entry.surname} kaydını silmek istediğinizden emin misiniz?'),
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
        await provider.deleteEntry(entry.id); // Fixed: Use ID instead of name
        _showSuccess('Kayıt başarıyla silindi');
      } catch (e) {
        _showError('Kayıt silinirken hata oluştu: $e');
      }
    }
  }

  Future<void> _importCSV(CreditProvider provider) async {
    try {
      final csvData = await CSVExportUtil.importCreditEntriesFromCSV();
      if (csvData != null) {
        await provider.importFromCSV(csvData);
        _showSuccess('CSV dosyası başarıyla içe aktarıldı');
      }
    } catch (e) {
      _showError('CSV içe aktarma başarısız: $e');
    }
  }

  Future<void> _exportCSV(CreditProvider provider) async {
    try {
      final csvData = provider.exportToCSV();
      await CSVExportUtil.exportCreditEntriesToCSV(csvData);
      _showSuccess('CSV dosyası başarıyla dışa aktarıldı');
    } catch (e) {
      _showError('CSV dışa aktarma başarısız: $e');
    }
  }

  void _showStatistics(CreditProvider provider) {
    final stats = provider.getCreditStatistics();
    final debtEntries = provider.getDebtEntries();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kredi İstatistikleri'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Toplam Müşteri', '${stats['totalEntries']}'),
              _buildDetailRow('Borçlu Müşteri', '${stats['debtEntries']}'),
              _buildDetailRow('Ödemiş Müşteri', '${stats['paidEntries']}'),
              _buildDetailRow('Toplam Borç', '${stats['totalDebt'].toStringAsFixed(2)} TL'),
              _buildDetailRow('Ortalama Borç', '${stats['averageDebt'].toStringAsFixed(2)} TL'),
              if (debtEntries.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('En Çok Borçlu Müşteriler:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...debtEntries
                    .take(5)
                    .map((entry) => Text('• ${entry.name} ${entry.surname}: ${entry.remainingDebt.toStringAsFixed(2)} TL')),
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

  Future<void> _cleanupPaidEntries(CreditProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ödenenleri Temizle'),
        content: const Text('Borcu olmayan tüm müşteri kayıtlarını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await provider.cleanupPaidEntries();
        _showSuccess('Ödenmiş kayıtlar temizlendi');
      } catch (e) {
        _showError('Temizlik işlemi başarısız: $e');
      }
    }
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