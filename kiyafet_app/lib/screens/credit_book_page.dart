import 'package:flutter/material.dart';
// import 'dart:convert'; // Removed
import 'dart:io';
import 'dart:math';
// import 'package:shared_preferences/shared_preferences.dart'; // Removed
import '../services/database_helper.dart'; // Added
import '../models/credit_entry.dart';
import '../constants/app_constants.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';

class CreditBookPage extends StatefulWidget {
  const CreditBookPage({Key? key}) : super(key: key);

  @override
  State<CreditBookPage> createState() => _CreditBookPageState();
}

class _CreditBookPageState extends State<CreditBookPage> {
  List<CreditEntry> _entries = [];
  List<CreditEntry> _filteredEntries = [];
  String _searchQuery = '';
  // static const String _prefsKey = 'credit_entries'; // Removed

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      _entries.clear(); // Clear existing entries
      final List<Map<String, dynamic>> maps = await DatabaseHelper.instance.readAllCreditEntries();
      final List<CreditEntry> loadedEntries = maps.map((map) => CreditEntry.fromMap(map)).toList();

      // Sort entries, for example by name then surname
      // This ensures a consistent order if your DB doesn't guarantee it or if you want a specific app order.
      loadedEntries.sort((a, b) {
        int nameComparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (nameComparison != 0) {
          return nameComparison;
        }
        return a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
      });

