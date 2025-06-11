import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';
import '../../../widgets/custom_button.dart';

/// Widget for managing day start and end operations
class DayManagementWidget extends StatelessWidget {
  final bool dayStarted;
  final DateTime? dayStartTime;
  final VoidCallback? onStartDay;
  final VoidCallback? onEndDay;
  final bool isLoading;

  const DayManagementWidget({
    Key? key,
    required this.dayStarted,
    this.dayStartTime,
    this.onStartDay,
    this.onEndDay,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (dayStarted) {
      return _buildDayStartedWidget();
    } else {
      return _buildDayNotStartedWidget();
    }
  }

  Widget _buildDayNotStartedWidget() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Gün Henüz Başlatılmadı',
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Satış işlemlerine başlamak için günü başlatın',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            CustomButton(
              text: 'Günü Başlat',
              onPressed: isLoading ? null : onStartDay,
              isLoading: isLoading,
              icon: Icons.play_arrow,
              backgroundColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayStartedWidget() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.access_time,
                color: Colors.green,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gün Aktif',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  if (dayStartTime != null)
                    Text(
                      'Başlangıç: ${DateFormat('dd/MM/yyyy HH:mm').format(dayStartTime!)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            
            CustomButton(
              text: 'Günü Bitir',
              onPressed: isLoading ? null : onEndDay,
              isLoading: isLoading,
              icon: Icons.stop,
              backgroundColor: Colors.red,
              isCompact: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Show day end confirmation dialog
  static Future<bool> showEndDayConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Günü Bitir'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Günü bitirmek istediğinizden emin misiniz?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bu işlem:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('• Günlük satış özetini kaydedecek'),
                  Text('• Tüm satış verilerini arşivleyecek'),
                  Text('• Yeni satış işlemlerini durduracak'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Günü Bitir'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show day start confirmation dialog
  static Future<bool> showStartDayConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wb_sunny, color: Colors.green),
            const SizedBox(width: 8),
            Text('Günü Başlat'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni bir iş günü başlatmak istediğinizden emin misiniz?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bu işlem:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('• Satış işlemlerini etkinleştirecek'),
                  Text('• Günlük verileri sıfırlayacak'),
                  Text('• Başlangıç zamanını kaydedecek'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('Günü Başlat'),
          ),
        ],
      ),
    ) ?? false;
  }
} 