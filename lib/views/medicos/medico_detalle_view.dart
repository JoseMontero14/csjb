import 'package:flutter/material.dart';
import '../../models/medico_model.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';

class MedicoDetalleView extends StatefulWidget {
  const MedicoDetalleView({super.key});

  @override
  State<MedicoDetalleView> createState() => _MedicoDetalleViewState();
}

class _MedicoDetalleViewState extends State<MedicoDetalleView> {
  late final MedicoModel _medico;
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _medico =
          ModalRoute.of(context)!.settings.arguments as MedicoModel;
      _inicializado = true;
    }
  }

  void _solicitarCita() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitud de citas próximamente disponible.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header con foto y nombre ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            leading: const BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: _FotoHeader(medico: _medico),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y especialidad
                  Text(_medico.nombre, style: textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(18),
                      borderRadius: AppRadius.fullBr,
                    ),
                    child: Text(
                      _medico.especialidad,
                      style: textTheme.labelMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Descripción de especialidad
                  _Seccion(
                    icono: Icons.school_rounded,
                    titulo: 'Sobre la especialidad',
                    child: Text(
                      _medico.descripcionEspecialidad,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textPrimary, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Días y horario
                  _Seccion(
                    icono: Icons.calendar_month_rounded,
                    titulo: 'Días y horario de atención',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: _medico.dias
                              .map((d) => _DiaChip(dia: d))
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              _medico.horario,
                              style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Botón de cita
                  AppButton(
                    label: 'Solicitar cita',
                    onPressed: _solicitarCita,
                    icon: const Icon(Icons.event_available_rounded),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _FotoHeader extends StatelessWidget {
  const _FotoHeader({required this.medico});
  final MedicoModel medico;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            medico.fotoUrl,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => const Icon(
              Icons.person_rounded,
              size: 80,
              color: AppColors.textDisabled,
            ),
          ),
          // Gradiente inferior para legibilidad del AppBar
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000)],
                stops: [0.0, 0.5],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.icono,
    required this.titulo,
    required this.child,
  });

  final IconData icono;
  final String titulo;
  final Widget child;

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
                style:
                    textTheme.titleSmall?.copyWith(color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _DiaChip extends StatelessWidget {
  const _DiaChip({required this.dia});
  final String dia;

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
        dia.substring(0, 3),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}
