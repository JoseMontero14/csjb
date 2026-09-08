import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/dashboard_controller.dart';
import '../../models/toma_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/urgency_badge.dart';

// UID placeholder hasta integrar AuthController global
const _kUidPlaceholder = 'uid-placeholder';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with RouteAware {
  final _controller = DashboardController();
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cargar() => _controller.cargar(_kUidPlaceholder);

  /// Navega a una ruta y recarga el dashboard al volver.
  Future<void> _pushAndRefresh(String route) async {
    await AppRoutes.push(context, route);
    if (mounted) _cargar();
  }

  void _onTabTap(int index) {
    if (index == _tabIndex) return;
    switch (index) {
      case 0:
        setState(() => _tabIndex = 0);
      case 1:
        _pushAndRefresh(AppRoutes.chatLista);
      case 2:
        _pushAndRefresh(AppRoutes.triajeSintomas);
      case 3:
        _pushAndRefresh(AppRoutes.examenes);
      case 4:
        _pushAndRefresh(AppRoutes.medicos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _DashboardBody(
          controller: _controller,
          onMedicacionTap: () => _pushAndRefresh(AppRoutes.medicacion),
          onTriajeTap: () => _pushAndRefresh(AppRoutes.triajeSintomas),
          onTriajeHistorialTap: () =>
              _pushAndRefresh(AppRoutes.triajeHistorial),
        ),
      ),
      floatingActionButton: const _BotonEmergencia(),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        onTap: _onTabTap,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final fecha =
        DateFormat("EEEE d 'de' MMMM", 'es').format(now).toUpperCase();

    return AppBar(
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fecha,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const Text('Hola, José'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline_rounded),
          onPressed: () => AppRoutes.push(context, AppRoutes.perfil),
          tooltip: 'Perfil',
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.controller,
    required this.onMedicacionTap,
    required this.onTriajeTap,
    required this.onTriajeHistorialTap,
  });

  final DashboardController controller;
  final VoidCallback onMedicacionTap;
  final VoidCallback onTriajeTap;
  final VoidCallback onTriajeHistorialTap;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => controller.cargar(_kUidPlaceholder),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _CardBienestar(controller: controller, onTap: onMedicacionTap),
          const SizedBox(height: AppSpacing.md),
          _CardRecordatorio(controller: controller, onTap: onMedicacionTap),
          const SizedBox(height: AppSpacing.md),
          _CardTriaje(
            controller: controller,
            onNuevoTriajeTap: onTriajeTap,
            onHistorialTap: onTriajeHistorialTap,
          ),
          const SizedBox(height: AppSpacing.md),
          const _CardTip(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ── Card 1: Bienestar ─────────────────────────────────────────────────────────

class _CardBienestar extends StatelessWidget {
  const _CardBienestar({required this.controller, required this.onTap});

  final DashboardController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final data = controller.data;
    final isLoading = controller.isLoading;

    final pct = data.bienestarPct;
    final value = data.totalHoy == 0 ? 0.0 : pct / 100.0;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isLoading)
                  const CircularProgressIndicator(strokeWidth: 7)
                else
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    backgroundColor: AppColors.surfaceVariant,
                    color: AppColors.primary,
                    strokeCap: StrokeCap.round,
                  ),
                if (!isLoading)
                  Center(
                    child: Text(
                      '$pct%',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bienestar general', style: textTheme.titleSmall),
                const SizedBox(height: 4),
                if (isLoading)
                  Text('Cargando...', style: textTheme.bodySmall)
                else if (data.sinRegistros)
                  Text('Sin registros aún', style: textTheme.bodySmall)
                else
                  Text(
                    '${data.tomadasHoy} de ${data.totalHoy} tomas hoy',
                    style: textTheme.bodySmall,
                  ),
                if (!isLoading && data.sinRegistros) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Registra tus medicamentos para ver tu adherencia',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textDisabled, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
        ],
      ),
    );
  }
}

// ── Card 2: Próximo recordatorio ──────────────────────────────────────────────

class _CardRecordatorio extends StatelessWidget {
  const _CardRecordatorio({required this.controller, required this.onTap});

