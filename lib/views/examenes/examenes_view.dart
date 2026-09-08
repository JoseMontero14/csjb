import 'package:flutter/material.dart';
import '../../controllers/examen_controller.dart';
import '../../models/examen_model.dart';
import '../../utils/theme.dart';

class ExamenesView extends StatefulWidget {
  const ExamenesView({super.key});

  @override
  State<ExamenesView> createState() => _ExamenesViewState();
}

class _ExamenesViewState extends State<ExamenesView> {
  final _controller = ExamenController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.cargar();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _abrirDetalle(ExamenModel examen) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ExamenBottomSheet(examen: examen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de exámenes')),
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

          // Lista vacía: no hay datos en Firestore todavía
          if (_controller.examenes.isEmpty) {
            return _EstadoVacioSinDatos(
              onCargarEjemplos: () async {
                await _controller.cargarDatosEjemplo();
              },
            );
          }

          return Column(
            children: [
              _BarraBusqueda(
                controller: _searchController,
                onChanged: _controller.setBusqueda,
              ),
              _ChipsCategorias(
                categorias: _controller.categorias,
                seleccionada: _controller.categoriaSeleccionada,
                onSeleccionar: _controller.setCategoria,
              ),
              Expanded(
                child: _controller.examenesFiltrados.isEmpty
                    ? const _EstadoVacioFiltro()
                    : _ListaExamenes(
                        examenes: _controller.examenesFiltrados,
                        onTap: _abrirDetalle,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Barra de búsqueda ─────────────────────────────────────────────────────────

class _BarraBusqueda extends StatelessWidget {
  const _BarraBusqueda({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar examen...',
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textDisabled),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textDisabled),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
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

// ── Chips de categoría ────────────────────────────────────────────────────────

class _ChipsCategorias extends StatelessWidget {
  const _ChipsCategorias({
    required this.categorias,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  final List<String> categorias;
  final String? seleccionada;
  final ValueChanged<String?> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final todas = [null, ...categorias.map<String?>((c) => c)];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: todas.length,
        separatorBuilder: (context2, i2) =>
            const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final cat = todas[i];
          final label = cat ?? 'Todos';
          final activo = seleccionada == cat;

          return FilterChip(
            label: Text(label),
            selected: activo,
            onSelected: (_) => onSeleccionar(cat),
            selectedColor: AppColors.urgencyMediumBg,
            checkmarkColor: AppColors.accent,
            side: BorderSide(
              color: activo ? AppColors.accent : AppColors.surfaceVariant,
            ),
            labelStyle: textTheme.labelMedium?.copyWith(
              color:
                  activo ? AppColors.accentDark : AppColors.textSecondary,
              fontWeight:
                  activo ? FontWeight.w600 : FontWeight.normal,
            ),
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBr),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

// ── Lista de exámenes ─────────────────────────────────────────────────────────

class _ListaExamenes extends StatelessWidget {
  const _ListaExamenes({
    required this.examenes,
    required this.onTap,
  });

  final List<ExamenModel> examenes;
  final ValueChanged<ExamenModel> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: examenes.length,
      separatorBuilder: (context2, i2) => const Divider(height: 1),
      itemBuilder: (context, i) =>
          _ExamenTile(examen: examenes[i], onTap: () => onTap(examenes[i])),
    );
  }
}

class _ExamenTile extends StatelessWidget {
  const _ExamenTile({required this.examen, required this.onTap});

  final ExamenModel examen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.mdBr,
        ),
        child: Icon(
          _iconoCategoria(examen.categoria),
          color: AppColors.primary,
          size: 22,
        ),
      ),
      title: Text(
        examen.nombre,
        style: textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            examen.categoria,
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (examen.requierePreparacion) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.schedule_rounded,
                size: 12, color: AppColors.accent),
            const SizedBox(width: 2),
            Text(
              'Requiere preparación',
              style: textTheme.labelSmall
                  ?.copyWith(color: AppColors.accent),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textDisabled),
      onTap: onTap,
    );
  }

  IconData _iconoCategoria(String cat) => switch (cat) {
        'Sangre' => Icons.water_drop_rounded,
        'Orina' => Icons.science_rounded,
        'Imágenes' => Icons.image_search_rounded,
        'Cardiología' => Icons.favorite_rounded,
        'Preventivo' => Icons.shield_rounded,
        _ => Icons.biotech_rounded,
      };
}

// ── Bottom sheet de detalle ───────────────────────────────────────────────────

class _ExamenBottomSheet extends StatelessWidget {
  const _ExamenBottomSheet({required this.examen});
  final ExamenModel examen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scroll) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.fullBr,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(examen.nombre, style: textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _CategoriaChip(categoria: examen.categoria),
                  const SizedBox(height: AppSpacing.lg),

                  // Qué es
                  _SeccionDetalle(
                    icono: Icons.info_outline_rounded,
                    titulo: '¿Qué es?',
                    contenido: examen.queEs,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Para qué sirve
                  _SeccionDetalle(
                    icono: Icons.check_circle_outline_rounded,
                    titulo: '¿Para qué sirve?',
                    contenido: examen.paraQueSirve,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Preparación
                  _SeccionPreparacion(examen: examen),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriaChip extends StatelessWidget {
  const _CategoriaChip({required this.categoria});
  final String categoria;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.fullBr,
      ),
      child: Text(
        categoria,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _SeccionDetalle extends StatelessWidget {
  const _SeccionDetalle({
    required this.icono,
    required this.titulo,
    required this.contenido,
  });

  final IconData icono;
  final String titulo;
  final String contenido;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(titulo,
                style: textTheme.titleSmall
                    ?.copyWith(color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(contenido,
            style: textTheme.bodyMedium
                ?.copyWith(color: AppColors.textPrimary, height: 1.5)),
      ],
    );
  }
}

class _SeccionPreparacion extends StatelessWidget {
  const _SeccionPreparacion({required this.examen});
  final ExamenModel examen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!examen.requierePreparacion) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.urgencyLowBg,
          borderRadius: AppRadius.mdBr,
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.urgencyLow, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'No requiere preparación especial',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.urgencyLow),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.urgencyMediumBg,
        borderRadius: AppRadius.mdBr,
        border: Border.all(
            color: AppColors.urgencyMedium.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.urgencyMedium, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text('Requiere preparación',
                  style: textTheme.titleSmall
                      ?.copyWith(color: AppColors.accentDark)),
            ],
          ),
          if (examen.indicacionesPreparacion != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              examen.indicacionesPreparacion!,
              style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Estados vacíos ────────────────────────────────────────────────────────────

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
            Icon(Icons.biotech_rounded,
                size: 72, color: AppColors.surfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin exámenes cargados',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'El catálogo está vacío. Próximamente se cargará '
              'el contenido oficial.',
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
  const _EstadoVacioFiltro();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: AppColors.surfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text('Sin resultados',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Intenta con otro término o cambia el filtro de categoría.',
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