      setState(() {
        _entries = loadedEntries;
        _filteredEntries = List.from(_entries); // Initialize filtered list
      });
    } catch (e) {
      // Log the error or show a user-friendly message
      print('Error loading credit entries: $e');
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veresiye kayıtları yüklenirken bir hata oluştu: $e')),
        );
      }
    }
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
        final name = '${entry.name} ${entry.surname}'.toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  // Future<void> _saveEntries() async { // Removed
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
                // En az gerekli alan sayısı kontrolü
                if (row.length < 5) {
                  print('Satır $i yeterli alana sahip değil. Beklenen: >=5, Bulunan: ${row.length}');
                  continue; // Bu satırı atla ama diğer satırları işlemeye devam et
                }
                
                // Temizlenecek para ve tarih değerleri için yardımcı fonksiyon
                String cleanMoneyValue(dynamic value) {
                  if (value == null) return '0';
                  String strValue = value.toString().trim();
                  return strValue
                    .replaceAll('TL', '')
                    .replaceAll('₺', '')
                    .replaceAll(',', '.') // Türkçe formatını destekle
                    .replaceAll(' ', '')
                    .trim();
                }
                
                // Değerleri al ve temizle
                final name = row[0]?.toString()?.trim() ?? '';
                final surname = row[1]?.toString()?.trim() ?? '';
                final remainingDebtStr = cleanMoneyValue(row[2]);
                final lastPaymentAmountStr = cleanMoneyValue(row[3]);
                final lastPaymentDateStr = row[4]?.toString()?.trim() ?? '';
                
                // Kritik alanların boş olup olmadığını kontrol et
                if (name.isEmpty) {
                  print('Satır $i: İsim boş, atlanıyor');
                  continue;
                }
                
                // Sayısal değerleri dönüştür
                double remainingDebt = 0.0;
                double lastPaymentAmount = 0.0;
                
                try {
                  remainingDebt = double.parse(remainingDebtStr);
                } catch (e) {
                  print('Kalan borç değeri dönüştürülemedi: $remainingDebtStr, varsayılan 0 kullanılıyor');
                }
                
                try {
                  lastPaymentAmount = double.parse(lastPaymentAmountStr);
                } catch (e) {
                  print('Son ödeme miktarı dönüştürülemedi: $lastPaymentAmountStr, varsayılan 0 kullanılıyor');
                }
                
                // Tarihi işle
                DateTime lastPaymentDate = _parseDate(lastPaymentDateStr);
                
                final entry = CreditEntry(
                  name: name,
                  surname: surname,
                  remainingDebt: remainingDebt,
                  lastPaymentAmount: lastPaymentAmount,
                  lastPaymentDate: lastPaymentDate,
                );
                
                print('Oluşturulan kayıt: ${entry.name} ${entry.surname} - Borç: ${entry.remainingDebt} TL');
                newEntries.add(entry);
              } catch (e) {
                print('CSV satırı işlenemedi: $e');
              }
            }
            
            if (newEntries.isNotEmpty) {
              try {
                for (final parsedEntry in newEntries) {
                  // The CreditEntry model now generates an ID if one isn't provided.
                  // If CSV might contain IDs, ensure CreditEntry.fromMap handles it or
                  // create CreditEntry instance here explicitly managing ID.
                  // Assuming CreditEntry.fromMap correctly assigns/generates ID.
                  await DatabaseHelper.instance.createCreditEntry(parsedEntry.toMap());
                }
                await _loadEntries(); // Refresh list from DB
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${newEntries.length} veresiye kaydı başarıyla veritabanına aktarıldı.')),
                );
              } catch (e) {
                print('Error importing CSV entries to database: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Kayıtlar veritabanına aktarılırken hata: $e')),
                );
              }
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

      final csvData = [
        ['Adı', 'Soyadı', 'Kalan Borç (TL)', 'Son Ödeme Miktarı (TL)', 'Son Ödeme Tarihi'],
        ..._entries.map((e) => [
          e.name,
          e.surname,
          e.remainingDebt.toString(),
          e.lastPaymentAmount.toString(),
          '${e.lastPaymentDate.day}.${e.lastPaymentDate.month}.${e.lastPaymentDate.year}',
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

  Future<void> _showAddOrEditEntryDialog({CreditEntry? entry, int? index}) async {
    final nameController = TextEditingController(text: entry?.name ?? '');
    final surnameController = TextEditingController(text: entry?.surname ?? '');
    final remainingDebtController = TextEditingController(text: entry?.remainingDebt.toString() ?? '');
    final lastPaymentAmountController = TextEditingController(text: entry?.lastPaymentAmount.toString() ?? '');
    DateTime? selectedDate = entry?.lastPaymentDate;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(entry == null ? 'Yeni Veresiye Kaydı' : 'Veresiye Kaydını Düzenle'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Adı'),
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  TextFormField(
                    controller: surnameController,
                    decoration: const InputDecoration(labelText: 'Soyadı'),
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  TextFormField(
                    controller: remainingDebtController,
                    decoration: const InputDecoration(labelText: 'Kalan Borç Miktarı (TL)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  TextFormField(
                    controller: lastPaymentAmountController,
                    decoration: const InputDecoration(labelText: 'Son Ödeme Miktarı (TL)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(selectedDate == null
                            ? 'Son Ödeme Tarihi seçilmedi'
                            : 'Son Ödeme Tarihi: \n${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year}'),
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
                ],
              ),
            ),
          ),
          actions: [
            if (entry != null) // Show Delete button only in edit mode
              TextButton(
                onPressed: () async {
                  try {
                    // Optional: Show a confirmation dialog before deleting
                    // bool confirmDelete = await showDialog(...);
                    // if (confirmDelete == true) {
                    await DatabaseHelper.instance.deleteCreditEntry(entry.id);
                    Navigator.pop(context); // Close the edit dialog
                    await _loadEntries(); // Refresh the list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veresiye kaydı silindi.')),
                    );
                    // }
                  } catch (e) {
                    print('Error deleting credit entry: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Silme işlemi sırasında hata: $e')),
                    );
                  }
                },
                child: const Text('Sil', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false && selectedDate != null) {
                  try {
                    if (entry == null) { // Adding new entry
                      final newCreditEntry = CreditEntry(
                        // id will be auto-generated by the model
                        name: nameController.text,
                        surname: surnameController.text,
                        remainingDebt: double.tryParse(remainingDebtController.text) ?? 0.0,
                        lastPaymentAmount: double.tryParse(lastPaymentAmountController.text) ?? 0.0,
                        lastPaymentDate: selectedDate!,
                      );
                      await DatabaseHelper.instance.createCreditEntry(newCreditEntry.toMap());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yeni veresiye kaydı eklendi!')),
                      );
                    } else { // Editing existing entry
                      final updatedCreditEntry = CreditEntry(
                        id: entry.id, // Preserve existing ID
                        name: nameController.text,
                        surname: surnameController.text,
                        remainingDebt: double.tryParse(remainingDebtController.text) ?? 0.0,
                        lastPaymentAmount: double.tryParse(lastPaymentAmountController.text) ?? 0.0,
                        lastPaymentDate: selectedDate!,
                      );
                      await DatabaseHelper.instance.updateCreditEntry(updatedCreditEntry.toMap());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veresiye kaydı güncellendi!')),
                      );
                    }
                    await _loadEntries(); // Refresh the list from DB
                    Navigator.pop(context); // Close dialog
                  } catch (e) {
                    print('Error saving credit entry: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Kayıt işlemi sırasında hata: $e')),
                    );
                  }
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
                          title: Row(
                            children: [
                              Text(
                                '${entry.name} ${entry.surname}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (_searchQuery.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Eşleşme',
                                    style: TextStyle(
                                      fontSize: 10,
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
                              _buildInfoRow('Kalan Borç', '${entry.remainingDebt.toStringAsFixed(2)} ₺', Colors.red),
                              _buildInfoRow('Son Ödeme', '${entry.lastPaymentAmount.toStringAsFixed(2)} ₺', Colors.green),
                              _buildInfoRow(
                                'Son Ödeme Tarihi',
                                '${entry.lastPaymentDate.day}.${entry.lastPaymentDate.month}.${entry.lastPaymentDate.year}',
                                Colors.blue,
                              ),
                            ],
                          ),
                          onTap: () => _showAddOrEditEntryDialog(entry: entry, index: _entries.indexOf(entry)),
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