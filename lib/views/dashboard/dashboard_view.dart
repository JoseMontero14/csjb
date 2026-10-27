import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/tip_controller.dart';
import '../../models/tip_model.dart';
import '../../models/usuario_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/urgency_badge.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

// ── Paleta de tarjetas (inspirada en referencia de la clínica) ────────────────

const _kLavender = Color(0xFFEDE5FF);
const _kTeal     = Color(0xFFD1EFEC);
const _kBlue     = Color(0xFFD6EBFA);

// ── Vista principal ───────────────────────────────────────────────────────────

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

  void _cargar() => _controller.cargar(_uid);

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
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: _DashboardBody(
          controller: _controller,
          onPerfilTap: () => AppRoutes.push(context, AppRoutes.perfil),
          onMedicacionTap: () => _pushAndRefresh(AppRoutes.medicacion),
          onTriajeTap: () => _pushAndRefresh(AppRoutes.triajeSintomas),
          onTriajeHistorialTap: () =>
              _pushAndRefresh(AppRoutes.triajeHistorial),
        ),
        floatingActionButton: const _BotonEmergencia(),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _tabIndex,
          onTap: _onTabTap,
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.controller,
    required this.onPerfilTap,
    required this.onMedicacionTap,
    required this.onTriajeTap,
    required this.onTriajeHistorialTap,
  });

  final DashboardController controller;
  final VoidCallback onPerfilTap;
  final VoidCallback onMedicacionTap;
  final VoidCallback onTriajeTap;
  final VoidCallback onTriajeHistorialTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeaderSimple(
          nombre: controller.data.nombre,
          onPerfilTap: onPerfilTap,
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => controller.cargar(_uid),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md,
                // Espacio extra para que el FAB no tape el último item
                AppSpacing.xxl + 56 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                _CardBienestar(
                    controller: controller, onTap: onMedicacionTap),
                const SizedBox(height: AppSpacing.sm),
                _CardRecordatorio(
                    controller: controller, onTap: onMedicacionTap),
                const SizedBox(height: AppSpacing.sm),
                _CardTriaje(
                  controller: controller,
                  onNuevoTriajeTap: onTriajeTap,
                  onHistorialTap: onTriajeHistorialTap,
                ),
                const SizedBox(height: AppSpacing.xl),
                _SeccionTips(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Header simple (estilo referencia: blanco + logo + saludo) ─────────────────

class _HeaderSimple extends StatelessWidget {
  const _HeaderSimple({required this.nombre, required this.onPerfilTap});

  final String nombre;
  final VoidCallback onPerfilTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final fecha = DateFormat("EEEE, d 'de' MMMM", 'es').format(now);

    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo + Nombre clínica + botón perfil
              Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/logo_csjb.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Clínica San Juan Bautista',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Material(
                    color: AppColors.primary.withAlpha(12),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onPerfilTap,
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Fecha
              Text(
                fecha,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              // Saludo
              Text(
                nombre.isNotEmpty ? 'Hola, $nombre 👋' : 'Hola 👋',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta ilustrada base (estilo referencia) ────────────────────────────────

class _IlluCard extends StatelessWidget {
  const _IlluCard({
    required this.bg,
    required this.svgAsset,
    required this.onTap,
    required this.content,
    this.svgHeight = 130,
    });

  final Color bg;
  final String svgAsset;
  final VoidCallback? onTap;
  final Widget content;
  final double svgHeight;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = (screenWidth * 0.37).clamp(120.0, 150.0);
    final illuWidth = (screenWidth * 0.37).clamp(110.0, 150.0);

    return Material(
      color: bg,
      borderRadius: AppRadius.xlBr,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xlBr,
        splashColor: Colors.black.withAlpha(10),
        child: SizedBox(
          height: cardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Ilustración — lado izquierdo
              SizedBox(
                width: illuWidth,
                height: cardHeight,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: SvgPicture.asset(
                    svgAsset,
                    height: svgHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Contenido — lado derecho
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta Bienestar ─────────────────────────────────────────────────────────

class _CardBienestar extends StatelessWidget {
  const _CardBienestar({required this.controller, required this.onTap});

  final DashboardController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final data = controller.data;
    final isLoading = controller.isLoading;
    final pct = data.bienestarPct;
    final value = data.totalHoy == 0 ? 0.0 : pct / 100.0;
    final ringColor = pct >= 80
        ? AppColors.urgencyLow
        : pct >= 50
            ? AppColors.accent
            : const Color(0xFFEF5350);

    return _IlluCard(
      bg: _kLavender,
      svgAsset: 'assets/il_doctor_header.svg',
      onTap: onTap,
      svgHeight: 125,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: AppColors.primary, size: 14),
              const SizedBox(width: 5),
              Text(
                'Bienestar',
                style: tt.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (isLoading)
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                color: AppColors.primary.withAlpha(60),
              ),
            )
          else
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    backgroundColor: ringColor.withAlpha(25),
                    color: ringColor,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      '$pct%',
                      style: tt.titleMedium?.copyWith(
                        color: ringColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          if (!isLoading && !data.sinRegistros)
            Text(
              '${data.tomadasHoy}/${data.totalHoy} tomas',
              style: tt.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tarjeta Recordatorio ──────────────────────────────────────────────────────

class _CardRecordatorio extends StatelessWidget {
  const _CardRecordatorio({required this.controller, required this.onTap});

  final DashboardController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final proxima = controller.data.proximaToma;
    final isLoading = controller.isLoading;

    return _IlluCard(
      bg: _kTeal,
      svgAsset: 'assets/il_medicacion_empty.svg',
      onTap: onTap,
      svgHeight: 120,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.alarm_rounded, color: const Color(0xFF00697A), size: 14),
              const SizedBox(width: 5),
              Text(
                'Recordatorio',
                style: tt.labelMedium?.copyWith(
                  color: const Color(0xFF00697A),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            Text('Cargando…', style: tt.bodySmall)
          else if (proxima == null)
            Text(
              controller.data.sinRegistros
                  ? 'Sin recordatorios'
                  : '¡Tomas completas!',
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.3,
              ),
            )
          else ...[
            Text(
              proxima.medicamento,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              proxima.dosis,
              style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(200),
                borderRadius: AppRadius.fullBr,
              ),
              child: Text(
                _cuentaAtras(proxima.toma.hora),
                style: tt.labelSmall?.copyWith(
                  color: AppColors.accentDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Devuelve "en X min", "en Xh Ym" o "ahora".
String _cuentaAtras(String hora) {
  final parts = hora.split(':');
  if (parts.length < 2) return hora;
  final hh = int.tryParse(parts[0]) ?? 0;
  final mm = int.tryParse(parts[1]) ?? 0;
  final now = DateTime.now();
  final diff = (hh * 60 + mm) - (now.hour * 60 + now.minute);
  if (diff <= 0) return 'ahora';
  if (diff < 60) return 'en $diff min';
  final h = diff ~/ 60;
  final m = diff % 60;
  return m == 0 ? 'en ${h}h' : 'en ${h}h ${m}m';
}

// ── Tarjeta Triaje ────────────────────────────────────────────────────────────

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
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return DateFormat('d MMM', 'es').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final data = controller.data;
    final nivel = data.tieneTriaje ? data.ultimoTriajeNivel! : null;

    return _IlluCard(
      bg: _kBlue,
      svgAsset: 'assets/il_triaje_empty.svg',
      onTap: data.tieneTriaje ? onHistorialTap : onNuevoTriajeTap,
      svgHeight: 115,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded, color: const Color(0xFF1565C0), size: 14),
              const SizedBox(width: 5),
              Text(
                'Triaje',
                style: tt.labelMedium?.copyWith(
                  color: const Color(0xFF1565C0),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!data.tieneTriaje)
            Text(
              'Sin registros',
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            )
          else ...[
            UrgencyBadge(nivel!, size: BadgeSize.small),
            const SizedBox(height: 6),
            Text(
              _fechaRelativa(data.ultimoTriajeFecha!),
              style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                data.tieneTriaje ? 'Ver historial' : 'Iniciar triaje',
                style: tt.labelSmall?.copyWith(
                  color: const Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_forward_rounded,
                  color: const Color(0xFF1565C0), size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sección "Tips para ti" ────────────────────────────────────────────────────

class _SeccionTips extends StatefulWidget {
  const _SeccionTips();

  @override
  State<_SeccionTips> createState() => _SeccionTipsState();
}

class _SeccionTipsState extends State<_SeccionTips> {
  final _tipController = TipController();
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      _cargar();
    }
  }

  @override
  void dispose() {
    _tipController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      final usuario = doc.exists
          ? UsuarioModel.fromFirestore(doc)
          : UsuarioModel(
              uid: uid,
              nombre: '',
              correo: '',
              sexo: Sexo.prefierNoDecir,
              fechaNacimiento: DateTime(2000),
              creadoEn: DateTime.now(),
            );
      if (mounted) await _tipController.cargar(uid, usuario);
    } catch (e) {
      debugPrint('_SeccionTips._cargar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _tipController,
      builder: (context2, _) {
        final tips = _tipController.tipsHoy;
        final cargando = _tipController.cargando;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(25),
                      borderRadius: AppRadius.smBr,
                    ),
                    child: const Icon(Icons.lightbulb_rounded,
                        color: AppColors.accent, size: 16),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Tips para ti',
                    style: tt.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (cargando)
              _TipCardEsqueleto()
            else if (_tipController.status == TipStatus.error)
              Text(
                _tipController.errorMessage ?? 'No se pudieron cargar los tips.',
                style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
              )
            else if (tips.isEmpty)
              const SizedBox.shrink()
            else
              ...tips.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TipCardCompacta(tip: tip),
                  )),
          ],
        );
      },
    );
  }
}

Color _colorCategoria(TipCategoria cat) => switch (cat) {
      TipCategoria.nutricion => const Color(0xFFE8F5E9),
      TipCategoria.actividadFisica => const Color(0xFFE3F2FD),
      TipCategoria.bienestarMental => const Color(0xFFF3E5F5),
      TipCategoria.sueno => const Color(0xFFEDE7F6),
      TipCategoria.hidratacion => const Color(0xFFE0F7FA),
      TipCategoria.prevencion => const Color(0xFFFFF3E0),
      TipCategoria.medicacion => const Color(0xFFFFEBEE),
    };

Color _iconCategoria(TipCategoria cat) => switch (cat) {
      TipCategoria.nutricion => const Color(0xFF2E7D32),
      TipCategoria.actividadFisica => const Color(0xFF1565C0),
      TipCategoria.bienestarMental => const Color(0xFF6A1B9A),
      TipCategoria.sueno => const Color(0xFF4527A0),
      TipCategoria.hidratacion => const Color(0xFF00838F),
      TipCategoria.prevencion => const Color(0xFFE65100),
      TipCategoria.medicacion => const Color(0xFFC62828),
    };

class _TipCardCompacta extends StatelessWidget {
  const _TipCardCompacta({required this.tip});
  final TipModel tip;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bgIcon = _colorCategoria(tip.categoria);
    final colorIcon = _iconCategoria(tip.categoria);

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgBr,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgBr,
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgIcon,
                borderRadius: AppRadius.smBr,
              ),
              child: Icon(tip.categoria.icon, color: colorIcon, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.categoria.label.toUpperCase(),
                    style: TextStyle(
                      color: colorIcon,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tip.texto,
                    style: tt.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCardEsqueleto extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBr,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.smBr,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            height: 14,
            width: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.smBr,
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
                nombre: 'SAMU',
                numero: '106',
                icono: Icons.local_hospital_rounded),
            Divider(),
            _ContactoEmergencia(
                nombre: 'Bomberos',
                numero: '116',
                icono: Icons.fire_truck_rounded),
            Divider(),
            _ContactoEmergencia(
                nombre: 'Policía',
                numero: '105',
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
      title: Text(nombre, style: Theme.of(context).textTheme.titleSmall),
      trailing: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.phone_rounded, size: 16),
        label: Text(numero),
        style: TextButton.styleFrom(foregroundColor: AppColors.urgencyHigh),
      ),
    );
  }
}
