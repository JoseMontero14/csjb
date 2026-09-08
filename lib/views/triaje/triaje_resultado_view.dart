import 'package:flutter/material.dart';
import '../../controllers/triaje_controller.dart';
import '../../models/triaje_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/emergencia_dialog.dart';
import '../../widgets/urgency_badge.dart';
import 'triaje_widgets.dart';

class TriajeResultadoView extends StatefulWidget {
  const TriajeResultadoView({super.key});

  @override
  State<TriajeResultadoView> createState() => _TriajeResultadoViewState();
}

class _TriajeResultadoViewState extends State<TriajeResultadoView> {
  late final TriajeController _controller;
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _controller =
          ModalRoute.of(context)!.settings.arguments as TriajeController;
      _inicializado = true;
    }
  }

  Future<void> _guardar() async {
    await _controller.guardarResultado();
    if (!mounted) return;
    if (_controller.yaGuardado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resultado guardado en tu historial.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _nuevaConsulta() async {
    _controller.reiniciar();
    // Elimina todo el stack del triaje y vuelve al paso 1 limpio.
    await AppRoutes.pushAndRemoveAll(
      context,
      AppRoutes.triajeSintomas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final resultado = _controller.resultado;
        if (resultado == null) {
          // No debería ocurrir, pero si ocurre mostramos un fallback limpio.
          return Scaffold(
            appBar: AppBar(title: const Text('Resultado')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.urgencyHigh, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('No hay resultado disponible.',
                      style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Volver al inicio',
                    onPressed: () =>
                        AppRoutes.pushAndRemoveAll(context, AppRoutes.triajeSintomas),
                  ),
                ],
              ),
            ),
          );
        }

        final esAlto = resultado.nivelUrgencia == UrgencyLevel.high;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Resultado del triaje'),
            leading: const BackButton(),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Nivel de urgencia ────────────────────────────────
                      _NivelCard(resultado: resultado),
                      const SizedBox(height: AppSpacing.md),

                      // ── Botón de emergencia contextual (solo nivel Alto) ─
                      if (esAlto) ...[
                        _BotonEmergenciaTriaje(),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // ── Recomendación ────────────────────────────────────
                      _RecomendacionCard(recomendacion: resultado.recomendacion),
                      const SizedBox(height: AppSpacing.md),

                      // ── Especialidad sugerida ─────────────────────────────
                      if (resultado.especialidadSugerida != null)
                        _EspecialidadCard(
                          especialidad: resultado.especialidadSugerida!,
                        ),
                      if (resultado.especialidadSugerida != null)
                        const SizedBox(height: AppSpacing.md),

                      // ── Síntomas reportados ──────────────────────────────
                      _SintomasCard(resultado: resultado),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Disclaimer ───────────────────────────────────────
                      _DisclaimerTriaje(),
                    ],
                  ),
                ),
              ),

              // ── Acciones ─────────────────────────────────────────────────
              if (_controller.errorMensaje != null)
                _ErrorBanner(mensaje: _controller.errorMensaje!),
              _AccionesBar(
                guardando: _controller.guardando,
                yaGuardado: _controller.yaGuardado,
                onGuardar: _guardar,
                onNuevaConsulta: _nuevaConsulta,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _NivelCard extends StatelessWidget {
  const _NivelCard({required this.resultado});
  final TriajeModel resultado;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nivel = resultado.nivelUrgencia;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: nivel.backgroundColor,
        borderRadius: AppRadius.lgBr,
        border: Border.all(color: nivel.color.withAlpha(80)),
      ),
      child: Column(
        children: [
          Icon(nivel.icon, color: nivel.color, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nivel de urgencia',
            style: textTheme.labelMedium
                ?.copyWith(color: nivel.color.withAlpha(180)),
          ),
          const SizedBox(height: AppSpacing.xs),
          UrgencyBadge(nivel, size: BadgeSize.large),
        ],
      ),
    );
  }
}

class _RecomendacionCard extends StatelessWidget {
  const _RecomendacionCard({required this.recomendacion});
  final String recomendacion;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text('Recomendación', style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(recomendacion,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textPrimary, height: 1.5)),
        ],
      ),
    );
  }
}

class _SintomasCard extends StatelessWidget {
  const _SintomasCard({required this.resultado});
  final TriajeModel resultado;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Síntomas reportados', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${resultado.intensidad.label} · ${resultado.duracionSintomas}',
            style: textTheme.labelSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: resultado.sintomas
                .map((s) => Chip(
                      label: Text(s),
                      labelStyle: textTheme.labelSmall
                          ?.copyWith(color: AppColors.textSecondary),
                      backgroundColor: AppColors.surfaceVariant,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: 0),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EspecialidadCard extends StatelessWidget {
  const _EspecialidadCard({required this.especialidad});
  final String especialidad;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBr,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: AppRadius.smBr,
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Especialidad sugerida',
                    style: textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(especialidad,
                    style: textTheme.titleSmall
                        ?.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => AppRoutes.push(
              context,
              AppRoutes.medicos,
              args: especialidad,
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              textStyle: textTheme.labelSmall,
            ),
            child: const Text('Ver médicos'),
          ),
        ],
      ),
    );
  }
}

class _BotonEmergenciaTriaje extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => mostrarDialogoEmergencia(context),
        icon: const Icon(Icons.emergency_rounded),
        label: const Text('Ver números de emergencia'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.urgencyHigh,
          side: const BorderSide(color: AppColors.urgencyHigh, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        ),
      ),
    );
  }
}

class _DisclaimerTriaje extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded,
            color: AppColors.textDisabled, size: 14),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Este triaje es informativo y no reemplaza una evaluación '
            'médica presencial. Ante cualquier duda, consulta a tu médico.',
            style: textTheme.labelSmall
                ?.copyWith(color: AppColors.textDisabled),
          ),
        ),
      ],
    );
  }
}

class _AccionesBar extends StatelessWidget {
  const _AccionesBar({
    required this.guardando,
    required this.yaGuardado,
    required this.onGuardar,
    required this.onNuevaConsulta,
  });

  final bool guardando;
  final bool yaGuardado;
  final VoidCallback onGuardar;
  final VoidCallback onNuevaConsulta;

  @override
  Widget build(BuildContext context) {
    return TriajeBarraInferior(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: yaGuardado ? 'Resultado guardado' : 'Guardar este resultado',
            onPressed: (guardando || yaGuardado) ? null : onGuardar,
            loading: guardando,
            icon: Icon(yaGuardado
                ? Icons.check_circle_rounded
                : Icons.save_alt_rounded),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onNuevaConsulta,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Nueva consulta de triaje'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: AppColors.urgencyHighBg,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.urgencyHigh, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.urgencyHigh),
            ),
          ),
        ],
      ),
    );
  }
}
