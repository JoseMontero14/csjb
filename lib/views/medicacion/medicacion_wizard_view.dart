import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controllers/medicacion_controller.dart';
import '../../data/medicamentos_catalogo.dart';
import '../../models/recordatorio_model.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

class MedicacionWizardView extends StatefulWidget {
  const MedicacionWizardView({
    super.key,
    required this.controller,
    this.recordatorioExistente, // non-null → modo edición
  });
  final MedicacionController controller;
  final RecordatorioModel? recordatorioExistente;

  @override
  State<MedicacionWizardView> createState() => _MedicacionWizardViewState();
}

class _MedicacionWizardViewState extends State<MedicacionWizardView> {
  late final PageController _pageCtrl;
  int _paso = 0;

  // Datos acumulados por el wizard
  MedicamentoCatalogo? _medicamento;
  Frecuencia _frecuencia = Frecuencia.unaVez;
  List<TimeOfDay> _horarios = [const TimeOfDay(hour: 8, minute: 0)];

  bool get _esEdicion => widget.recordatorioExistente != null;

  @override
  void initState() {
    super.initState();
    final rec = widget.recordatorioExistente;
    if (rec != null) {
      // Pre-llenar con datos del recordatorio existente
      _medicamento = MedicamentoCatalogo(
        nombre: rec.medicamento,
        presentacion: rec.presentacion,
      );
      _frecuencia = rec.frecuencia;
      _horarios = rec.horarios.map((h) {
        final p = h.split(':');
        return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }).toList();
      // En edición, empezar en el paso de frecuencia (paso 1)
      _pageCtrl = PageController(initialPage: 1);
      _paso = 1;
    } else {
      _pageCtrl = PageController();
    }
  }

  void _irA(int paso) {
    setState(() => _paso = paso);
    _pageCtrl.animateToPage(
      paso,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _seleccionarMedicamento(MedicamentoCatalogo med) {
    setState(() => _medicamento = med);
    _irA(1);
  }

  void _seleccionarFrecuencia(Frecuencia f) {
    final horarios = _horariosDefault(f);
    setState(() {
      _frecuencia = f;
      _horarios = horarios;
    });
    // segunNecesidad salta directo a confirmación
    _irA(f == Frecuencia.segunNecesidad ? 3 : 2);
  }

  List<TimeOfDay> _horariosDefault(Frecuencia f) => switch (f) {
        Frecuencia.unaVez || Frecuencia.unaVezAlDia || Frecuencia.personalizado =>
          [const TimeOfDay(hour: 8, minute: 0)],
        Frecuencia.dosVeces || Frecuencia.cada12h => [
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 20, minute: 0),
          ],
        Frecuencia.tresVeces || Frecuencia.cada8h => [
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 14, minute: 0),
            const TimeOfDay(hour: 20, minute: 0),
          ],
        Frecuencia.segunNecesidad => [],
      };

