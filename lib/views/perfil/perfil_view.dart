import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/perfil_controller.dart';
import '../../models/usuario_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

// ── Colores locales del design system ────────────────────────────────────────
const _kCardBorder = AppColors.cardBorder;
const _kCardRadius = 18.0;
const _kIconBoxRadius = 12.0;

class PerfilView extends StatefulWidget {
  const PerfilView({super.key});

  @override
  State<PerfilView> createState() => _PerfilViewState();
}

class _PerfilViewState extends State<PerfilView> {
  final _controller = PerfilController();
  bool _editando = false;

  @override
  void initState() {
    super.initState();
    _controller.cargar(_uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleEditar() => setState(() => _editando = !_editando);

  void _onGuardado() {
    setState(() => _editando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil actualizado correctamente.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onErrorGuardado() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No se pudo guardar. Intenta de nuevo.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.urgencyHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Mi perfil'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              if (!_controller.listo) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: GestureDetector(
                  onTap: _controller.guardando ? null : _toggleEditar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLightBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _editando ? 'Cancelar' : 'Editar',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          if (_controller.cargando) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (_controller.error != null && _controller.usuario == null) {
            return _EstadoError(
              mensaje: _controller.error!,
              onReintentar: () => _controller.cargar(_uid),
            );
          }
          if (_controller.usuario == null) return const SizedBox.shrink();

          return _editando
              ? _FormEditar(
                  usuario: _controller.usuario!,
                  controller: _controller,
                  onGuardado: _onGuardado,
                  onError: _onErrorGuardado,
                )
              : _VistaLectura(usuario: _controller.usuario!);
        },
      ),
    );
  }
}

// ── Vista de lectura ──────────────────────────────────────────────────────────

class _VistaLectura extends StatelessWidget {
  const _VistaLectura({required this.usuario});
  final UsuarioModel usuario;