  final DashboardController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final proxima = controller.data.proximaToma;
    final isLoading = controller.isLoading;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: proxima != null
                  ? AppColors.surfaceVariant
                  : AppColors.urgencyLowBg,
              borderRadius: AppRadius.mdBr,
            ),
            child: Icon(
              Icons.medication_outlined,
              color: proxima != null
                  ? AppColors.primary
                  : AppColors.urgencyLow,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Próximo recordatorio', style: textTheme.titleSmall),
                const SizedBox(height: 4),
                if (isLoading)
                  Text('Cargando...', style: textTheme.bodySmall)
                else if (proxima == null)
                  Text(
                    controller.data.sinRegistros
                        ? 'Sin recordatorios'
                        : '¡Todas las tomas completadas hoy!',
                    style: textTheme.bodySmall,
                  )
                else
                  _ProximaTomaTile(proxima: proxima),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
        ],
      ),
    );
  }
}

class _ProximaTomaTile extends StatelessWidget {
  const _ProximaTomaTile({required this.proxima});
  final TomaConRecordatorio proxima;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          proxima.medicamento,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          children: [
            Text(proxima.dosis, style: textTheme.bodySmall),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: AppRadius.fullBr,
              ),
              child: Text(
                proxima.toma.hora,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Card 3: Triaje ────────────────────────────────────────────────────────────

class _CardTriaje extends StatelessWidget {
  const _CardTriaje({
    required this.controller,
    required this.onNuevoTriajeTap,
    required this.onHistorialTap,
  });

  final DashboardController controller;
  final VoidCallback onNuevoTriajeTap;
  final VoidCallback onHistorialTap;

  String _fechaRelativa(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Hace 1 día';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    if (diff.inDays < 14) return 'Hace 1 semana';
    return DateFormat('d MMM', 'es').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final data = controller.data;

    if (!data.tieneTriaje) {
      // Sin triajes guardados: toca para hacer uno nuevo
      return AppCard(
        onTap: onNuevoTriajeTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.urgencyLowBg,
                borderRadius: AppRadius.mdBr,
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.urgencyLow,
                size: 26,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Último triaje', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Sin triajes guardados',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textDisabled),
          ],
        ),
      );
    }

    // Con triaje guardado: toca para ver el historial
    final nivel = data.ultimoTriajeNivel!;
    final fecha = data.ultimoTriajeFecha!;

    return AppCard(
      onTap: onHistorialTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: nivel.backgroundColor,
              borderRadius: AppRadius.mdBr,
            ),
            child: Icon(nivel.icon, color: nivel.color, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Último triaje', style: textTheme.titleSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    UrgencyBadge(nivel, size: BadgeSize.small),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '· ${_fechaRelativa(fecha)}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
        ],
      ),
    );
  }
}

// ── Card 4: Tip del día ───────────────────────────────────────────────────────

class _CardTip extends StatelessWidget {
  const _CardTip();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard.accent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.onPrimary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'TIP DEL DÍA',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.onPrimary.withAlpha(180),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cargando tip...',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón emergencia ──────────────────────────────────────────────────────────

class _BotonEmergencia extends StatelessWidget {
  const _BotonEmergencia();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _mostrarDialogo(context),
      backgroundColor: AppColors.urgencyHigh,
      foregroundColor: AppColors.onPrimary,
      tooltip: 'Emergencia',
      child: const Icon(Icons.phone_rounded, size: 28),
    );
  }

  void _mostrarDialogo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.urgencyHigh),
            const SizedBox(width: AppSpacing.sm),
            Text('Emergencia',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _ContactoEmergencia(
                nombre: 'SAMU', numero: '106',
                icono: Icons.local_hospital_rounded),
            Divider(),
            _ContactoEmergencia(
                nombre: 'Bomberos', numero: '116',
                icono: Icons.fire_truck_rounded),
            Divider(),
            _ContactoEmergencia(
                nombre: 'Policía', numero: '105',
                icono: Icons.local_police_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _ContactoEmergencia extends StatelessWidget {
  const _ContactoEmergencia({
    required this.nombre,
    required this.numero,
    required this.icono,
  });

  final String nombre;
  final String numero;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: AppColors.urgencyHigh),
      title: Text(nombre,
          style: Theme.of(context).textTheme.titleSmall),
      trailing: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.phone_rounded, size: 16),
        label: Text(numero),
        style:
            TextButton.styleFrom(foregroundColor: AppColors.urgencyHigh),
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          activeIcon: Icon(Icons.chat_bubble_rounded),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.health_and_safety_outlined),
          activeIcon: Icon(Icons.health_and_safety_rounded),
          label: 'Triaje',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.science_outlined),
          activeIcon: Icon(Icons.science_rounded),
          label: 'Exámenes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_services_outlined),
          activeIcon: Icon(Icons.medical_services_rounded),
          label: 'Médicos',
        ),
      ],
    );
  }
}