  Future<void> _pickHora(int idx) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horarios[idx],
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      _horarios[idx] = picked;
      // Si el usuario ajusta la primera hora en frecuencias de intervalo fijo,
      // redistribuir automáticamente las demás desde esa base.
      if (idx == 0 && _horarios.length > 1) {
        final intervaloMin = switch (_frecuencia) {
          Frecuencia.cada8h || Frecuencia.tresVeces => 8 * 60,
          Frecuencia.cada12h || Frecuencia.dosVeces => 12 * 60,
          _ => null,
        };
        if (intervaloMin != null) {
          final baseMin = picked.hour * 60 + picked.minute;
          _horarios = List.generate(_horarios.length, (i) {
            final total = (baseMin + i * intervaloMin) % (24 * 60);
            return TimeOfDay(hour: total ~/ 60, minute: total % 60);
          });
        }
      }
    });
  }

  void _agregarHora() {
    setState(() {
      final ultima = _horarios.isNotEmpty
          ? _horarios.last
          : const TimeOfDay(hour: 8, minute: 0);
      final nuevoMin = (ultima.hour * 60 + ultima.minute + 60) % (24 * 60);
      _horarios.add(TimeOfDay(hour: nuevoMin ~/ 60, minute: nuevoMin % 60));
    });
  }

  void _eliminarHora(int idx) {
    if (_horarios.length <= 1) return;
    setState(() => _horarios.removeAt(idx));
  }

  String _formatHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    final med = _medicamento;
    if (med == null) return;

    final existente = widget.recordatorioExistente;
    final rec = RecordatorioModel(
      id: existente?.id ?? '',
      uid: existente?.uid ?? _uid,
      medicamento: med.nombre,
      presentacion: med.presentacion,
      dosis: existente?.dosis ?? '',
      frecuencia: _frecuencia,
      horarios: _horarios.map(_formatHora).toList(),
      fechaInicio: existente?.fechaInicio ?? DateTime.now(),
      sinFechaFin: existente?.sinFechaFin ?? true,
      fechaFin: existente?.fechaFin,
      notas: existente?.notas,
    );

    if (_esEdicion && existente != null) {
      await widget.controller.editarRecordatorio(existente.id, rec);
    } else {
      await widget.controller.agregarRecordatorio(rec);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar medicamento' : _tituloPaso(_paso)),
        leading: _paso == (_esEdicion ? 1 : 0)
            ? const CloseButton()
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _irA(_paso - 1),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _BarraProgreso(paso: _paso, total: 4),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _PasoBuscar(onSeleccionar: _seleccionarMedicamento),
          _PasoFrecuencia(
            frecuenciaActual: _frecuencia,
            onSeleccionar: _seleccionarFrecuencia,
          ),
          _PasoHorarios(
            horarios: _horarios,
            frecuencia: _frecuencia,
            onPickHora: _pickHora,
            onAgregarHora: _agregarHora,
            onEliminarHora: _eliminarHora,
            onSiguiente: () => _irA(3),
          ),
          _PasoConfirmacion(
            medicamento: _medicamento,
            frecuencia: _frecuencia,
            horarios: _horarios,
            formatHora: _formatHora,
            onGuardar: _guardar,
          ),
        ],
      ),
    );
  }

  String _tituloPaso(int p) => switch (p) {
        0 => 'Buscar medicamento',
        1 => 'Frecuencia',
        2 => 'Horarios',
        _ => 'Confirmar',
      };
}

// ── Barra de progreso ─────────────────────────────────────────────────────────

class _BarraProgreso extends StatelessWidget {
  const _BarraProgreso({required this.paso, required this.total});
  final int paso;
  final int total;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (paso + 1) / total,
      backgroundColor: AppColors.divider,
      color: AppColors.primary,
      minHeight: 4,
    );
  }
}

// ── Paso 1: Buscar medicamento ────────────────────────────────────────────────

class _PasoBuscar extends StatefulWidget {
  const _PasoBuscar({required this.onSeleccionar});
  final void Function(MedicamentoCatalogo) onSeleccionar;

  @override
  State<_PasoBuscar> createState() => _PasoBuscarState();
}

