import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/receivable.dart';

class ReceivableService {
  final SharedPreferences _prefs;

  ReceivableService(this._prefs);

  Future<List<Receivable>> getReceivables() async {
    final receivablesString = _prefs.getString('receivables');
    if (receivablesString != null) {
      final List<dynamic> receivableList = jsonDecode(receivablesString);
      return receivableList.map((json) => Receivable.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> addReceivable(Receivable receivable) async {
    final receivables = await getReceivables();
    receivables.add(receivable);
    await _saveReceivables(receivables);
  }

  Future<void> updateReceivable(Receivable updatedReceivable) async {
    final receivables = await getReceivables();
    final index = receivables.indexWhere((receivable) => receivable.id == updatedReceivable.id);
    if (index != -1) {
      receivables[index] = updatedReceivable;
      await _saveReceivables(receivables);
    }
  }

  Future<void> deleteReceivable(String id) async {
    final receivables = await getReceivables();
    receivables.removeWhere((receivable) => receivable.id == id);
    await _saveReceivables(receivables);
  }

  Future<void> _saveReceivables(List<Receivable> receivables) async {
    final receivablesString = jsonEncode(receivables.map((receivable) => receivable.toJson()).toList());
    await _prefs.setString('receivables', receivablesString);
  }
}
