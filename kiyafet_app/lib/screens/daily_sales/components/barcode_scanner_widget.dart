import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../constants/app_constants.dart';

/// Reusable barcode scanner widget
class BarcodeScannerWidget extends StatelessWidget {
  final Function(String) onBarcodeDetected;
  final VoidCallback? onCancel;

  const BarcodeScannerWidget({
    Key? key,
    required this.onBarcodeDetected,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Barkod Tara',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 16),
                
                // Scanner Area
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          onBarcodeDetected(barcode.rawValue!);
                          Navigator.pop(context);
                          break;
                        }
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Barkodu kameranın merkezine hizalayın',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onCancel?.call();
                      },
                      child: Text(AppStrings.cancel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show barcode scanner dialog
  static Future<void> show(
    BuildContext context, {
    required Function(String) onBarcodeDetected,
    VoidCallback? onCancel,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (context) => BarcodeScannerWidget(
        onBarcodeDetected: onBarcodeDetected,
        onCancel: onCancel,
      ),
    );
  }
} 