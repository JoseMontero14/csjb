import 'package:flutter/material.dart';
import '../../utils/theme.dart';

/// Barra de progreso (paso 1/3, 2/3, 3/3) para el AppBar del triaje.
class TriajePasoIndicador extends StatelessWidget
    implements PreferredSizeWidget {
  const TriajePasoIndicador({required this.paso, super.key});
  final int paso;

  @override
  Size get preferredSize => const Size.fromHeight(4);

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: paso / 3,
      backgroundColor: AppColors.surfaceVariant,
      color: AppColors.primary,
      minHeight: 4,
    );
  }
}

/// Barra inferior con separador y padding para los botones de acción del triaje.
class TriajeBarraInferior extends StatelessWidget {
  const TriajeBarraInferior({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
        ),
        child: child,
      ),
    );
  }
}
