import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isOutlined;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final String? semanticLabel;
  final Color? loadingIndicatorColor;
  final bool enableFeedback;
  final EdgeInsets? padding;
  final double? borderRadius;
  final double? elevation;
  final bool fullWidth;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isOutlined = false,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.semanticLabel,
    this.loadingIndicatorColor,
    this.enableFeedback = true,
    this.padding,
    this.borderRadius,
    this.elevation,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveWidth = fullWidth ? double.infinity : (width ?? AppSizes.buttonWidth);
    final effectiveBorderRadius = borderRadius ?? AppSizes.borderRadius;
    final effectiveElevation = elevation ?? (isOutlined ? 0 : 2);
    
    final buttonColor = backgroundColor ?? (isOutlined ? Colors.transparent : AppColors.primary);
    final textStyle = AppTextStyles.body.copyWith(
      color: isOutlined ? AppColors.primary : Colors.white,
      fontWeight: FontWeight.bold,
    );
    
    return Semantics(
      label: semanticLabel ?? text,
      button: true,
      enabled: onPressed != null && !isLoading,
      child: Tooltip(
        message: semanticLabel ?? text,
        child: SizedBox(
          width: effectiveWidth,
          height: height ?? AppSizes.buttonHeight,
          child: ElevatedButton(
            onPressed: isLoading ? null : () {
              if (enableFeedback) {
                HapticFeedback.lightImpact(); // Dokunsal geri bildirim
              }
              onPressed?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: textColor ?? (isOutlined ? AppColors.primary : Colors.white),
              side: isOutlined ? BorderSide(color: AppColors.primary) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(effectiveBorderRadius),
              ),
              elevation: effectiveElevation,
              padding: padding,
              disabledBackgroundColor: isOutlined ? Colors.transparent : buttonColor.withOpacity(0.6),
              disabledForegroundColor: isOutlined ? AppColors.primary.withOpacity(0.6) : Colors.white.withOpacity(0.7),
            ),
            focusNode: FocusNode(skipTraversal: isLoading),
            autofocus: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(loadingIndicatorColor ?? Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[                        
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          text,
                          style: textStyle,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}