import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
// import 'package:shared_preferences/shared_preferences.dart'; // Removed
import '../models/receivable.dart'; // Changed from credit_entry.dart
import '../constants/app_constants.dart';
import '../services/receivable_service.dart'; // Added
import '../services/service_locator.dart'; // Added
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart'; // Added for ID generation
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';

class CreditBookPage extends StatefulWidget {
  const CreditBookPage({Key? key}) : super(key: key);

  @override
  State<CreditBookPage> createState() => _CreditBookPageState();
}

class _CreditBookPageState extends State<CreditBookPage> {
  late ReceivableService _receivableService; // Added
  List<Receivable> _entries = []; // Changed from CreditEntry
  List<Receivable> _filteredEntries = []; // Changed from CreditEntry
  String _searchQuery = '';
  // static const String _prefsKey = 'credit_entries'; // Removed

  @override
  void initState() {
    super.initState();
    _receivableService = getIt<ReceivableService>(); // Added
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    // final prefs = await SharedPreferences.getInstance(); // Removed
    // final data = prefs.getStringList(_prefsKey) ?? []; // Removed
    final loadedEntries = await _receivableService.getReceivables(); // Changed
    setState(() {
      // _entries = data.map((e) => Receivable.fromMap(jsonDecode(e))).toList(); // Changed model
      _entries = loadedEntries;
      _filteredEntries = List.from(_entries);
    });
  }

