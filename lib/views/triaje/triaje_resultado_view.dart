import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../../controllers/triaje_controller.dart';
import '../../models/triaje_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/emergencia_dialog.dart';
import 'triaje_widgets.dart';

final _notificaciones = FlutterLocalNotificationsPlugin();

class TriajeResultadoView extends StatefulWidget {
  const TriajeResultadoView({super.key});

  @override
  State<TriajeResultadoView> createState() => _TriajeResultadoViewState();
}

class _TriajeResultadoViewState extends State<TriajeResultadoView> {
  late final TriajeController _controller;
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _initNotificaciones();
  }

  Future<void> _initNotificaciones() async {
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notificaciones.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

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
      await _mostrarPopupSeguimiento();
    }
  }

  Future<void> _mostrarPopupSeguimiento() async {
    if (!mounted) return;
    final fechaElegida = await showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SeguimientoDialog(),
    );
    if (fechaElegida == null || !mounted) return;
    await _controller.guardarSeguimiento(
      fechaHora: fechaElegida,
      notificaciones: _notificaciones,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notificación programada para ${_formatFecha(fechaElegida)}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatFecha(DateTime dt) {
    final hora = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hora:$min';
  }

  Future<void> _nuevaConsulta() async {
    _controller.reiniciar();
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

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) =>
              AppRoutes.pushAndRemoveAll(context, AppRoutes.dashboard),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Resultado del triaje'),
              leading: BackButton(
                onPressed: () =>
                    AppRoutes.pushAndRemoveAll(context, AppRoutes.dashboard),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Badge de urgencia compacto ───────────────────────
                        _NivelBadge(nivel: resultado.nivelUrgencia),
                        const SizedBox(height: AppSpacing.md),

                        // ── Botón emergencia (solo Alto) ─────────────────────
                        if (esAlto) ...[
                          _BotonEmergenciaTriaje(),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ── Recomendación ─────────────────────────────────────
                        _RecomendacionCard(recomendacion: resultado.recomendacion),
                        const SizedBox(height: AppSpacing.md),

                        // ── Especialidad sugerida ─────────────────────────────
                        if (resultado.especialidadSugerida != null) ...[
                          _EspecialidadFila(
                            especialidad: resultado.especialidadSugerida!,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ── Síntomas reportados ──────────────────────────────
                        _SintomasSection(resultado: resultado),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Disclaimer ────────────────────────────────────────
                        _DisclaimerTriaje(),
                      ],
                    ),
                  ),
                ),

                // ── Acciones ───────────────────────────────────────────────
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
          ),
        );
      },
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _NivelBadge extends StatelessWidget {
  const _NivelBadge({required this.nivel});
  final UrgencyLevel nivel;

  Color get _bg => switch (nivel) {
        UrgencyLevel.high => const Color(0xFFFFEBEE),
        UrgencyLevel.medium => const Color(0xFFFFF8E1),
        UrgencyLevel.low => const Color(0xFFF1F8E9),
      };

  Color get _textColor => switch (nivel) {
        UrgencyLevel.high => const Color(0xFFC62828),
        UrgencyLevel.medium => const Color(0xFFF57F17),
        UrgencyLevel.low => const Color(0xFF558B2F),
      };

  IconData get _icon => switch (nivel) {
        UrgencyLevel.high => Icons.error_outline_rounded,
        UrgencyLevel.medium => Icons.warning_amber_outlined,
        UrgencyLevel.low => Icons.check_circle_outline_rounded,
      };

  String get _descripcion => switch (nivel) {
        UrgencyLevel.high => 'Requiere atención pronto',
        UrgencyLevel.medium => 'Consulta en los próximos días',
        UrgencyLevel.low => 'Atención no urgente',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: AppRadius.lgBr,
      ),
      child: Row(
        children: [
          Icon(_icon, size: 20, color: _textColor),
          const SizedBox(width: AppSpacing.sm),
          Text(
            nivel.label,
            style: textTheme.titleSmall?.copyWith(
              color: _textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '· $_descripcion',
            style: textTheme.bodySmall?.copyWith(
              color: _textColor.withAlpha(180),
            ),
          ),
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

    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBr),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECOMENDACIÓN',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              recomendacion,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.6,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SintomasSection extends StatelessWidget {
  const _SintomasSection({required this.resultado});
  final TriajeModel resultado;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${resultado.intensidad.label} · ${resultado.duracionSintomas}',
          style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _EspecialidadFila extends StatelessWidget {
  const _EspecialidadFila({required this.especialidad});
  final String especialidad;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          Icons.medical_services_rounded,
          size: 16,
          color: AppColors.primary.withAlpha(150),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            especialidad,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          onPressed: () => AppRoutes.push(
            context,
            AppRoutes.medicos,
            args: especialidad,
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            textStyle: textTheme.labelSmall,
          ),
          child: const Text('Ver médicos →'),
        ),
      ],
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

// ── Popup de seguimiento ──────────────────────────────────────────────────────

class _SeguimientoDialog extends StatefulWidget {
  const _SeguimientoDialog();

  @override
  State<_SeguimientoDialog> createState() => _SeguimientoDialogState();
}

class _SeguimientoDialogState extends State<_SeguimientoDialog> {
  // null = opción personalizada
  int? _opcionHoras; // 1, 2, o null
  DateTime? _fechaPersonalizada;
  bool _eligiendoFecha = false;

  DateTime get _fechaSeleccionada {
    if (_opcionHoras != null) {
      return DateTime.now().add(Duration(hours: _opcionHoras!));
    }
    return _fechaPersonalizada ?? DateTime.now().add(const Duration(hours: 1));
  }

  bool get _listo =>
      _opcionHoras != null ||
      (_opcionHoras == null && _fechaPersonalizada != null);

  Future<void> _elegirFechaHora() async {
    setState(() => _eligiendoFecha = true);
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 30)),
    );
    if (!mounted || fecha == null) {
      setState(() => _eligiendoFecha = false);
      return;
    }
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ahora.add(const Duration(hours: 1))),
    );
    if (!mounted) return;
    setState(() {
      _eligiendoFecha = false;
      if (hora != null) {
        _fechaPersonalizada = DateTime(
          fecha.year, fecha.month, fecha.day, hora.hour, hora.minute,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '¿Deseas recibir seguimiento?',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Te enviaremos una notificación para saber cómo evolucionaron tus síntomas.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _OpcionChip(
            label: 'En 1 hora',
            selected: _opcionHoras == 1,
            onTap: () => setState(() {
              _opcionHoras = 1;
              _fechaPersonalizada = null;
            }),
          ),
          const SizedBox(height: 8),
          _OpcionChip(
            label: 'En 2 horas',
            selected: _opcionHoras == 2,
            onTap: () => setState(() {
              _opcionHoras = 2;
              _fechaPersonalizada = null;
            }),
          ),
          const SizedBox(height: 8),
          _OpcionChip(
            label: _fechaPersonalizada != null
                ? _formatFecha(_fechaPersonalizada!)
                : 'Elegir fecha y hora',
            selected: _opcionHoras == null && _fechaPersonalizada != null,
            loading: _eligiendoFecha,
            icon: Icons.calendar_today_outlined,
            onTap: () {
              setState(() => _opcionHoras = null);
              _elegirFechaHora();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('No, gracias'),
        ),
        FilledButton(
          onPressed: _listo
              ? () => Navigator.of(context).pop(_fechaSeleccionada)
              : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Programar'),
        ),
      ],
    );
  }

  String _formatFecha(DateTime dt) {
    final hora = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hora:$min';
  }
}

class _OpcionChip extends StatelessWidget {
  const _OpcionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.loading = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha(20)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (icon != null)
              Icon(icon, size: 16, color: color)
            else
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
                color: color,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
