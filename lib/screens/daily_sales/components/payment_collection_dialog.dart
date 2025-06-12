import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/app_constants.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/custom_button.dart';

/// Dialog for collecting payment method amounts at end of day
class PaymentCollectionDialog extends StatefulWidget {
  final double totalRevenue;
  final VoidCallback? onCancel;
  final Function(Map<String, double>)? onConfirm;

  const PaymentCollectionDialog({
    Key? key,
    required this.totalRevenue,
    this.onCancel,
    this.onConfirm,
  }) : super(key: key);

  @override
  State<PaymentCollectionDialog> createState() => _PaymentCollectionDialogState();

  /// Show payment collection dialog
  static Future<Map<String, double>?> show(
    BuildContext context, {
    required double totalRevenue,
  }) async {
    return await showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentCollectionDialog(
        totalRevenue: totalRevenue,
      ),
    );
  }
}

class _PaymentCollectionDialogState extends State<PaymentCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cashController = TextEditingController();
  final _creditCardController = TextEditingController();
  final _pazarController = TextEditingController();

  double get cashAmount => double.tryParse(_cashController.text) ?? 0.0;
  double get creditCardAmount => double.tryParse(_creditCardController.text) ?? 0.0;
  double get pazarAmount => double.tryParse(_pazarController.text) ?? 0.0;
  double get totalPayments => cashAmount + creditCardAmount + pazarAmount;
  double get difference => totalPayments - widget.totalRevenue;

  @override
  void initState() {
    super.initState();
    // Initialize with total revenue for convenience
    _cashController.text = widget.totalRevenue.toStringAsFixed(2);
    
    // Listen to changes to update UI
    _cashController.addListener(_onAmountChanged);
    _creditCardController.addListener(_onAmountChanged);
    _pazarController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _cashController.dispose();
    _creditCardController.dispose();
    _pazarController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {}); // Trigger UI update for balance calculation
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildRevenueInfo(),
              const SizedBox(height: 24),
              _buildPaymentFields(),
              const SizedBox(height: 16),
              _buildBalanceInfo(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            Icons.payments,
            size: 30,
            color: Colors.green[600],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Gün Sonu Ödeme Toplama',
          style: AppTextStyles.heading2.copyWith(
            color: Colors.green[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Bugün toplanan paraların dağılımını girin',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRevenueInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Toplam Gelir:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          Text(
            '₺${widget.totalRevenue.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFields() {
    return Column(
      children: [
        // Cash
        CustomTextField(
          controller: _cashController,
          label: 'Nakit',
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          prefixIcon: Icons.money,
          suffixIcon: Text('₺'),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final amount = double.tryParse(value);
              if (amount == null || amount < 0) {
                return 'Geçerli bir tutar girin';
              }
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Credit Card
        CustomTextField(
          controller: _creditCardController,
          label: 'Kredi Kartı',
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          prefixIcon: Icons.credit_card,
          suffixIcon: Text('₺'),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final amount = double.tryParse(value);
              if (amount == null || amount < 0) {
                return 'Geçerli bir tutar girin';
              }
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Pazar
        CustomTextField(
          controller: _pazarController,
          label: 'Pazar',
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          prefixIcon: Icons.store,
          suffixIcon: Text('₺'),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final amount = double.tryParse(value);
              if (amount == null || amount < 0) {
                return 'Geçerli bir tutar girin';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBalanceInfo() {
    final isBalanced = difference.abs() < 0.01;
    final color = isBalanced 
        ? Colors.green 
        : difference > 0 
            ? Colors.orange 
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toplam Ödeme:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color[700],
                ),
              ),
              Text(
                '₺${totalPayments.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fark:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color[700],
                ),
              ),
              Text(
                '₺${difference.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color[700],
                ),
              ),
            ],
          ),
          if (!isBalanced)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                difference > 0 
                    ? 'Ödeme toplam gelirden fazla' 
                    : 'Ödeme toplam gelirden az',
                style: TextStyle(
                  fontSize: 12,
                  color: color[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('İptal'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: CustomButton(
            text: 'Günü Bitir',
            onPressed: _onConfirm,
            backgroundColor: Colors.green,
            icon: Icons.check,
          ),
        ),
      ],
    );
  }

  void _onConfirm() {
    if (_formKey.currentState!.validate()) {
      final paymentData = {
        'cash': cashAmount,
        'creditCard': creditCardAmount,
        'pazar': pazarAmount,
        'total': totalPayments,
        'difference': difference,
      };

      Navigator.of(context).pop(paymentData);
      widget.onConfirm?.call(paymentData);
    }
  }
} 