  void _filterEntries(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _filteredEntries = List.from(_entries);
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _filteredEntries = _entries.where((entry) {
        // final name = '${entry.name} ${entry.surname}'.toLowerCase(); // Changed for Receivable model
        final name = entry.customerName.toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  // _saveEntries is not needed directly, service handles saving.
  // Future<void> _saveEntries() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final data = _entries.map((e) => jsonEncode(e.toMap())).toList();
  //   await prefs.setStringList(_prefsKey, data);
  // }

  Future<bool> _requestPermissions() async {
    // Android 13 ve üzeri için farklı izinleri iste
    if (await Permission.storage.status.isDenied ||
        await Permission.manageExternalStorage.status.isDenied) {
      
      if (await Permission.storage.request().isGranted) {
        print("Storage permission granted");
        return true;
      }
      
      // API 33+ için
      final mediaPermissions = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
      
      print("Media permissions: $mediaPermissions");
      
      // Son çare olarak manageExternalStorage iste
      try {
        await Permission.manageExternalStorage.request();
        print("ManageExternalStorage: ${await Permission.manageExternalStorage.status}");
      } catch (e) {
        print("Error requesting manageExternalStorage: $e");
      }
    }
    
    // İzin durumunu kontrol et
    bool hasStoragePermission = await Permission.storage.isGranted;
    bool hasManagePermission = await Permission.manageExternalStorage.isGranted;
    bool hasPhotosPermission = await Permission.photos.isGranted;
    
    print("Permissions: storage=$hasStoragePermission, manage=$hasManagePermission, photos=$hasPhotosPermission");
    
    return hasStoragePermission || hasManagePermission || hasPhotosPermission;
  }

  Future<void> _importCSV() async {
    try {
      // Önce izinleri kontrol et
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya erişim izni verilmedi. Lütfen ayarlardan izin verin.')),
        );
        return;
      }
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          print('Seçilen dosya yolu: ${file.path}');
          final input = File(file.path!).readAsStringSync();
          print('Dosya içeriği: ${input.substring(0, min(100, input.length))}...'); // İlk 100 karakteri göster
          
          // CSV ayırıcı olarak hem virgül hem de noktalı virgül deneyeceğiz
          List<List<dynamic>> rows = [];
          
          try {
            // Önce noktalı virgül (;) ile deneyelim
            if (input.contains(';')) {
              rows = const CsvToListConverter(fieldDelimiter: ';').convert(input);
              print('Noktalı virgül ayırıcı ile CSV dönüştürüldü. Satır sayısı: ${rows.length}');
            } else {
              // Yoksa normal virgül (,) ile deneyelim
              rows = const CsvToListConverter().convert(input);
              print('Virgül ayırıcı ile CSV dönüştürüldü. Satır sayısı: ${rows.length}');
            }
          } catch (e) {
            print('CSV dönüştürme hatası: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('CSV dosyası dönüştürülürken bir hata oluştu: $e')),
            );
            return;
          }
          
          print('CSV satır sayısı: ${rows.length}');
          
          if (rows.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV dosyası boş görünüyor')),
            );
            return;
          }
          
          if (rows.length > 1) { // Başlık satırı + en az bir veri satırı
            final newEntries = <CreditEntry>[];
            
            // İlk satır başlık satırı, onu atla
            for (var i = 1; i < rows.length; i++) {
              final row = rows[i];
              print('Satır $i: $row');
              
              try {
                // CSV structure for Receivable: customerName, amount, date, description, isPaid
                // Adı Soyadı (customerName), Kalan Borç (amount), Son Ödeme Tarihi (date), Açıklama (description), Ödendi mi (isPaid)
                if (row.length < 3) { // customerName, amount, date are minimal
                  print('Satır $i yeterli alana sahip değil. Beklenen: >=3, Bulunan: ${row.length}');
                  continue;
                }
                
                // Temizlenecek para ve tarih değerleri için yardımcı fonksiyon
                String cleanMoneyValue(dynamic value) {
                  if (value == null) return '0';
                  return value.toString().trim().replaceAll('TL', '').replaceAll('₺', '').replaceAll(',', '.').replaceAll(' ', '');
                }

                final customerName = row[0]?.toString().trim() ?? '';
                final amountStr = cleanMoneyValue(row[1]);
                final dateStr = row[2]?.toString().trim() ?? '';
                final description = row.length > 3 ? row[3]?.toString().trim() : null;
                final isPaidStr = row.length > 4 ? row[4]?.toString().trim().toLowerCase() : 'false';
                
                if (customerName.isEmpty) {
                  print('Satır $i: Müşteri adı boş, atlanıyor');
                  continue;
                }
                
                double amount = 0.0;
                try {
                  amount = double.parse(amountStr);
                } catch (e) {
                  print('Tutar değeri dönüştürülemedi: $amountStr, varsayılan 0 kullanılıyor');
                }
                
                DateTime date = _parseDate(dateStr);
                bool isPaid = isPaidStr == 'true' || isPaidStr == 'evet';
                
                final entry = Receivable(
                  id: const Uuid().v4(), // Generate new ID for imported items
                  customerName: customerName,
                  amount: amount,
                  date: date,
                  description: description,
                  isPaid: isPaid,
                );
                
                print('Oluşturulan kayıt: ${entry.customerName} - Tutar: ${entry.amount} TL');
                newEntries.add(entry);
              } catch (e) {
                print('CSV satırı işlenemedi: $e');
              }
            }
            
            if (newEntries.isNotEmpty) {
              for (var entry in newEntries) {
                await _receivableService.addReceivable(entry);
              }
              _loadEntries(); // Reload all entries from service
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${newEntries.length} veresiye kaydı içe aktarıldı')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV dosyasında geçerli veri bulunamadı. Lütfen format ve içeriği kontrol edin.')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV dosyası boş veya geçersiz format')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dosya yolu alınamadı')),
          );
        }
      }
    } catch (e) {
      print('CSV yükleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV yükleme hatası: $e')),
      );
    }
  }

  Future<void> _exportCSV() async {
    try {
      // Önce izinleri kontrol et
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya erişim izni verilmedi. Lütfen ayarlardan izin verin.')),
        );
        return;
      }
      
      if (_entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dışa aktarılacak kayıt bulunamadı')),
        );
        return;
      }

      // CSV structure for Receivable: customerName, amount, date, description, isPaid
      final csvData = [
        ['Müşteri Adı', 'Tutar (TL)', 'Tarih', 'Açıklama', 'Ödendi mi?'],
        ..._entries.map((e) => [
          e.customerName,
          e.amount.toStringAsFixed(2),
          '${e.date.day}.${e.date.month}.${e.date.year}',
          e.description ?? '',
          e.isPaid ? 'Evet' : 'Hayır',
        ]),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'CSV Dosyasını Kaydet',
        fileName: 'veresiye_defteri_${DateTime.now().toString().split(' ')[0]}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(csvString);
        print('CSV dosyası kaydedildi: $result');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veresiye kayıtları başarıyla dışa aktarıldı')),
        );
      }
    } catch (e) {
      print('CSV dışa aktarma hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV dışa aktarma hatası: $e')),
      );
    }
  }

  DateTime _parseDate(String value) {
    try {
      final parts = value.split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _showAddOrEditEntryDialog({Receivable? entry}) async { // Changed CreditEntry to Receivable
    final customerNameController = TextEditingController(text: entry?.customerName ?? '');
    final amountController = TextEditingController(text: entry?.amount.toString() ?? '');
    final descriptionController = TextEditingController(text: entry?.description ?? '');
    DateTime? selectedDate = entry?.date ?? DateTime.now();
    bool isPaid = entry?.isPaid ?? false;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(entry == null ? 'Yeni Alacak Kaydı' : 'Alacak Kaydını Düzenle'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: customerNameController,
                    decoration: const InputDecoration(labelText: 'Müşteri Adı Soyadı'),
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Tutar (TL)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Açıklama (Opsiyonel)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(selectedDate == null
                            ? 'Tarih seçilmedi'
                            : 'Tarih: ${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Ödendi mi?'),
                    value: isPaid,
                    onChanged: (bool value) {
                      setStateDialog(() {
                        isPaid = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false && selectedDate != null) {
                  final newReceivable = Receivable(
                    id: entry?.id ?? const Uuid().v4(), // Use existing ID or generate new
                    customerName: customerNameController.text,
                    amount: double.tryParse(amountController.text) ?? 0.0,
                    date: selectedDate!,
                    description: descriptionController.text.isEmpty ? null : descriptionController.text,
                    isPaid: isPaid,
                  );

                  if (entry == null) {
                    await _receivableService.addReceivable(newReceivable);
                  } else {
                    await _receivableService.updateReceivable(newReceivable);
                  }
                  _loadEntries(); // Reload entries from service
                  Navigator.pop(context);
                }
              },
              child: Text(entry == null ? 'Ekle' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veresiye Defteri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importCSV,
            tooltip: 'CSV Yükle',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportCSV,
            tooltip: 'CSV Dışa Aktar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'İsim veya Soyisim Ara',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onChanged: _filterEntries,
            ),
          ),
          
          // Liste veya boş mesaj
          Expanded(
            child: _filteredEntries.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                        ? 'Henüz veresiye kaydı yok.'
                        : 'Arama sonucu bulunamadı.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _filteredEntries[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            entry.customerName,
                            style: TextStyle(fontWeight: FontWeight.bold, color: entry.isPaid ? Colors.green : Colors.red),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              _buildInfoRow('Tutar', '${entry.amount.toStringAsFixed(2)} ₺', entry.isPaid ? Colors.green : Colors.red),
                              _buildInfoRow(
                                'Tarih',
                                '${entry.date.day}.${entry.date.month}.${entry.date.year}',
                                Colors.blueGrey,
                              ),
                              if (entry.description != null && entry.description!.isNotEmpty)
                                _buildInfoRow('Açıklama', entry.description!, Colors.black54),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.grey.shade600),
                            onPressed: () async {
                              // Confirmation dialog before deleting
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Alacağı Sil'),
                                    content: Text('${entry.customerName} adlı müşterinin alacağını silmek istediğinizden emin misiniz?'),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('İptal'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Sil'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (confirm == true) {
                                await _receivableService.deleteReceivable(entry.id);
                                _loadEntries();
                              }
                            },
                          ),
                          onTap: () => _showAddOrEditEntryDialog(entry: entry),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditEntryDialog(),
        child: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        tooltip: 'Yeni Veresiye Kaydı',
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 