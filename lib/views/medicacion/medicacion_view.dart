import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../controllers/medicacion_controller.dart';
import '../../models/recordatorio_model.dart';
import '../../models/toma_model.dart';
import '../../utils/theme.dart';
import '../../widgets/app_card.dart';
import 'medicacion_wizard_view.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

class MedicacionView extends StatefulWidget {
  const MedicacionView({super.key});

  @override
  State<MedicacionView> createState() => _MedicacionViewState();
}

class _MedicacionViewState extends State<MedicacionView> {
  final _controller = MedicacionController();

  @override
  void initState() {
    super.initState();
    _controller.iniciarStream(_uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _abrirWizard([RecordatorioModel? existente]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MedicacionWizardView(
          controller: _controller,
          recordatorioExistente: existente,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hoy = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medicación'),
            Text(
              hoy,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _CuerpoHoy(
          controller: _controller,
          onEditar: _abrirWizard,
          onEliminar: _confirmarEliminar,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirWizard(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        tooltip: 'Agregar medicamento',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _confirmarEliminar(RecordatorioModel rec) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar medicamento'),
        content: Text(
          '¿Eliminar "${rec.nombreCompleto}"?\nSe cancelarán sus recordatorios programados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.urgencyHigh),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _controller.eliminarRecordatorio(_uid, rec.id);
    }
  }
}

// ── Cuerpo principal ──────────────────────────────────────────────────────────

class _CuerpoHoy extends StatelessWidget {
  const _CuerpoHoy({
    required this.controller,
    required this.onEditar,
    required this.onEliminar,
  });
  final MedicacionController controller;
  final void Function(RecordatorioModel) onEditar;
  final Future<void> Function(RecordatorioModel) onEliminar;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.status == MedicacionStatus.error) {
      return _EstadoError(
        mensaje: controller.errorMessage ?? 'No se pudieron cargar los medicamentos.',
        onReintentar: controller.reintentar,
      );
    }

    final agrupadas = controller.tomasAgrupadas;

    if (agrupadas.isEmpty) {
      return _EstadoVacio();
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _ResumenHoy(controller: controller),
        const SizedBox(height: AppSpacing.lg),
        ...agrupadas.entries.map((entry) {
          final recId = entry.key;
          final tomas = entry.value;
          final rec = controller.recordatorioPorId(recId);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _CardMedicamento(
              recId: recId,
              recordatorio: rec,
              tomas: tomas,
              onMarcar: (item, v) => controller.marcarToma(item, v),
              onEditar: rec != null ? () => onEditar(rec) : null,
              onEliminar: rec != null ? () => onEliminar(rec) : null,
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

// ── Estado de error ───────────────────────────────────────────────────────────

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFDEAEA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 36, color: AppColors.urgencyHigh),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No se pudo cargar',
              style: textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              mensaje,
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: SvgPicture.asset(
                'assets/il_medicacion_empty.svg',
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin medicamentos para hoy',
              style: textTheme.titleSmall
                  ?.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Toca + para agregar tu primer medicamento y activar recordatorios',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Resumen circular ──────────────────────────────────────────────────────────

class _ResumenHoy extends StatelessWidget {
  const _ResumenHoy({required this.controller});
  final MedicacionController controller;

  Color _colorProgreso(int pct) {
    if (pct >= 80) return AppColors.urgencyLow;
    if (pct >= 50) return AppColors.accent;
    return AppColors.urgencyHigh;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = controller.totalHoy;
    final tomadas = controller.tomadasHoy;
    final pct = total == 0 ? 0 : (tomadas / total * 100).round();
    final color = total == 0 ? AppColors.textDisabled : _colorProgreso(pct);

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: total == 0 ? 0 : tomadas / total,
                  strokeWidth: 8,
                  backgroundColor: AppColors.divider,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '$pct%',
                    style: textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tomadas de $total tomas completadas',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  pct == 100
                      ? '¡Todo al día por hoy!'
                      : pct >= 50
                          ? 'Vas bien, sigue así'
                          : 'Recuerda tomar tus medicamentos',
                  style: textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card por medicamento ──────────────────────────────────────────────────────

class _CardMedicamento extends StatefulWidget {
  const _CardMedicamento({
    required this.recId,
    required this.recordatorio,
    required this.tomas,
    required this.onMarcar,
    this.onEditar,
    this.onEliminar,
  });
  final String recId;
  final RecordatorioModel? recordatorio;
  final List<TomaConRecordatorio> tomas;
  final void Function(TomaConRecordatorio, bool) onMarcar;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  @override
  State<_CardMedicamento> createState() => _CardMedicamentoState();
}

class _CardMedicamentoState extends State<_CardMedicamento> {
  bool _expandida = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tomas = widget.tomas;
    final tomadasCount = tomas.where((t) => t.toma.tomado).length;
    final todas = tomadasCount == tomas.length;
    final rec = widget.recordatorio;

    final nombre = rec?.medicamento ?? tomas.first.medicamento;
    final presentacion = rec?.presentacion ?? tomas.first.presentacion;
    final frecuenciaLabel = rec?.frecuencia.label ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ─────────────────────────────────────────────────────
          Row(
            children: [
              // Icono + info
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _expandida = !_expandida),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: todas
                              ? AppColors.urgencyLowBg
                              : const Color(0xFFEDE5FF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          todas
                              ? Icons.check_circle_rounded
                              : Icons.medication_rounded,
                          color: todas
                              ? AppColors.urgencyLow
                              : AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: textTheme.titleSmall?.copyWith(
                                color: todas
                                    ? AppColors.textDisabled
                                    : AppColors.textPrimary,
                                decoration: todas
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (presentacion.isNotEmpty || frecuenciaLabel.isNotEmpty)
                              Text(
                                [presentacion, frecuenciaLabel]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Contador
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: todas
                      ? AppColors.urgencyLowBg
                      : AppColors.surfaceVariant,
                  borderRadius: AppRadius.fullBr,
                ),
                child: Text(
                  '$tomadasCount/${tomas.length}',
                  style: textTheme.labelSmall?.copyWith(
                    color: todas
                        ? AppColors.urgencyLow
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Menú ⋮
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textSecondary, size: 20),
                itemBuilder: (_) => [
                  if (widget.onEditar != null)
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.textSecondary),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                  if (widget.onEliminar != null)
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.urgencyHigh),
                          SizedBox(width: 8),
                          Text('Eliminar',
                              style:
                                  TextStyle(color: AppColors.urgencyHigh)),
                        ],
                      ),
                    ),
                ],
                onSelected: (v) {
                  if (v == 'editar') widget.onEditar?.call();
                  if (v == 'eliminar') widget.onEliminar?.call();
                },
              ),
            ],
          ),

          // ── Tomas (expandibles) ────────────────────────────────────────────
          if (_expandida) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            ...tomas.map((item) => _FilaToma(
                  item: item,
                  onChanged: (v) => widget.onMarcar(item, v),
                )),
          ],
        ],
      ),
    );
  }
}

// ── Fila de toma individual ───────────────────────────────────────────────────

class _FilaToma extends StatelessWidget {
  const _FilaToma({required this.item, required this.onChanged});
  final TomaConRecordatorio item;
  final void Function(bool) onChanged;

  bool _esAtrasada() {
    if (item.toma.tomado) return false;
    final parts = item.toma.hora.split(':');
    if (parts.length < 2) return false;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final ahora = TimeOfDay.now();
    return ahora.hour > h || (ahora.hour == h && ahora.minute > m + 10);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tomado = item.toma.tomado;
    final atrasada = _esAtrasada();

    final Color horaColor;
    final Color horaBg;
    final Color estadoColor;
    final String estadoLabel;

    if (tomado) {
      horaColor = AppColors.urgencyLow;
      horaBg = AppColors.urgencyLowBg;
      estadoColor = AppColors.urgencyLow;
      estadoLabel = 'Tomado';
    } else if (atrasada) {
      horaColor = AppColors.accent;
      horaBg = const Color(0xFFFFF3E0);
      estadoColor = AppColors.accent;
      estadoLabel = 'Atrasado';
    } else {
      horaColor = AppColors.textSecondary;
      horaBg = AppColors.surfaceVariant;
      estadoColor = AppColors.textSecondary;
      estadoLabel = 'Pendiente';
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          // Pill de hora
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: horaBg,
              borderRadius: AppRadius.fullBr,
            ),
            child: Text(
              item.toma.hora,
              style: textTheme.labelMedium?.copyWith(
                color: horaColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Text(
              estadoLabel,
              style: textTheme.bodySmall?.copyWith(color: estadoColor),
            ),
          ),

          // Checkbox
          Checkbox(
            value: tomado,
            onChanged: (v) => onChanged(v ?? false),
          ),
        ],
      ),
    );
  }
}
