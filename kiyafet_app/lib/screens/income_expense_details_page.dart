import 'package:flutter/material.dart';
import '../models/income_expense_entry.dart';
import '../constants/app_constants.dart';
import '../services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/credit_entry.dart';
import '../models/product.dart';
import '../widgets/custom_button.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class IncomeExpenseDetailsPage extends StatefulWidget {
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
  State<IncomeExpenseDetailsPage> createState() => _IncomeExpenseDetailsPageState();
}

class _IncomeExpenseDetailsPageState extends State<IncomeExpenseDetailsPage> {
  late List<IncomeExpenseEntry> _allEntries;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  List<CreditEntry> _creditEntries = [];
  List<Product> _products = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _allEntries = widget.entries;
    _loadSpecialData();
  }

  Future<void> _loadSpecialData() async {
    setState(() { _isLoading = true; });
    
    try {
      // Özel veri tipleri için yükleme yap
      if (widget.type == EntryType.mevcut) {
        // Alacaklar (veresiye defteri)
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getStringList('credit_entries') ?? [];
        _creditEntries = data.map((e) => CreditEntry.fromMap(jsonDecode(e))).toList();
        
        // Stok (envanter)
        final productsJson = prefs.getStringList('products') ?? [];
        _products = productsJson.map((e) => Product.fromMap(jsonDecode(e))).toList();
      }
      
      // Tüm Gelir-Gider kayıtlarını yeniden yükle
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList('income_expense_entries') ?? [];
      final allEntries = entriesJson.map((e) => IncomeExpenseEntry.fromMap(jsonDecode(e))).toList();
      
      // Sadece ilgili tipe ait kayıtları filtrele
      final filteredEntries = allEntries.where((e) => e.type == widget.type.name).toList();
      
      setState(() {
        _allEntries = filteredEntries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      // Hata durumunda en azından widget ile gelen verileri göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veri yüklenirken hata oluştu: $e'))
      );
    }
  }

  List<IncomeExpenseEntry> _filterByCategory(String category) {
    return _allEntries.where((e) => e.category == category && _searchMatch(e)).toList();
  }

  bool _searchMatch(IncomeExpenseEntry e) {
    return e.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      e.category.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  double _totalForCategory(String category) {
    return _allEntries.where((e) => e.category == category).fold(0.0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    final isMevcut = widget.type == EntryType.mevcut;
    final isGelir = widget.type == EntryType.gelir;
    final isGider = widget.type == EntryType.gider;
    final isBorc = widget.type == EntryType.borc;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Ara',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() { _searchQuery = value; });
              },
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (isGelir) ...[
                  _buildBalanceCard(
                    title: 'Sabit Gelirler',
                    icon: Icons.attach_money,
                    iconColor: Colors.green,
                    category: IncomeExpenseCategory.sabitGelir,
                  ),
                  _buildBalanceCard(
                    title: 'Günlük Gelirler',
                    icon: Icons.trending_up,
                    iconColor: Colors.green.shade700,
                    category: IncomeExpenseCategory.gunlukGelir,
                  ),
                ],
                if (isGider) ...[
                  _buildBalanceCard(
                    title: 'Sabit Giderler',
                    icon: Icons.money_off,
                    iconColor: Colors.red,
                    category: IncomeExpenseCategory.sabitGider,
                  ),
                  _buildBalanceCard(
                    title: 'Günlük Giderler',
                    icon: Icons.trending_down,
                    iconColor: Colors.red.shade700,
                    category: IncomeExpenseCategory.gunlukGider,
                  ),
                ],
                if (isMevcut) ...[
                  _buildBalanceCard(
                    title: 'Eldeki Nakit',
                    icon: Icons.account_balance_wallet,
                    iconColor: Colors.blue,
                    category: IncomeExpenseCategory.nakit,
                  ),
                  _buildAlacaklarCard(),
                  _buildStokCard(),
                ],
                if (isBorc) ...[
                  _buildBalanceCard(
                    title: 'Banka Borcu',
                    icon: Icons.account_balance,
                    iconColor: Colors.orange,
                    category: IncomeExpenseCategory.bankaBorcu,
                  ),
                  _buildBalanceCard(
                    title: 'Toptancı Borcu',
                    icon: Icons.store,
                    iconColor: Colors.orange.shade700,
                    category: IncomeExpenseCategory.toptanciBorcu,
                  ),
                  _buildBalanceCard(
                    title: 'TL ile Borç',
                    icon: Icons.money,
                    iconColor: Colors.orange.shade400,
                    category: IncomeExpenseCategory.tlBorcu,
                  ),
                  _buildBalanceCard(
                    title: 'Döviz Borcu',
                    icon: Icons.euro,
                    iconColor: Colors.orange.shade300,
                    category: IncomeExpenseCategory.dovizBorcu,
                  ),
                  _buildBalanceCard(
                    title: 'Emtia Borcu',
                    icon: Icons.shopping_basket,
                    iconColor: Colors.orange.shade200,
                    category: IncomeExpenseCategory.emtiaBorcu,
                  ),
                ],
              ],
            ),
          ),
          _buildExportButton(),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required IncomeExpenseCategory category,
  }) {
    final entries = _filterByCategory(category.name);
    final total = _totalForCategory(category.name);
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
            Row(
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
                Text(
                  title, 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: iconColor
                  )
                ),
                Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${total.toStringAsFixed(2)} ₺', 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: iconColor
                    )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: Center(
                  child: Text(
                    'Kayıt bulunamadı',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else ...entries.map((entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: entry.isAutoGenerated ? Colors.grey.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.description}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      '${entry.amount.toStringAsFixed(2)} ₺',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getAmountColor(entry.type),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue.shade400, size: 20),
                      onPressed: () => _showEntryDialog(entry: entry, category: category.name),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                      onPressed: () => _deleteEntry(entry),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: Icon(Icons.add, size: 18),
                label: Text('Yeni Kayıt Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showEntryDialog(category: category.name),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAmountColor(String type) {
    switch (type) {
      case 'gelir':
        return Colors.green.shade700;
      case 'gider':
        return Colors.red.shade700;
      case 'mevcut':
        return Colors.blue.shade700;
      case 'borc':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildAlacaklarCard() {
    final total = _creditEntries.fold(0.0, (sum, e) => sum + e.remainingDebt);
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
                  child: Icon(Icons.people, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Alacaklar', 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.blue
                  )
                ),
                Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${total.toStringAsFixed(2)} ₺', 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.blue
                    )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_creditEntries.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: Center(
                  child: Text(
                    'Veresiye kaydı bulunamadı',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else ..._creditEntries.map((entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  '${entry.name} ${entry.surname}',
                  style: TextStyle(
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
                        Expanded(
                          child: _buildInfoChip(
                            icon: Icons.account_balance_wallet,
                            label: 'Kalan Borç',
                            value: '${entry.remainingDebt.toStringAsFixed(2)} ₺',
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoChip(
                            icon: Icons.payment,
                            label: 'Son Ödeme',
                            value: '${entry.lastPaymentAmount.toStringAsFixed(2)} ₺',
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildInfoChip(
                      icon: Icons.calendar_today,
                      label: 'Son Ödeme Tarihi',
                      value: '${entry.lastPaymentDate.day}.${entry.lastPaymentDate.month}.${entry.lastPaymentDate.year}',
                      color: Colors.grey.shade700,
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: Icon(Icons.add, size: 18),
                label: Text('Yeni Alacak Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {/* Buraya yeni alacak ekleme dialogu eklenebilir */},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStokCard() {
    final total = _products.fold(0.0, (sum, p) => sum + (p.finalCost * p.quantity));
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
                    color: Colors.blue.shade700
                  )
                ),
                Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${total.toStringAsFixed(2)} ₺', 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.blue.shade700
                    )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_products.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: Center(
                  child: Text(
                    'Stokta ürün yok',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else ..._products.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Toplam: ${(p.finalCost * p.quantity).toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoChip(
                            icon: Icons.format_list_numbered,
                            label: 'Adet',
                            value: '${p.quantity}',
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoChip(
                            icon: Icons.monetization_on,
                            label: 'Son Maliyet',
                            value: '${p.finalCost.toStringAsFixed(2)} ₺',
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (p.barcode != null && p.barcode!.isNotEmpty) SizedBox(height: 4),
                    if (p.barcode != null && p.barcode!.isNotEmpty)
                      _buildInfoChip(
                        icon: Icons.qr_code,
                        label: 'Barkod',
                        value: p.barcode!,
                        color: Colors.grey.shade700,
                      ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (widget.type) {
      case EntryType.gelir:
        return 'Gelir Detayları';
      case EntryType.gider:
        return 'Gider Detayları';
      case EntryType.mevcut:
        return 'Mevcut Detayları';
      case EntryType.borc:
        return 'Borç Detayları';
    }
  }

  Future<void> _showEntryDialog({IncomeExpenseEntry? entry, String? category}) async {
    final isEdit = entry != null;
    final descController = TextEditingController(text: entry?.description ?? '');
    final amountController = TextEditingController(text: entry?.amount.toString() ?? '');
    DateTime selectedDate = entry?.date ?? DateTime.now();
    final formKey = GlobalKey<FormState>();
    final usedCategory = category ?? entry?.category ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Kayıt Düzenle' : 'Yeni Kayıt Ekle'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descController,
                  decoration: InputDecoration(labelText: 'Açıklama'),
                  validator: (v) => v == null || v.isEmpty ? 'Açıklama gerekli' : null,
                ),
                TextFormField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: 'Tutar (TL)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Tutar gerekli' : null,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text('Tarih: ${DateFormat('dd.MM.yyyy').format(selectedDate)}'),
                    IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final prefs = await SharedPreferences.getInstance();
                final entriesJson = prefs.getStringList('income_expense_entries') ?? [];
                final entries = entriesJson.map((json) => IncomeExpenseEntry.fromMap(jsonDecode(json))).toList();
                if (isEdit) {
                  final idx = entries.indexWhere((e) => e.id == entry!.id);
                  if (idx != -1) {
                    entries[idx] = entry!.copyWith(
                      description: descController.text,
                      amount: double.tryParse(amountController.text) ?? 0.0,
                      date: selectedDate,
                    );
                  }
                } else {
                  final newEntry = IncomeExpenseEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: widget.type.name,
                    category: usedCategory,
                    description: descController.text,
                    amount: double.tryParse(amountController.text) ?? 0.0,
                    date: selectedDate,
                    isAutoGenerated: false,
                  );
                  entries.add(newEntry);
                }
                final updatedJson = entries.map((e) => jsonEncode(e.toMap())).toList();
                await prefs.setStringList('income_expense_entries', updatedJson);
                Navigator.pop(context);
                setState(() {
                  _allEntries = entries.where((e) => e.type == widget.type.name).toList();
                });
              }
            },
            child: Text(isEdit ? 'Kaydet' : 'Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry(IncomeExpenseEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kayıt Sil'),
        content: Text('Bu kaydı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList('income_expense_entries') ?? [];
      final entries = entriesJson.map((json) => IncomeExpenseEntry.fromMap(jsonDecode(json))).toList();
      entries.removeWhere((e) => e.id == entry.id);
      final updatedJson = entries.map((e) => jsonEncode(e.toMap())).toList();
      await prefs.setStringList('income_expense_entries', updatedJson);
      setState(() {
        _allEntries = entries.where((e) => e.type == widget.type.name).toList();
      });
    }
  }

  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CustomButton(
            text: "Excel'e Aktar",
            icon: Icons.download,
            backgroundColor: AppColors.primary,
            textColor: Colors.white,
            onPressed: _exportToExcel,
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      // Sadece seçili ayın gelir-gider hareketlerini dışa aktar
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      // Örnek veri: gelir-gider listesi
      final entries = await widget.storageService.getIncomeExpenseEntries();
      final filtered = entries.where((entry) {
        final date = entry.date;
        return date.month == month && date.year == year;
      }).toList();
      List<List<dynamic>> rows = [];
      rows.add([
        'Tarih', 'Tip', 'Açıklama', 'Tutar', 'Kategori'
      ]);
      for (final entry in filtered) {
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
      final file = File('${dir.path}/yorukler_giyim_gelir_gider_${year}_${month}.csv');
      await file.writeAsString(csv);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel dosyası kaydedildi: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dışa aktarma hatası: $e')),
      );
    }
  }
} 