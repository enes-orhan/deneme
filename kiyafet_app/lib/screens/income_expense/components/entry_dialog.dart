import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/income_expense_entry.dart';
import '../../../utils/logger.dart';

/// Reusable dialog for adding/editing income expense entries
class EntryDialog extends StatefulWidget {
  final IncomeExpenseEntry? entry;
  final String? category;
  final String title;
  final Function(String description, double amount, DateTime date) onSave;

  const EntryDialog({
    Key? key,
    this.entry,
    this.category,
    required this.title,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.entry?.description ?? '');
    _amountController = TextEditingController(text: widget.entry?.amount.toString() ?? '');
    _selectedDate = widget.entry?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildDateSelector(),
            ],
          ),
        ),
      ),
      actions: [
        _buildCancelButton(),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Açıklama',
        hintText: 'Gider/gelir açıklaması',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.description),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Açıklama gerekli';
        }
        if (value.trim().length < 3) {
          return 'Açıklama en az 3 karakter olmalı';
        }
        return null;
      },
      textCapitalization: TextCapitalization.sentences,
      maxLines: 2,
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: 'Tutar',
        hintText: '0.00',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.monetization_on),
        suffixText: '₺',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Tutar gerekli';
        }
        
        final amount = double.tryParse(value.trim());
        if (amount == null) {
          return 'Geçerli bir tutar girin';
        }
        
        if (amount <= 0) {
          return 'Tutar sıfırdan büyük olmalı';
        }
        
        if (amount > 999999999) {
          return 'Tutar çok büyük';
        }
        
        return null;
      },
    );
  }

  Widget _buildDateSelector() {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: const Text('Tarih'),
        subtitle: Text(
          DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(_selectedDate),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _selectDate,
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
      child: const Text('İptal'),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(widget.entry != null ? 'Güncelle' : 'Kaydet'),
    );
  }

  Future<void> _selectDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        locale: const Locale('tr', 'TR'),
        helpText: 'Tarih Seçin',
        cancelText: 'İptal',
        confirmText: 'Tamam',
      );

      if (picked != null && picked != _selectedDate) {
        setState(() {
          _selectedDate = picked;
        });
      }
    } catch (e) {
      Logger.error('Date picker error', tag: 'ENTRY_DIALOG', error: e);
      if (mounted) {
        _showErrorSnackBar('Tarih seçilirken hata oluştu');
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final description = _descriptionController.text.trim();
      final amount = double.parse(_amountController.text.trim());

      await widget.onSave(description, amount, _selectedDate);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Logger.error('Save entry error', tag: 'ENTRY_DIALOG', error: e);
      if (mounted) {
        _showErrorSnackBar('Kayıt kaydedilirken hata oluştu');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Confirmation dialog for deleting entries
class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Sil'),
        ),
      ],
    );
  }

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: title,
        message: message,
        onConfirm: onConfirm,
      ),
    );
  }
} 