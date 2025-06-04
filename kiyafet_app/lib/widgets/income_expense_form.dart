import 'package:flutter/material.dart';
import 'package:kiyafet_app/models/income_expense_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class IncomeExpenseForm extends StatefulWidget {
  final IncomeExpenseCategory? initialCategory;
  final VoidCallback onSave;

  const IncomeExpenseForm({
    super.key,
    this.initialCategory,
    required this.onSave,
  });

  @override
  State<IncomeExpenseForm> createState() => _IncomeExpenseFormState();
}

class _IncomeExpenseFormState extends State<IncomeExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  late IncomeExpenseCategory _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? IncomeExpenseCategory.sabitGelir;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = prefs.getStringList('income_expense_entries') ?? [];
      
      final entry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'description': _descriptionController.text,
        'amount': double.parse(_amountController.text),
        'category': _selectedCategory.name,
        'type': _selectedCategory.entryType.name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      entriesJson.add(jsonEncode(entry));
      await prefs.setStringList('income_expense_entries', entriesJson);
      
      if (mounted) {
        widget.onSave();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt sırasında hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Yeni ${_selectedCategory.entryType.name} Ekle',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<IncomeExpenseCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: IncomeExpenseCategory.values
                  .where((category) => category.entryType == _selectedCategory.entryType)
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.categoryLabel),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen bir açıklama girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Tutar',
                border: OutlineInputBorder(),
                prefixText: '₺ ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen bir tutar girin';
                }
                if (double.tryParse(value) == null) {
                  return 'Geçerli bir sayı girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveEntry,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
} 