  String _formatFecha(DateTime fecha) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }

  int get _edad {
    final hoy = DateTime.now();
    int e = hoy.year - usuario.fechaNacimiento.year;
    if (hoy.month < usuario.fechaNacimiento.month ||
        (hoy.month == usuario.fechaNacimiento.month &&
            hoy.day < usuario.fechaNacimiento.day)) { e--; }
    return e;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          _HeroHeader(usuario: usuario),

          // ── Stats ─────────────────────────────────────────────────────────
          _StatsGrid(edad: _edad, usuario: usuario),

          // ── Cuerpo ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),

                // Card datos personales
                _Card(
                  children: [
                    _CardHeader(
                      icono: Icons.person_outline_rounded,
                      label: 'Datos personales',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CampoFila(
                      icono: Icons.wc_rounded,
                      iconBg: AppColors.catPurpleBg,
                      iconColor: AppColors.catPurpleText,
                      label: 'Sexo',
                      valor: usuario.sexo.label,
                    ),
                    _Divisor(),
                    _CampoFila(
                      icono: Icons.cake_rounded,
                      iconBg: AppColors.catYellowBg,
                      iconColor: AppColors.catYellowText,
                      label: 'Fecha de nacimiento',
                      valor: _formatFecha(usuario.fechaNacimiento),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Card información de salud
                _Card(
                  children: [
                    _CardHeader(
                      icono: Icons.favorite_border_rounded,
                      label: 'Información de salud',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CampoFila(
                      icono: Icons.water_drop_rounded,
                      iconBg: const Color(0xFFFFEBEE),
                      iconColor: const Color(0xFFE53935),
                      label: 'Grupo sanguíneo',
                      valor: usuario.grupoSanguineo ?? 'Sin registros',
                    ),
                    _Divisor(),
                    _CampoFila(
                      icono: Icons.monitor_heart_rounded,
                      iconBg: AppColors.catYellowBg,
                      iconColor: AppColors.catYellowText,
                      label: 'Enfermedades / condiciones',
                      valor: usuario.enfermedades.isNotEmpty
                          ? usuario.enfermedades.join(', ')
                          : 'Sin registros',
                    ),
                    _Divisor(),
                    _CampoFila(
                      icono: Icons.warning_amber_rounded,
                      iconBg: AppColors.catRedBg,
                      iconColor: AppColors.catRedText,
                      label: 'Alergias',
                      valor: usuario.alergias.isNotEmpty
                          ? usuario.alergias.join(', ')
                          : 'Sin registros',
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Card "Ver mi reporte"
                _CardReporte(),

                const SizedBox(height: AppSpacing.sm),

                // Disclaimer
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(_kCardRadius),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightBg,
                          borderRadius:
                              BorderRadius.circular(_kIconBoxRadius),
                        ),
                        child: const Icon(Icons.info_outline_rounded,
                            size: 15, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Esta información la usa el asistente IA para darte orientación '
                          'personalizada. No reemplaza la evaluación médica.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Cerrar sesión — centrado, texto rojo
                Center(child: _BotonCerrarSesion()),
                SizedBox(
                    height: AppSpacing.lg +
                        MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.usuario});
  final UsuarioModel usuario;

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Avatar circular 56px con gradiente morado
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6B48FF), Color(0xFFA78BFA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                _iniciales(usuario.nombre),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuario.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  usuario.correo,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLightBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo_csjb.png',
                          height: 14, fit: BoxFit.contain),
                      const SizedBox(width: 4),
                      const Text(
                        'Clínica San Juan Bautista',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats grid 3 columnas ─────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.edad, required this.usuario});
  final int edad;
  final UsuarioModel usuario;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              valor: '$edad',
              label: 'AÑOS',
              bg: AppColors.catPurpleBg,
              textColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatBox(
              valor: usuario.sexo.label,
              label: 'SEXO',
              bg: AppColors.surfaceVariant,
              textColor: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatBox(
              valor: usuario.grupoSanguineo ?? '—',
              label: 'SANGRE',
              bg: AppColors.catGreenBg,
              textColor: AppColors.catGreenText,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.valor,
    required this.label,
    required this.bg,
    required this.textColor,
  });
  final String valor;
  final String label;
  final Color bg;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card base ─────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ── Card header con ícono en caja ─────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icono, required this.label});
  final IconData icono;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryLightBg,
            borderRadius: BorderRadius.circular(_kIconBoxRadius),
          ),
          child: Icon(icono, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Fila de campo ─────────────────────────────────────────────────────────────

class _CampoFila extends StatelessWidget {
  const _CampoFila({
    required this.icono,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.valor,
  });
  final IconData icono;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(_kIconBoxRadius),
            ),
            child: Icon(icono, size: 20, color: iconColor),
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
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Divisor sutil ─────────────────────────────────────────────────────────────

class _Divisor extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFF5F3FF),
      );
}

// ── Card "Ver mi reporte" ─────────────────────────────────────────────────────

class _CardReporte extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => AppRoutes.push(context, AppRoutes.reporte),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(color: _kCardBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryLightBg,
                borderRadius: BorderRadius.circular(_kIconBoxRadius),
              ),
              child: const Icon(Icons.assessment_rounded,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ver mi reporte',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Historial de salud, medicación y triajes',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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

// ── Formulario de edición ─────────────────────────────────────────────────────

class _FormEditar extends StatefulWidget {
  const _FormEditar({
    required this.usuario,
    required this.controller,
    required this.onGuardado,
    required this.onError,
  });

  final UsuarioModel usuario;
  final PerfilController controller;
  final VoidCallback onGuardado;
  final VoidCallback onError;

  @override
  State<_FormEditar> createState() => _FormEditarState();
}

class _FormEditarState extends State<_FormEditar> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _grupoCtrl;
  late final TextEditingController _enfermedadesCtrl;
  late final TextEditingController _alergiasCtrl;
  late Sexo _sexo;

  static const _gruposSanguineos = [
    'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−',
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombreCtrl = TextEditingController(text: u.nombre);
    _grupoCtrl = TextEditingController(text: u.grupoSanguineo ?? '');
    _enfermedadesCtrl = TextEditingController(text: u.enfermedades.join(', '));
    _alergiasCtrl = TextEditingController(text: u.alergias.join(', '));
    _sexo = u.sexo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _grupoCtrl.dispose();
    _enfermedadesCtrl.dispose();
    _alergiasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    List<String> parseItems(String raw) => raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final actualizado = widget.usuario.copyWith(
      nombre: _nombreCtrl.text.trim(),
      sexo: _sexo,
      grupoSanguineo: _grupoCtrl.text.trim().isEmpty
          ? null
          : _grupoCtrl.text.trim(),
      enfermedades: parseItems(_enfermedadesCtrl.text),
      alergias: parseItems(_alergiasCtrl.text),
    );

    final ok = await widget.controller.guardar(_uid, actualizado);
    if (!mounted) return;
    if (ok) {
      widget.onGuardado();
    } else {
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottomPadding + AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6B48FF), Color(0xFFA78BFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _iniciales(widget.usuario.nombre),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            _EncabezadoSeccion(icono: Icons.person_outline_rounded, titulo: 'Datos personales'),
            const SizedBox(height: AppSpacing.sm),

            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            Text('Sexo',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: Sexo.values.map((s) {
                final activo = _sexo == s;
                return ChoiceChip(
                  label: Text(s.label),
                  selected: activo,
                  onSelected: (_) => setState(() => _sexo = s),
                  selectedColor: AppColors.primary.withAlpha(20),
                  side: BorderSide(
                    color: activo ? AppColors.primary : AppColors.surfaceVariant,
                  ),
                  labelStyle: textTheme.labelMedium?.copyWith(
                    color: activo ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            _EncabezadoSeccion(icono: Icons.favorite_border_rounded, titulo: 'Información de salud'),
            const SizedBox(height: AppSpacing.sm),

            DropdownButtonFormField<String>(
              initialValue: _gruposSanguineos.contains(_grupoCtrl.text) ? _grupoCtrl.text : null,
              decoration: const InputDecoration(labelText: 'Grupo sanguíneo (opcional)'),
              items: _gruposSanguineos
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _grupoCtrl.text = v ?? ''),
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _enfermedadesCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Enfermedades / condiciones (opcional)',
                hintText: 'Ej: Diabetes tipo 2, hipertensión',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _alergiasCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alergias (opcional)',
                hintText: 'Ej: Penicilina, mariscos',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.lgBr,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Tu información de salud es privada y solo la verás tú.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, child) {
                return AppButton(
                  label: 'Guardar cambios',
                  onPressed: widget.controller.guardando ? null : _guardar,
                  loading: widget.controller.guardando,
                  icon: const Icon(Icons.check_rounded),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }
}

class _EncabezadoSeccion extends StatelessWidget {
  const _EncabezadoSeccion({required this.icono, required this.titulo});
  final IconData icono;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(titulo,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.primary)),
      ],
    );
  }
}

// ── Estado de error ───────────────────────────────────────────────────────────

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.urgencyHigh),
            const SizedBox(height: AppSpacing.md),
            Text(mensaje,
                style: Theme.of(context).textTheme.bodyMedium,
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

// ── Botón cerrar sesión ───────────────────────────────────────────────────────

class _BotonCerrarSesion extends StatefulWidget {
  @override
  State<_BotonCerrarSesion> createState() => _BotonCerrarSesionState();
}

class _BotonCerrarSesionState extends State<_BotonCerrarSesion> {
  final _authController = AuthController();
  bool _cerrando = false;

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  Future<void> _confirmarYCerrar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Seguro que deseas cerrar sesión? Podrás volver a ingresar con este usuario u otro distinto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    setState(() => _cerrando = true);
    await _authController.logout();
    if (!mounted) return;
    AppRoutes.pushAndRemoveAll(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _cerrando ? null : _confirmarYCerrar,
      icon: _cerrando
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.danger),
            )
          : const Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
      label: const Text(
        'Cerrar sesión',
        style: TextStyle(
          color: AppColors.danger,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
    );
  }
}
