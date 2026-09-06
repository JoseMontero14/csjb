import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_card.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _tabIndex = 0;

  // Destinos del bottom nav que ya tienen ruta
  void _onTabTap(int index) {
    if (index == _tabIndex) return;
    switch (index) {
      case 0:
        setState(() => _tabIndex = 0);
      case 1:
        AppRoutes.push(context, AppRoutes.chatLista);
      case 2:
        AppRoutes.push(context, AppRoutes.triajeSintomas);
      case 3:
        AppRoutes.push(context, AppRoutes.examenes);
      case 4:
        AppRoutes.push(context, AppRoutes.medicos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _DashboardBody(),
      floatingActionButton: _BotonEmergencia(),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        onTap: _onTabTap,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(now).toUpperCase();

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
          Text(
            'Hola, José',
            style: textTheme.titleLarge,
          ),
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
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        _CardBienestar(),
        SizedBox(height: AppSpacing.md),
        _CardRecordatorio(),
        SizedBox(height: AppSpacing.md),
        _CardTriaje(),
        SizedBox(height: AppSpacing.md),
        _CardTip(),
        SizedBox(height: AppSpacing.xxl), // espacio para el FAB
      ],
    );
  }
}

// ── Card 1: Bienestar ─────────────────────────────────────────────────────────

class _CardBienestar extends StatelessWidget {
  const _CardBienestar();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          // Indicador circular
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 0,
                  strokeWidth: 7,
                  backgroundColor: AppColors.surfaceVariant,
                  color: AppColors.primary,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '0%',
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
                Text(
                  'Sin registros aún',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Registra tus medicamentos para ver tu adherencia',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textDisabled,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textDisabled,
          ),
        ],
      ),
      onTap: () {},
    );
  }
}

// ── Card 2: Recordatorio ──────────────────────────────────────────────────────

class _CardRecordatorio extends StatelessWidget {
  const _CardRecordatorio();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.mdBr,
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppColors.primary,
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
                Text('Sin recordatorios', style: textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}

// ── Card 3: Triaje ────────────────────────────────────────────────────────────

class _CardTriaje extends StatelessWidget {
  const _CardTriaje();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () {},
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
                Text('Sin triajes', style: textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textDisabled,
          ),
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
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.onPrimary,
                size: 18,
              ),
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
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _mostrarDialogoEmergencia(context),
      backgroundColor: AppColors.urgencyHigh,
      foregroundColor: AppColors.onPrimary,
      tooltip: 'Emergencia',
      child: const Icon(Icons.phone_rounded, size: 28),
    );
  }

  void _mostrarDialogoEmergencia(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.urgencyHigh),
            const SizedBox(width: AppSpacing.sm),
            Text('Emergencia', style: textTheme.headlineSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ContactoEmergencia(
              nombre: 'SAMU',
              numero: '106',
              icono: Icons.local_hospital_rounded,
            ),
            const Divider(height: AppSpacing.md),
            _ContactoEmergencia(
              nombre: 'Bomberos',
              numero: '116',
              icono: Icons.fire_truck_rounded,
            ),
            const Divider(height: AppSpacing.md),
            _ContactoEmergencia(
              nombre: 'Policía',
              numero: '105',
              icono: Icons.local_police_rounded,
            ),
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
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: AppColors.urgencyHigh),
      title: Text(nombre, style: textTheme.titleSmall),
      trailing: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.phone_rounded, size: 16),
        label: Text(numero),
        style: TextButton.styleFrom(foregroundColor: AppColors.urgencyHigh),
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
