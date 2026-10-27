import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controllers/triaje_controller.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';
import 'triaje_widgets.dart';

class TriajeSintomasView extends StatefulWidget {
  const TriajeSintomasView({super.key});

  @override
  State<TriajeSintomasView> createState() => _TriajeSintomasViewState();
}

class _TriajeSintomasViewState extends State<TriajeSintomasView> {
  // El controlador nace aquí y viaja a los pasos 2 y 3 por argumento.
  final _controller = TriajeController();
  final _otroController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _otroController.dispose();
    super.dispose();
  }

  Future<void> _siguiente() async {
    await AppRoutes.push(
      context,
      AppRoutes.triajeIntensidad,
      args: _controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Triaje informativo'),
        bottom: const TriajePasoIndicador(paso: 1),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historial de triajes',
            onPressed: () =>
                AppRoutes.push(context, AppRoutes.triajeHistorial),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ilustración médica
                      Center(
                        child: SvgPicture.asset(
                          'assets/il_triaje_empty.svg',
                          height: (MediaQuery.of(context).size.height * 0.18).clamp(90.0, 140.0),
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '¿Qué síntomas tienes?',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Selecciona todos los que apliquen.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: TriajeOpciones.sintomas.map((s) {
                          final seleccionado =
                              _controller.sintomasSeleccionados.contains(s);
                          return FilterChip(
                            label: Text(s),
                            selected: seleccionado,
                            onSelected: (_) => _controller.toggleSintoma(s),
                            selectedColor: AppColors.urgencyMediumBg,
                            checkmarkColor: AppColors.accent,
                            side: BorderSide(
                              color: seleccionado
                                  ? AppColors.accent
                                  : AppColors.surfaceVariant,
                            ),
                            labelStyle: textTheme.labelMedium?.copyWith(
                              color: seleccionado
                                  ? AppColors.accentDark
                                  : AppColors.textSecondary,
                              fontWeight: seleccionado
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.fullBr,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Otro síntoma (opcional)',
                          style: textTheme.labelMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _otroController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Describe brevemente...',
                        ),
                        onChanged: _controller.setSintomaLibre,
                      ),
                    ],
                  ),
                ),
              ),
              TriajeBarraInferior(
                child: AppButton(
                  label: 'Siguiente',
                  onPressed:
                      _controller.tieneSintomas ? _siguiente : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
