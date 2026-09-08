import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/triaje_controller.dart';
import '../../models/triaje_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/urgency_badge.dart';

const _kUidPlaceholder = 'uid-placeholder';

class TriajeHistorialView extends StatefulWidget {
  const TriajeHistorialView({super.key});

  @override
  State<TriajeHistorialView> createState() => _TriajeHistorialViewState();
}

class _TriajeHistorialViewState extends State<TriajeHistorialView> {
  final _controller = TriajeController();

  @override
  void initState() {
    super.initState();
    _controller.cargarHistorial(_kUidPlaceholder);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de triajes')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.cargandoHistorial) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (_controller.historial.isEmpty) {
            return _EstadoVacio(
              onNuevoTriaje: () =>
                  AppRoutes.push(context, AppRoutes.triajeSintomas),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _controller.cargarHistorial(_kUidPlaceholder),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              itemCount: _controller.historial.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _TriajeTile(triaje: _controller.historial[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRoutes.push(context, AppRoutes.triajeSintomas),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo triaje'),
      ),
    );
  }
}

// ── Tile individual ───────────────────────────────────────────────────────────

class _TriajeTile extends StatelessWidget {
  const _TriajeTile({required this.triaje});
  final TriajeModel triaje;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hoy = DateTime.now();
    final mismaFecha = triaje.fecha.year == hoy.year &&
        triaje.fecha.month == hoy.month &&
        triaje.fecha.day == hoy.day;
    final fechaStr = mismaFecha
        ? DateFormat('HH:mm', 'es').format(triaje.fecha)
        : DateFormat('d MMM yyyy', 'es').format(triaje.fecha);

    final sintomasStr = triaje.sintomas.take(3).join(', ') +
        (triaje.sintomas.length > 3 ? '...' : '');

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: triaje.nivelUrgencia.backgroundColor,
          borderRadius: AppRadius.mdBr,
        ),
        child: Icon(
          triaje.nivelUrgencia.icon,
          color: triaje.nivelUrgencia.color,
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              sintomasStr,
              style: textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          UrgencyBadge(triaje.nivelUrgencia, size: BadgeSize.small),
        ],
      ),
      subtitle: Text(
        '${triaje.intensidad.label} · ${triaje.duracionSintomas}',
        style: textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
        maxLines: 1,
      ),
      trailing: Text(
        fechaStr,
        style: textTheme.labelSmall
            ?.copyWith(color: AppColors.textDisabled),
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.onNuevoTriaje});
  final VoidCallback onNuevoTriaje;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined,
                size: 72, color: AppColors.surfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin triajes guardados',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Los triajes no se guardan automáticamente. '
              'Toca "Guardar este resultado" al finalizar un triaje '
              'para que aparezca aquí.',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onNuevoTriaje,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Hacer un triaje'),
            ),
          ],
        ),
      ),
    );
  }
}