class _PasoBuscarState extends State<_PasoBuscar> {
  final _ctrl = TextEditingController();
  List<MedicamentoCatalogo> _resultados = [];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_filtrar);
  }

  void _filtrar() {
    setState(() => _resultados = filtrarMedicamentos(_ctrl.text));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hayTexto = _ctrl.text.isNotEmpty;
    final hayResultados = _resultados.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ej. Paracetamol, Losartán…',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textDisabled),
              suffixIcon: hayTexto
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: AppColors.textDisabled),
                      onPressed: () => _ctrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 10),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: AppRadius.xlBr,
              ),
            ),
          ),
        ),
        if (!hayTexto)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: SvgPicture.asset(
                        'assets/il_medicacion_empty.svg',
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Escribe el nombre del medicamento',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (!hayResultados)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 48, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sin resultados para "${_ctrl.text}"',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _resultados.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final med = _resultados[i];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDE5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medication_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(med.nombre, style: textTheme.titleSmall),
                  subtitle: Text(med.presentacion,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textDisabled),
                  onTap: () => widget.onSeleccionar(med),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Paso 2: Frecuencia ────────────────────────────────────────────────────────

// Solo las frecuencias relevantes para el usuario; las legacy se mapean internamente.
const _frecuenciasUI = [
  Frecuencia.unaVez,
  Frecuencia.dosVeces,
  Frecuencia.tresVeces,
  Frecuencia.cada8h,
  Frecuencia.cada12h,
  Frecuencia.segunNecesidad,
  Frecuencia.personalizado,
];

class _PasoFrecuencia extends StatelessWidget {
  const _PasoFrecuencia({
    required this.frecuenciaActual,
    required this.onSeleccionar,
  });
  final Frecuencia frecuenciaActual;
  final void Function(Frecuencia) onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          '¿Con qué frecuencia lo toma?',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        ..._frecuenciasUI.map((f) => _ChipFrecuencia(
              frecuencia: f,
              seleccionada: f == frecuenciaActual,
              onTap: () => onSeleccionar(f),
            )),
      ],
    );
  }
}

