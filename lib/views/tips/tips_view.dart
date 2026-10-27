import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/tip_controller.dart';
import '../../models/tip_model.dart';
import '../../models/usuario_model.dart';
import '../../utils/theme.dart';
import '../../widgets/app_card.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

class TipsView extends StatefulWidget {
  const TipsView({super.key});

  @override
  State<TipsView> createState() => _TipsViewState();
}

class _TipsViewState extends State<TipsView> {
  final _controller = TipController();
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final usuario = await _leerUsuario(uid);
    if (!mounted) return;
    await _controller.cargar(uid, usuario);
  }

  Future<UsuarioModel> _leerUsuario(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      if (doc.exists) return UsuarioModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('TipsView._leerUsuario: $e');
    }
    // Fallback mínimo si Firestore falla
    final user = FirebaseAuth.instance.currentUser!;
    return UsuarioModel(
      uid: uid,
      nombre: user.displayName ?? '',
      correo: user.email ?? '',
      sexo: Sexo.prefierNoDecir,
      fechaNacimiento: DateTime(2000),
      creadoEn: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Tips de Salud'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context2, _) {
          if (_controller.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.status == TipStatus.error) {
            return _ErrorView(
              mensaje: _controller.errorMessage ?? 'Error desconocido.',
              onReintentar: _cargar,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _cargar,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (_controller.tipsHoy.isNotEmpty)
                  _TarjetaTipDestacada(tip: _controller.tipsHoy.first),
                if (_controller.tipsHoy.length > 1) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SeccionHistorial(tips: _controller.tipsHoy),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Tarjeta destacada del tip del día ────────────────────────────────────────

class _TarjetaTipDestacada extends StatelessWidget {
  const _TarjetaTipDestacada({required this.tip});
  final TipModel tip;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xlBr,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tip.categoria.icon,
                  color: AppColors.onPrimary.withAlpha(200), size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'TIP DEL DÍA',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.onPrimary.withAlpha(180),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withAlpha(30),
                  borderRadius: AppRadius.fullBr,
                ),
                child: Text(
                  tip.categoria.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tip.texto,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            DateFormat("d 'de' MMMM", 'es').format(tip.fecha),
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.onPrimary.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Historial de tips recientes ───────────────────────────────────────────────

class _SeccionHistorial extends StatelessWidget {
  const _SeccionHistorial({required this.tips});
  final List<TipModel> tips;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // El primer elemento ya se muestra como tarjeta destacada
    final anteriores = tips.skip(1).toList();
    if (anteriores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tips recientes',
          style: textTheme.titleSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...anteriores.map((tip) => _TarjetaTipHistorial(tip: tip)),
      ],
    );
  }
}

class _TarjetaTipHistorial extends StatelessWidget {
  const _TarjetaTipHistorial({required this.tip});
  final TipModel tip;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.mdBr,
              ),
              child: Icon(tip.categoria.icon,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tip.categoria.label,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('d MMM', 'es').format(tip.fecha),
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.texto,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.mensaje, required this.onReintentar});
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
                size: 48, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.md),
            Text(
              mensaje,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
