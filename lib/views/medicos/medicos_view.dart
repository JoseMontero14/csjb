import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final _busquedaCtrl = TextEditingController();
  bool _inicializado = false;
  String _busqueda = '';

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
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<MedicoModel> _filtrarPorBusqueda(List<MedicoModel> medicos) {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return medicos;
    return medicos.where((m) {
      return m.nombre.toLowerCase().contains(q) ||
          m.especialidadDisplay.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Directorio médico'),
            Text(
              'Clínica San Juan Bautista',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary.withAlpha(160),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ClipOval(
              child: Image.asset('assets/logo_csjb.png',
                  width: 28, height: 28, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
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
          final filtrados = _filtrarPorBusqueda(_controller.medicosFiltrados);
          return Column(
            children: [
              _BarraBusqueda(
                controller: _busquedaCtrl,
                onChanged: (v) => setState(() => _busqueda = v),
              ),
              _ChipsEspecialidades(
                especialidades: _controller.especialidades,
                seleccionada: _controller.especialidadSeleccionada,
                onSeleccionar: _controller.setEspecialidad,
              ),
              Expanded(
                child: filtrados.isEmpty
                    ? _EstadoVacioFiltro(
                        especialidad: _busqueda.isNotEmpty
                            ? _busqueda
                            : (_controller.especialidadSeleccionada ?? ''),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _controller.cargar,
                        child: _ListaMedicos(
                          medicos: filtrados,
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

// ── Barra de búsqueda ────────────────────────────────────────────────────────

class _BarraBusqueda extends StatelessWidget {
  const _BarraBusqueda({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar médico o especialidad...',
          hintStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textDisabled),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textDisabled, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        size: 18, color: AppColors.textDisabled),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: AppRadius.xlBr,
          ),
        ),
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
            selectedColor: AppColors.primary.withAlpha(20),
            checkmarkColor: AppColors.primary,
            side: BorderSide(
              color: activo ? AppColors.primary : AppColors.surfaceVariant,
            ),
            labelStyle: textTheme.labelMedium?.copyWith(
              color: activo ? AppColors.primary : AppColors.textSecondary,
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: medicos.length,
      itemBuilder: (context, i) =>
          _MedicoTile(medico: medicos[i], onTap: () => onTap(medicos[i])),
    );
  }
}

// Color de fondo del avatar-placeholder según especialidad
Color _colorEspecialidad(String especialidad) {
  final lower = especialidad.toLowerCase();
  if (lower.contains('cardio')) return const Color(0xFFFFEBEE);
  if (lower.contains('gine') || lower.contains('obstet')) return const Color(0xFFFCE4EC);
  if (lower.contains('cirugía') || lower.contains('cirug')) return const Color(0xFFD1EFEC);
  if (lower.contains('pediatr')) return const Color(0xFFFFF3E0);
  if (lower.contains('neuro')) return const Color(0xFFE3F2FD);
  if (lower.contains('traumat') || lower.contains('ortop')) return const Color(0xFFE8F5E9);
  if (lower.contains('nutri') || lower.contains('endocrin')) return const Color(0xFFF3E5F5);
  if (lower.contains('oftalm')) return const Color(0xFFE0F7FA);
  if (lower.contains('dermat')) return const Color(0xFFFFF3E0);
  if (lower.contains('psiqui') || lower.contains('psicol')) return const Color(0xFFEDE5FF);
  return const Color(0xFFEDE5FF);
}

class _MedicoTile extends StatelessWidget {
  const _MedicoTile({required this.medico, required this.onTap});

  final MedicoModel medico;
  final VoidCallback onTap;

  static const _diasNombres = {
    1: 'Lunes', 2: 'Martes', 3: 'Miércoles', 4: 'Jueves',
    5: 'Viernes', 6: 'Sábado', 7: 'Domingo',
  };

  bool get _disponibleHoy {
    final hoy = _diasNombres[DateTime.now().weekday] ?? '';
    return medico.dias.any(
      (d) => d.toLowerCase().startsWith(hoy.substring(0, 3).toLowerCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final diasStr = medico.dias.length >= 5
        ? 'Lun – Vie'
        : medico.dias.map((d) => d.substring(0, 3)).join(' · ');
    final disponible = _disponibleHoy;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            // Avatar cuadrado radio 14 con borde blanco en el dot
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _colorEspecialidad(medico.especialidad),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _MedicoAvatarTile(fotoUrl: medico.fotoUrl),
                ),
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: disponible
                              ? const Color(0xFF4CAF50)
                              : AppColors.textDisabled,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medico.nombre, style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  // Specialty pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightBg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      medico.especialidadDisplay,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        disponible ? 'Disponible hoy' : 'No disponible hoy',
                        style: textTheme.labelSmall?.copyWith(
                          color: disponible
                              ? const Color(0xFF2E7D32)
                              : AppColors.textDisabled,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Text('·',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        diasStr,
                        style: textTheme.labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Flecha en caja
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicoAvatarTile extends StatelessWidget {
  const _MedicoAvatarTile({required this.fotoUrl});
  final String fotoUrl;

  @override
  Widget build(BuildContext context) {
    if (fotoUrl.startsWith('data:image')) {
      final b64 = fotoUrl.contains(',') ? fotoUrl.split(',').last : fotoUrl;
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes,
            fit: BoxFit.cover, width: 60, height: 60);
      } catch (_) {}
    } else if (fotoUrl.isNotEmpty) {
      return Image.network(fotoUrl,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _MedicoIconPlaceholder());
    }
    return _MedicoIconPlaceholder();
  }
}

class _MedicoIconPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/il_doctor_placeholder.svg',
        fit: BoxFit.cover,
      );
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
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE5FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded,
                  size: 40, color: AppColors.primary),
            ),
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

