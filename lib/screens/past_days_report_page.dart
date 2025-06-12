import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import '../constants/app_constants.dart';
import '../models/daily_session.dart';
import '../services/database/repositories/daily_session_repository.dart';
import '../utils/logger.dart';

/// Simple page for viewing past days reports
class PastDaysReportPage extends StatefulWidget {
  const PastDaysReportPage({Key? key}) : super(key: key);

  @override
  State<PastDaysReportPage> createState() => _PastDaysReportPageState();
}

class _PastDaysReportPageState extends State<PastDaysReportPage> {
  late final DailySessionRepository _repository;
  List<DailySession> _sessions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _repository = GetIt.instance<DailySessionRepository>();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: 30));
      _sessions = await _repository.getSessionsInRange(startDate, endDate);
      // Filter only ended sessions
      _sessions = _sessions.where((session) => session.endTime != null).toList();
      
      Logger.info('Loaded ${_sessions.length} past day sessions', tag: 'PAST_DAYS_REPORT');
    } catch (e) {
      _errorMessage = 'Geçmiş günler yüklenirken hata oluştu: $e';
      Logger.error('Failed to load past days', tag: 'PAST_DAYS_REPORT', error: e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Günler'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Hata',
                style: AppTextStyles.heading2.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadSessions,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Geçmiş Gün Bulunamadı',
                style: AppTextStyles.heading2.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Son 30 günde tamamlanmış gün bulunamadı',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryHeader(),
        Expanded(child: _buildSessionsList()),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    final totalRevenue = _sessions.fold<double>(0, (sum, session) => sum + session.totalRevenue);
    final totalCost = _sessions.fold<double>(0, (sum, session) => sum + session.totalCost);
    final totalProfit = _sessions.fold<double>(0, (sum, session) => sum + session.totalProfit);
    final totalSales = _sessions.fold<int>(0, (sum, session) => sum + session.totalSales);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Dönem Özeti (${_sessions.length} Gün)',
                style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Toplam Gelir', '₺${totalRevenue.toStringAsFixed(2)}', Colors.green),
              ),
              Expanded(
                child: _buildSummaryItem('Toplam Maliyet', '₺${totalCost.toStringAsFixed(2)}', Colors.red),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Net Kar', '₺${totalProfit.toStringAsFixed(2)}', Colors.blue),
              ),
              Expanded(
                child: _buildSummaryItem('Toplam Satış', '$totalSales Adet', Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(DailySession session) {
    final date = DateTime.parse(session.date);
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);
    final startTime = session.startTime != null 
        ? DateFormat('HH:mm').format(session.startTime!) 
        : '--:--';
    final endTime = session.endTime != null 
        ? DateFormat('HH:mm').format(session.endTime!) 
        : '--:--';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('dd').format(date),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
              Text(
                DateFormat('MMM').format(date),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          formattedDate,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saat: $startTime - $endTime'),
            Text('Gelir: ₺${session.totalRevenue.toStringAsFixed(2)} | Kar: ₺${session.totalProfit.toStringAsFixed(2)}'),
            if (session.totalPaymentAmount > 0)
              Text(
                'Nakit: ₺${session.cashAmount.toStringAsFixed(0)} | Kart: ₺${session.creditCardAmount.toStringAsFixed(0)} | Pazar: ₺${session.pazarAmount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${session.totalSales}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Satış',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        onTap: () => _showSessionDetails(session),
      ),
    );
  }

  void _showSessionDetails(DailySession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gün Detayları - ${session.date}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Başlangıç', session.startTime?.toString() ?? 'Bilinmiyor'),
              _buildDetailRow('Bitiş', session.endTime?.toString() ?? 'Bilinmiyor'),
              const Divider(),
              _buildDetailRow('Toplam Gelir', '₺${session.totalRevenue.toStringAsFixed(2)}'),
              _buildDetailRow('Toplam Maliyet', '₺${session.totalCost.toStringAsFixed(2)}'),
              _buildDetailRow('Net Kar', '₺${session.totalProfit.toStringAsFixed(2)}'),
              _buildDetailRow('Toplam Satış', '${session.totalSales} adet'),
              const Divider(),
              if (session.totalPaymentAmount > 0) ...[
                Text('Ödeme Yöntemleri:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDetailRow('Nakit', '₺${session.cashAmount.toStringAsFixed(2)}'),
                _buildDetailRow('Kredi Kartı', '₺${session.creditCardAmount.toStringAsFixed(2)}'),
                _buildDetailRow('Pazar', '₺${session.pazarAmount.toStringAsFixed(2)}'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
} 