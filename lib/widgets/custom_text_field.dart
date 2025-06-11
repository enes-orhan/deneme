import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final dynamic prefixIcon; // IconData veya Widget
  final dynamic suffixIcon; // IconData veya Widget
  final VoidCallback? onTap;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final String? semanticLabel;
  final Iterable<String>? autofillHints;
  final String? tooltip;
  final bool enabled;
  final bool required;
  final String? helperText;
  final TextAlign textAlign;
  final bool autovalidate;
  final Color? fillColor;
  final EdgeInsets? contentPadding;
  final InputBorder? border;
  final double? borderRadius;
  final bool showLabel;

  const CustomTextField({
    Key? key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.semanticLabel,
    this.autofillHints,
    this.tooltip,
    this.enabled = true,
    this.required = false,
    this.helperText,
    this.textAlign = TextAlign.start,
    this.autovalidate = false,
    this.fillColor,
    this.contentPadding,
    this.border,
    this.borderRadius,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildTextField(context);
  }

  Widget? getIcon(dynamic icon) {
    if (icon == null) return null;
    if (icon is IconData) {
      return Icon(icon, color: enabled ? AppColors.primary : AppColors.textSecondary.withOpacity(0.5));
    } else if (icon is Widget) {
      return icon;
    }
    return null;
  }
  
  // TextField oluşturma metodu
  Widget _buildTextField(BuildContext context) {
    // Erişilebilirlik için gerekli etiketler
    final effectiveSemanticsLabel = semanticLabel ?? label;
    final requiredText = required ? ' (zorunlu alan)' : '';
    final fullSemanticsLabel = '$effectiveSemanticsLabel$requiredText';
    
    // Border radius değeri
    final effectiveBorderRadius = borderRadius ?? AppSizes.borderRadius;
    final effectiveContentPadding = contentPadding ?? const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    );
    
    return Semantics(
      label: fullSemanticsLabel,
      textField: true,
      enabled: enabled && !readOnly,
      readOnly: readOnly,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[  
            Row(
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: enabled ? AppColors.textSecondary : AppColors.textSecondary.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (required)
                  Text(
                    ' *',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Tooltip(
            message: tooltip ?? label,
            child: TextFormField(
              controller: controller,
              validator: validator,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              obscureText: obscureText,
              readOnly: readOnly,
              maxLines: maxLines,
              minLines: minLines,
              onChanged: onChanged,
              focusNode: focusNode,
              textInputAction: textInputAction,
              onFieldSubmitted: onSubmitted,
              onTap: onTap,
              autofillHints: autofillHints,
              enabled: enabled,
              textAlign: textAlign,
              autovalidateMode: autovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
              style: AppTextStyles.body.copyWith(
                color: enabled ? null : AppColors.textSecondary.withOpacity(0.6),
              ),
              decoration: InputDecoration(
                hintText: hint,
                helperText: helperText,
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                prefixIcon: getIcon(prefixIcon),
                suffixIcon: getIcon(suffixIcon),
                filled: true,
                fillColor: enabled 
                    ? (fillColor ?? AppColors.surface)
                    : AppColors.textSecondary.withOpacity(0.1),
                border: border ?? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                ),
                enabledBorder: border ?? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                ),
                focusedBorder: border ?? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                errorBorder: border ?? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  borderSide: BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: border ?? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  borderSide: BorderSide(color: AppColors.error),
                ),
                disabledBorder: border ?? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.1)),
                ),
                contentPadding: effectiveContentPadding,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 