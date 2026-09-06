import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/medicacion_controller.dart';
import '../../models/recordatorio_model.dart';
import '../../models/toma_model.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_input.dart';

// UID placeholder hasta integrar AuthController global
const _kUidPlaceholder = 'uid-placeholder';

class MedicacionView extends StatefulWidget {
  const MedicacionView({super.key});

  @override
  State<MedicacionView> createState() => _MedicacionViewState();
}

class _MedicacionViewState extends State<MedicacionView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _controller = MedicacionController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller.cargarHoy(_kUidPlaceholder);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicación'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hoy'),
            Tab(text: 'Adherencia'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => TabBarView(
          controller: _tabController,
          children: [
            _TabHoy(controller: _controller),
            _TabAdherencia(controller: _controller),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirBottomSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Agregar medicamento',
          style: textTheme.labelLarge?.copyWith(color: AppColors.onPrimary),
        ),
      ),
    );
  }

  void _abrirBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AgregarMedicamentoSheet(
        onGuardar: (rec) {
          _controller.agregarRecordatorio(rec);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Tab Hoy ───────────────────────────────────────────────────────────────────

class _TabHoy extends StatelessWidget {
  const _TabHoy({required this.controller});
  final MedicacionController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.tomasHoy.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined,
                size: 64, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.md),
            Text('Sin medicamentos para hoy',
                style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Text('Toca "Agregar medicamento" para comenzar',
                style: textTheme.bodySmall),
          ],
        ),
      );
    }

    return Column(
      children: [
        _ResumenHoy(controller: controller),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: controller.tomasHoy.length,
            separatorBuilder: (context2, idx) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _TarjetaToma(
              item: controller.tomasHoy[i],
              onChanged: (val) =>
                  controller.marcarToma(controller.tomasHoy[i], val),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumenHoy extends StatelessWidget {
  const _ResumenHoy({required this.controller});
  final MedicacionController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = controller.totalHoy == 0
        ? 0
        : (controller.tomadasHoy / controller.totalHoy * 100).round();

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.lgBr,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: controller.totalHoy == 0
                      ? 0
                      : controller.tomadasHoy / controller.totalHoy,
                  strokeWidth: 6,
                  backgroundColor: AppColors.divider,
                  color: AppColors.primary,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text('$pct%',
                      style: textTheme.labelLarge
                          ?.copyWith(color: AppColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${controller.tomadasHoy} de ${controller.totalHoy} tomas completadas hoy',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TarjetaToma extends StatelessWidget {
  const _TarjetaToma({required this.item, required this.onChanged});
  final TomaConRecordatorio item;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tomado = item.toma.tomado;

    return AppCard(
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: tomado,
            onChanged: (v) => onChanged(v ?? false),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Horario
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: tomado
                  ? AppColors.urgencyLowBg
                  : AppColors.surfaceVariant,
              borderRadius: AppRadius.smBr,
            ),
            child: Text(
              item.toma.hora,
              style: textTheme.labelMedium?.copyWith(
                color:
                    tomado ? AppColors.urgencyLow : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Nombre + dosis
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicamento,
                  style: textTheme.titleSmall?.copyWith(
                    decoration:
                        tomado ? TextDecoration.lineThrough : null,
                    color: tomado ? AppColors.textDisabled : null,
                  ),
                ),
                Text(item.dosis, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (tomado)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.urgencyLow, size: 20),
        ],
      ),
    );
  }
}

// ── Tab Adherencia ────────────────────────────────────────────────────────────

class _TabAdherencia extends StatelessWidget {
  const _TabAdherencia({required this.controller});
  final MedicacionController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = (controller.adherenciaSemanal * 100).round();
    final color = pct >= 80
        ? AppColors.urgencyLow
        : pct >= 50
            ? AppColors.urgencyMedium
            : AppColors.urgencyHigh;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Column(
            children: [
              Text('Adherencia semanal', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: controller.adherenciaSemanal,
                      strokeWidth: 12,
                      backgroundColor: AppColors.divider,
                      color: color,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            style: textTheme.headlineMedium
                                ?.copyWith(color: color),
                          ),
                          Text('últimos 7 días',
                              style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _mensajeAdherencia(pct),
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _mensajeAdherencia(int pct) {
    if (pct == 0) return 'Sin datos suficientes aún.';
    if (pct >= 80) return '¡Excelente! Estás tomando bien tus medicamentos.';
    if (pct >= 50) return 'Puedes mejorar. Intenta no saltarte tomas.';
    return 'Adherencia baja. Recuerda tomar tus medicamentos a tiempo.';
  }
}

// ── Bottom Sheet: Agregar medicamento ─────────────────────────────────────────

class _AgregarMedicamentoSheet extends StatefulWidget {
  const _AgregarMedicamentoSheet({required this.onGuardar});
  final void Function(RecordatorioModel) onGuardar;

  @override
  State<_AgregarMedicamentoSheet> createState() =>
      _AgregarMedicamentoSheetState();
}

class _AgregarMedicamentoSheetState
    extends State<_AgregarMedicamentoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _dosisCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  Frecuencia _frecuencia = Frecuencia.unaVezAlDia;
  List<TimeOfDay> _horarios = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime _fechaInicio = DateTime.now();
  bool _sinFechaFin = true;
  DateTime? _fechaFin;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dosisCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  String _formatHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _onFrecuenciaChanged(Frecuencia f) {
    setState(() {
      _frecuencia = f;
      _horarios = switch (f) {
        Frecuencia.cada8h => [
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 16, minute: 0),
            const TimeOfDay(hour: 0, minute: 0),
          ],
        Frecuencia.cada12h => [
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 20, minute: 0),
          ],
        Frecuencia.unaVezAlDia => [const TimeOfDay(hour: 8, minute: 0)],
        Frecuencia.personalizado => [const TimeOfDay(hour: 8, minute: 0)],
      };
    });
  }

  Future<void> _pickHora(int idx) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horarios[idx],
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _horarios[idx] = picked);
  }

  Future<void> _pickFecha({required bool inicio}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: inicio ? _fechaInicio : (_fechaFin ?? now),
      firstDate: inicio ? now.subtract(const Duration(days: 365)) : now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('es'),
    );
    if (picked == null) return;
    setState(() {
      if (inicio) {
        _fechaInicio = picked;
      } else {
        _fechaFin = picked;
      }
    });
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final rec = RecordatorioModel(
      id: '',
      uid: _kUidPlaceholder,
      medicamento: _nombreCtrl.text.trim(),
      dosis: _dosisCtrl.text.trim(),
      frecuencia: _frecuencia,
      horarios: _horarios.map(_formatHora).toList(),
      fechaInicio: _fechaInicio,
      sinFechaFin: _sinFechaFin,
      fechaFin: _sinFechaFin ? null : _fechaFin,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );
    widget.onGuardar(rec);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, mq.viewInsets.bottom + AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text('Agregar medicamento',
                    style: textTheme.titleLarge),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Nombre y dosis
              AppInput(
                controller: _nombreCtrl,
                label: 'Nombre del medicamento',
                hint: 'Ej. Paracetamol',
                prefixIcon: const Icon(Icons.medication_outlined),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa el nombre.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppInput(
                controller: _dosisCtrl,
                label: 'Dosis',
                hint: 'Ej. 500mg, 1 tableta',
                prefixIcon: const Icon(Icons.straighten_outlined),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa la dosis.' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Frecuencia
              Text('Frecuencia', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: Frecuencia.values.map((f) {
                  final sel = f == _frecuencia;
                  return ChoiceChip(
                    label: Text(f.label),
                    selected: sel,
                    onSelected: (_) => _onFrecuenciaChanged(f),
                    selectedColor: AppColors.accent,
                    labelStyle: textTheme.labelLarge?.copyWith(
                      color: sel ? AppColors.onAccent : AppColors.textPrimary,
                    ),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.fullBr),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Horarios
              Text('Horarios de toma', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ..._horarios.asMap().entries.map((e) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: InkWell(
                      onTap: () => _pickHora(e.key),
                      borderRadius: AppRadius.lgBr,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Horario ${e.key + 1}',
                          prefixIcon:
                              const Icon(Icons.schedule_outlined),
                          suffixIcon:
                              const Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _formatHora(e.value),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )),

              // Agregar horario extra en modo personalizado
              if (_frecuencia == Frecuencia.personalizado)
                TextButton.icon(
                  onPressed: () => setState(() => _horarios
                      .add(const TimeOfDay(hour: 12, minute: 0))),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar horario'),
                ),

              const SizedBox(height: AppSpacing.md),

              // Fecha inicio
              Text('Fechas', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: () => _pickFecha(inicio: true),
                borderRadius: AppRadius.lgBr,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de inicio',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_fechaInicio),
                    style: textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Sin fecha de fin
              Row(
                children: [
                  Checkbox(
                    value: _sinFechaFin,
                    onChanged: (v) =>
                        setState(() => _sinFechaFin = v ?? true),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Sin fecha de fin', style: textTheme.bodyMedium),
                ],
              ),

              if (!_sinFechaFin) ...[
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: () => _pickFecha(inicio: false),
                  borderRadius: AppRadius.lgBr,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de fin',
                      prefixIcon: Icon(Icons.event_outlined),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _fechaFin != null
                          ? DateFormat('dd/MM/yyyy').format(_fechaFin!)
                          : 'Seleccionar',
                      style: textTheme.bodyMedium?.copyWith(
                        color: _fechaFin != null
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Notas
              AppInput(
                controller: _notasCtrl,
                label: 'Notas adicionales (opcional)',
                hint: 'Ej. Tomar con alimentos',
                maxLines: 2,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Guardar medicamento',
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