class _ChipFrecuencia extends StatelessWidget {
  const _ChipFrecuencia({
    required this.frecuencia,
    required this.seleccionada,
    required this.onTap,
  });
  final Frecuencia frecuencia;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sel = seleccionada;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBr,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.surface,
            border: Border.all(
              color: sel ? AppColors.primary : AppColors.cardBorder,
            ),
            borderRadius: AppRadius.lgBr,
          ),
          child: Row(
            children: [
              Icon(
                _iconoFrecuencia(frecuencia),
                color: sel ? AppColors.onPrimary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  frecuencia.label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: sel ? AppColors.onPrimary : AppColors.textPrimary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (sel)
                Icon(Icons.check_rounded,
                    color: AppColors.onPrimary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconoFrecuencia(Frecuencia f) => switch (f) {
        Frecuencia.unaVez || Frecuencia.unaVezAlDia => Icons.looks_one_outlined,
        Frecuencia.dosVeces || Frecuencia.cada12h => Icons.looks_two_outlined,
        Frecuencia.tresVeces || Frecuencia.cada8h => Icons.looks_3_outlined,
        Frecuencia.segunNecesidad => Icons.help_outline_rounded,
        Frecuencia.personalizado => Icons.tune_rounded,
      };
}

// ── Paso 3: Horarios ──────────────────────────────────────────────────────────

class _PasoHorarios extends StatelessWidget {
  const _PasoHorarios({
    required this.horarios,
    required this.frecuencia,
    required this.onPickHora,
    required this.onSiguiente,
    this.onAgregarHora,
    this.onEliminarHora,
  });
  final List<TimeOfDay> horarios;
  final Frecuencia frecuencia;
  final Future<void> Function(int) onPickHora;
  final VoidCallback onSiguiente;
  final VoidCallback? onAgregarHora;
  final void Function(int)? onEliminarHora;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _esPersonalizado => frecuencia == Frecuencia.personalizado;
  bool get _esIntervalo =>
      frecuencia == Frecuencia.cada8h ||
      frecuencia == Frecuencia.cada12h ||
      frecuencia == Frecuencia.dosVeces ||
      frecuencia == Frecuencia.tresVeces;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _esPersonalizado
                ? 'Define tus horarios de toma'
                : '¿A qué hora(s) lo toma?',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _esIntervalo
                ? 'Ajusta la primera hora — las demás se calcularán automáticamente'
                : 'Toca cada horario para ajustarlo',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              children: [
                ...List.generate(horarios.length, (i) {
                  final label = horarios.length == 1
                      ? 'Horario de toma'
                      : 'Toma ${i + 1}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          // Ícono en caja cuadrada morada
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLightBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.schedule_rounded,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  _fmt(horarios[i]),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Botón editar en caja
                          GestureDetector(
                            onTap: () => onPickHora(i),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_outlined,
                                  size: 16, color: AppColors.primary),
                            ),
                          ),
                          if (_esPersonalizado && horarios.length > 1) ...[
                            const SizedBox(width: AppSpacing.xs),
                            GestureDetector(
                              onTap: () => onEliminarHora?.call(i),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDEAEA),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.remove_rounded,
                                    size: 16,
                                    color: AppColors.urgencyHigh),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                if (_esPersonalizado)
                  TextButton.icon(
                    onPressed: onAgregarHora,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar toma'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: AppButton(
              label: 'Continuar',
              onPressed: onSiguiente,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paso 4: Confirmación ──────────────────────────────────────────────────────

class _PasoConfirmacion extends StatefulWidget {
  const _PasoConfirmacion({
    required this.medicamento,
    required this.frecuencia,
    required this.horarios,
    required this.formatHora,
    required this.onGuardar,
  });
  final MedicamentoCatalogo? medicamento;
  final Frecuencia frecuencia;
  final List<TimeOfDay> horarios;
  final String Function(TimeOfDay) formatHora;
  final VoidCallback onGuardar;

  @override
  State<_PasoConfirmacion> createState() => _PasoConfirmacionState();
}

class _PasoConfirmacionState extends State<_PasoConfirmacion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final med = widget.medicamento;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Check animado en bucle
          Center(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: _scale.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo exterior pulsante (verde)
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0FA46E).withAlpha(
                            (_glow.value * 60).round()),
                      ),
                    ),
                    // Círculo principal verde
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F8F3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Color(0xFF0FA46E), size: 40),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Column(
              children: [
                Text(
                  '¡Todo listo!',
                  style: textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0FA46E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisa el resumen antes de guardar',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Card resumen con colores
          Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgBr,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                _FilaResumenColoreada(
                  icono: Icons.medication_rounded,
                  titulo: 'Medicamento',
                  valor: med != null
                      ? '${med.nombre} · ${med.presentacion}'
                      : '—',
                  bg: const Color(0xFFEDE5FF),
                  color: AppColors.primary,
                ),
                Divider(height: 1, color: AppColors.cardBorder),
                _FilaResumenColoreada(
                  icono: Icons.repeat_rounded,
                  titulo: 'Frecuencia',
                  valor: widget.frecuencia.label,
                  bg: const Color(0xFFD1EFEC),
                  color: const Color(0xFF00697A),
                ),
                if (widget.horarios.isNotEmpty) ...[
                  Divider(height: 1, color: AppColors.cardBorder),
                  _FilaResumenColoreada(
                    icono: Icons.schedule_rounded,
                    titulo: widget.horarios.length == 1 ? 'Horario' : 'Horarios',
                    valor: widget.horarios.map(widget.formatHora).join('  ·  '),
                    bg: const Color(0xFFFFF3E0),
                    color: AppColors.accent,
                  ),
                ],
                if (widget.frecuencia == Frecuencia.segunNecesidad) ...[
                  Divider(height: 1, color: AppColors.cardBorder),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Sin recordatorio automático — tomar cuando sea necesario.',
                            style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Spacer(),
          SafeArea(
            top: false,
            child: AppButton(
              label: 'Guardar medicamento',
              onPressed: widget.onGuardar,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _FilaResumenColoreada extends StatelessWidget {
  const _FilaResumenColoreada({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.bg,
    required this.color,
  });
  final IconData icono;
  final String titulo;
  final String valor;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(valor,
                    style:
                        textTheme.bodyMedium?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fila resumen original (mantenida por compatibilidad si se usa en otro lado) ─

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.icono,
    required this.titulo,
    required this.valor,
  });
  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: textTheme.labelSmall
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(valor, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

