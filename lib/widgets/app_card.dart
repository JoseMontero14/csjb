import 'package:flutter/material.dart';
import '../utils/theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color,
    this.borderColor,
    this.elevation,
  });

  /// Card con fondo de color de marca (surfaceVariant por defecto).
  const AppCard.accent({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.elevation,
  })  : color = AppColors.primary,
        borderColor = Colors.transparent;

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: elevation ?? AppElevation.card,
      color: color ?? theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBr,
        side: BorderSide(
          color: borderColor ?? AppColors.cardBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBr,
        child: Padding(
          padding: padding ??
              const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}
