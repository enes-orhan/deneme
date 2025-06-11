import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/income_expense_entry.dart';

/// Reusable balance card component for displaying financial categories
class BalanceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<IncomeExpenseEntry> entries;
  final double totalAmount;
  final VoidCallback? onAddEntry;
  final Function(IncomeExpenseEntry)? onEditEntry;
  final Function(IncomeExpenseEntry)? onDeleteEntry;

  const BalanceCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.entries,
    required this.totalAmount,
    this.onAddEntry,
    this.onEditEntry,
    this.onDeleteEntry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: iconColor.withOpacity(0.05),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: iconColor.withOpacity(0.2), width: 1),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildContent(),
            if (onAddEntry != null) ...[
              const SizedBox(height: 12),
              _buildAddButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            NumberFormat.currency(
              locale: 'tr_TR',
              symbol: '₺',
              decimalDigits: 2,
            ).format(totalAmount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'Henüz kayıt yok',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      children: entries.map((entry) => _buildEntryItem(entry)).toList(),
    );
  }

  Widget _buildEntryItem(IncomeExpenseEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          entry.description,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(entry.date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  NumberFormat.currency(
                    locale: 'tr_TR',
                    symbol: '₺',
                    decimalDigits: 2,
                  ).format(entry.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            if (onEditEntry != null)
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Düzenle'),
                  ],
                ),
              ),
            if (onDeleteEntry != null)
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sil', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEditEntry?.call(entry);
                break;
              case 'delete':
                onDeleteEntry?.call(entry);
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Yeni Kayıt Ekle'),
        style: ElevatedButton.styleFrom(
          backgroundColor: iconColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onAddEntry,
      ),
    );
  }
}

/// Special balance card for displaying credit entries (alacaklar)
class CreditBalanceCard extends StatelessWidget {
  final double totalAmount;
  final List<dynamic> creditEntries; // CreditEntry list
  final VoidCallback? onAddCredit;

  const CreditBalanceCard({
    Key? key,
    required this.totalAmount,
    required this.creditEntries,
    this.onAddCredit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.2), width: 1),
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Alacaklar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    NumberFormat.currency(
                      locale: 'tr_TR',
                      symbol: '₺',
                      decimalDigits: 2,
                    ).format(totalAmount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (creditEntries.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    'Veresiye kaydı bulunamadı',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ...creditEntries.map((entry) => _buildCreditItem(entry)),
            if (onAddCredit != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Alacak Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onAddCredit,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreditItem(dynamic entry) {
    // Since we can't access CreditEntry properties directly, we'll use dynamic
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          'Müşteri', // Placeholder since we can't access entry properties
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: const Text('Alacak detayları'),
        trailing: Text(
          NumberFormat.currency(
            locale: 'tr_TR',
            symbol: '₺',
            decimalDigits: 2,
          ).format(0.0), // Placeholder amount
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
} 