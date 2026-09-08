import 'package:flutter/material.dart';
import '../../controllers/triaje_controller.dart';
import '../../models/triaje_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';
import 'triaje_widgets.dart';

const _kUidPlaceholder = 'uid-placeholder';

class TriajeIntensidadView extends StatefulWidget {
  const TriajeIntensidadView({super.key});

  @override
  State<TriajeIntensidadView> createState() => _TriajeIntensidadViewState();
}

class _TriajeIntensidadViewState extends State<TriajeIntensidadView> {
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

  Future<void> _verResultado() async {
    await _controller.generarResultado(_kUidPlaceholder);
    if (!mounted) return;
    if (_controller.listo) {
      await AppRoutes.push(
        context,
        AppRoutes.triajeResultado,
        args: _controller,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text('Triaje informativo'),
                bottom: const TriajePasoIndicador(paso: 2),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('¿Qué tan intensos son los síntomas?',
                              style: textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Selecciona el nivel que mejor los describe.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ...IntensidadSintomas.values.map((intensidad) {
                            final seleccionada =
                                _controller.intensidad == intensidad;
                            return _OpcionCard(
                              titulo: intensidad.label,
                              subtitulo: _descripcionIntensidad(intensidad),
                              icono: _iconoIntensidad(intensidad),
                              seleccionada: seleccionada,
                              color: _colorIntensidad(intensidad),
                              onTap: () =>
                                  _controller.setIntensidad(intensidad),
                            );
                          }),
                          const SizedBox(height: AppSpacing.lg),
                          Text('¿Hace cuánto tiempo tienes estos síntomas?',
                              style: textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.md),
                          ...TriajeOpciones.duraciones.map((dur) {
                            final seleccionada =
                                _controller.duracion == dur;
                            return _OpcionCard(
                              titulo: dur,
                              seleccionada: seleccionada,
                              color: AppColors.primary,
                              onTap: () => _controller.setDuracion(dur),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  if (_controller.errorMensaje != null)
                    _ErrorBanner(mensaje: _controller.errorMensaje!),
                  TriajeBarraInferior(
                    child: AppButton(
                      label: 'Ver resultado',
                      onPressed: _controller.paso2Completo && !_controller.generando
                          ? _verResultado
                          : null,
                      icon: const Icon(Icons.science_rounded),
                    ),
                  ),
                ],
              ),
            ),
            if (_controller.generando) const _LoadingOverlay(),
          ],
        );
      },
    );
  }

  String _descripcionIntensidad(IntensidadSintomas i) => switch (i) {
        IntensidadSintomas.leve =>
          'Molestia leve, puedes hacer actividades normales',
        IntensidadSintomas.moderada =>
          'Malestar notable, limita algunas actividades',
        IntensidadSintomas.intensa =>
          'Síntomas fuertes, dificultan las actividades diarias',
      };

  IconData _iconoIntensidad(IntensidadSintomas i) => switch (i) {
        IntensidadSintomas.leve => Icons.sentiment_satisfied_alt_rounded,
        IntensidadSintomas.moderada => Icons.sentiment_neutral_rounded,
        IntensidadSintomas.intensa => Icons.sentiment_very_dissatisfied_rounded,
      };

  Color _colorIntensidad(IntensidadSintomas i) => switch (i) {
        IntensidadSintomas.leve => AppColors.urgencyLow,
        IntensidadSintomas.moderada => AppColors.urgencyMedium,
        IntensidadSintomas.intensa => AppColors.urgencyHigh,
      };
}

class _OpcionCard extends StatelessWidget {
  const _OpcionCard({
    required this.titulo,
    required this.seleccionada,
    required this.color,
    required this.onTap,
    this.subtitulo,
    this.icono,
  });

  final String titulo;
  final String? subtitulo;
  final IconData? icono;
  final bool seleccionada;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdBr,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: seleccionada
                ? color.withAlpha(20)
                : AppColors.surface,
            borderRadius: AppRadius.mdBr,
            border: Border.all(
              color: seleccionada ? color : AppColors.surfaceVariant,
              width: seleccionada ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icono != null) ...[
                Icon(icono, color: seleccionada ? color : AppColors.textDisabled,
                    size: 22),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: textTheme.bodyMedium?.copyWith(
                        color: seleccionada ? color : AppColors.textPrimary,
                        fontWeight: seleccionada
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (seleccionada)
                Icon(Icons.check_circle_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.background.withAlpha(200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text('Analizando síntomas...',
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
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
