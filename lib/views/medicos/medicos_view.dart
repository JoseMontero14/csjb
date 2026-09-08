import 'package:flutter/material.dart';
import '../../controllers/medico_controller.dart';
import '../../models/medico_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';

class MedicosView extends StatefulWidget {
  const MedicosView({super.key});

  @override
  State<MedicosView> createState() => _MedicosViewState();
}

class _MedicosViewState extends State<MedicosView> {
  final _controller = MedicoController();
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      final especialidadInicial =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (especialidadInicial != null) {
        _controller.cargarConFiltroInicial(especialidadInicial);
      } else {
        _controller.cargar();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directorio médico')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.cargando) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (_controller.error != null) {
            return _EstadoError(
              mensaje: _controller.error!,
              onReintentar: _controller.cargar,
            );
          }
          if (_controller.especialidades.isEmpty) {
            return _EstadoVacioSinDatos(
              onCargarEjemplos: _controller.cargarDatosEjemplo,
            );
          }
          return Column(
            children: [
              _ChipsEspecialidades(
                especialidades: _controller.especialidades,
                seleccionada: _controller.especialidadSeleccionada,
                onSeleccionar: _controller.setEspecialidad,
              ),
              Expanded(
                child: _controller.medicosFiltrados.isEmpty
                    ? _EstadoVacioFiltro(
                        especialidad:
                            _controller.especialidadSeleccionada ?? '',
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _controller.cargar,
                        child: _ListaMedicos(
                          medicos: _controller.medicosFiltrados,
                          onTap: (m) => AppRoutes.push(
                            context,
                            AppRoutes.medicoDetalle,
                            args: m,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Chips de especialidad ─────────────────────────────────────────────────────

class _ChipsEspecialidades extends StatelessWidget {
  const _ChipsEspecialidades({
    required this.especialidades,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  final List<String> especialidades;
  final String? seleccionada;
  final ValueChanged<String?> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final todas = [null, ...especialidades.map<String?>((e) => e)];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        itemCount: todas.length,
        separatorBuilder: (context2, i2) =>
            const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final esp = todas[i];
          final label = esp ?? 'Todas';
          final activo = seleccionada == esp;

          return FilterChip(
            label: Text(label),
            selected: activo,
            onSelected: (_) => onSeleccionar(esp),
            selectedColor: AppColors.urgencyMediumBg,
            checkmarkColor: AppColors.accent,
            side: BorderSide(
              color: activo ? AppColors.accent : AppColors.surfaceVariant,
            ),
            labelStyle: textTheme.labelMedium?.copyWith(
              color: activo ? AppColors.accentDark : AppColors.textSecondary,
              fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
            ),
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBr),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

// ── Lista de médicos ──────────────────────────────────────────────────────────

class _ListaMedicos extends StatelessWidget {
  const _ListaMedicos({required this.medicos, required this.onTap});

  final List<MedicoModel> medicos;
  final ValueChanged<MedicoModel> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: medicos.length,
      separatorBuilder: (context2, i2) => const Divider(height: 1),
      itemBuilder: (context, i) =>
          _MedicoTile(medico: medicos[i], onTap: () => onTap(medicos[i])),
    );
  }
}

class _MedicoTile extends StatelessWidget {
  const _MedicoTile({required this.medico, required this.onTap});

  final MedicoModel medico;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final diasStr = medico.dias.length >= 5
        ? 'Lun – Vie'
        : medico.dias.map((d) => d.substring(0, 3)).join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.surfaceVariant,
        backgroundImage: NetworkImage(medico.fotoUrl),
        onBackgroundImageError: (err, st) {},
      ),
      title: Text(medico.nombre, style: textTheme.titleSmall),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(medico.especialidad,
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.primary)),
          Text(diasStr,
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textDisabled),
      onTap: onTap,
    );
  }
}

// ── Estados ───────────────────────────────────────────────────────────────────

class _EstadoVacioSinDatos extends StatelessWidget {
  const _EstadoVacioSinDatos({required this.onCargarEjemplos});
  final VoidCallback onCargarEjemplos;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 72, color: AppColors.surfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text('Sin médicos cargados',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'El directorio está vacío. Próximamente se cargará '
              'el directorio oficial.',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            // TODO: quitar antes de producción
            OutlinedButton.icon(
              onPressed: onCargarEjemplos,
              icon: const Icon(Icons.warning_amber_rounded, size: 16),
              label: const Text('Cargar datos de ejemplo (temporal)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.surfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacioFiltro extends StatelessWidget {
  const _EstadoVacioFiltro({required this.especialidad});
  final String especialidad;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded,
                size: 64, color: AppColors.surfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text('Sin médicos en "$especialidad"',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Prueba con otra especialidad o consulta en recepción.',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

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
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppColors.urgencyHigh),
            const SizedBox(height: AppSpacing.md),
            Text(mensaje,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onReintentar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
