import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/medicacion_controller.dart';
import '../../models/recordatorio_model.dart';
import '../../utils/theme.dart';
import '../../widgets/app_card.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

class MedicacionListaView extends StatelessWidget {
  const MedicacionListaView({super.key, required this.controller});
  final MedicacionController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis medicamentos')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final recs = controller.recordatorios;

          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (recs.isEmpty) {
            return _EstadoVacio();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: recs.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _TarjetaMedicamento(
              recordatorio: recs[i],
              onEliminar: () => _confirmarEliminar(context, recs[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    RecordatorioModel rec,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar medicamento'),
        content: Text(
          '¿Eliminar "${rec.nombreCompleto}"? Se cancelarán sus recordatorios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.urgencyHigh),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await controller.eliminarRecordatorio(_uid, rec.id);
    }
  }
}

// ── Estado vacío ───────────────────────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_outlined,
              size: 72, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sin medicamentos registrados',
            style:
                textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Agrega uno desde la pantalla principal',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de medicamento registrado ─────────────────────────────────────────

class _TarjetaMedicamento extends StatelessWidget {
  const _TarjetaMedicamento({
    required this.recordatorio,
    required this.onEliminar,
  });
  final RecordatorioModel recordatorio;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rec = recordatorio;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.smBr,
            ),
            child: const Icon(Icons.medication_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.nombreCompleto, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  rec.frecuencia.label,
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                if (rec.horarios.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: rec.horarios
                        .map((h) => _ChipHora(hora: h))
                        .toList(),
                  ),
                ],
                if (rec.frecuencia == Frecuencia.segunNecesidad) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 12, color: AppColors.textDisabled),
                      const SizedBox(width: 4),
                      Text(
                        'Sin recordatorio automático',
                        style: textTheme.labelSmall
                            ?.copyWith(color: AppColors.textDisabled),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Menú de acciones
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary, size: 20),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'eliminar',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: AppColors.urgencyHigh, size: 18),
                    SizedBox(width: 8),
                    Text('Eliminar'),
                  ],
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'eliminar') onEliminar();
            },
          ),
        ],
      ),
    );
  }
}

class _ChipHora extends StatelessWidget {
  const _ChipHora({required this.hora});
  final String hora;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: AppRadius.fullBr,
      ),
      child: Text(
        hora,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
