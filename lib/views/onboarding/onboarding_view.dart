import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controllers/onboarding_controller.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

// ── Opciones fijas ────────────────────────────────────────────────────────────

const _opcionesEnfermedades = [
  'Diabetes',
  'Hipertensión',
  'Asma',
  'Artritis',
  'Tiroides',
  'Ninguna',
  'Otra',
];

const _opcionesAlergias = [
  'A medicamentos',
  'A algún alimento',
  'Al polvo / ácaros',
  'Al látex',
  'Ninguna',
  'Otra',
];

const _gruposSanguineos = [
  'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−', 'No lo sé',
];

// ── Vista principal ───────────────────────────────────────────────────────────

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with SingleTickerProviderStateMixin {
  final _controller = OnboardingController();
  final _pageCtrl = PageController();

  // 0=presentación  1=sobre ti  2=datos salud  3=personaliza  4=cómo usar
  int _paso = 0;
  static const _totalPasos = 5;

  // ── Paso 1 — Sobre ti ──────────────────────────────────────────────────────
  DateTime? _fechaNacimiento;
  String? _embarazoLactancia;
  String? _preferenciaExplicacion;
  String? _limitacionComunicacion;

  // ── Paso 2 — Datos de salud ────────────────────────────────────────────────
  String? _grupoSanguineo;
  final Set<String> _enfermedades = {};
  final _otraCondicionCtrl = TextEditingController();
  String? _tipoCondicion; // 'diagnosticada' | 'sintomas'
  final Set<String> _alergias = {};
  final _otraAlergiaCtrl = TextEditingController();
  final _alergiaMedDetalleCtrl = TextEditingController();
  final _alergiaMedReaccionCtrl = TextEditingController();
  bool _tomaMedicacion = false;
  // Hasta 3 medicamentos: cada uno tiene nombre, dosis, frecuencia, tipo
  final List<Map<String, TextEditingController>> _medControllers = [];
  final List<String?> _medFrecuencia = [];
  final List<String?> _medTipo = [];

  // ── Paso 3 — Personaliza asistente ────────────────────────────────────────
  final Set<String> _categoriasTips = {};
  String? _objetivoSalud;
  String? _actividadFisica;

  late final AnimationController _welcomeAnim;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_uid)
        .update({'preferenciasSalud': <String, dynamic>{'visto': true}})
        .catchError((_) {});

    _welcomeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _welcomeAnim, curve: Curves.easeOut);

    // Inicializar con 1 medicamento vacío
    _agregarMedicamento();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageCtrl.dispose();
    _otraCondicionCtrl.dispose();
    _otraAlergiaCtrl.dispose();
    _alergiaMedDetalleCtrl.dispose();
    _alergiaMedReaccionCtrl.dispose();
    for (final m in _medControllers) {
      m['nombre']!.dispose();
      m['dosis']!.dispose();
    }
    _welcomeAnim.dispose();
    super.dispose();
  }

  void _agregarMedicamento() {
    if (_medControllers.length >= 3) return;
    _medControllers.add({
      'nombre': TextEditingController(),
      'dosis': TextEditingController(),
    });
    _medFrecuencia.add(null);
    _medTipo.add(null);
  }

  void _eliminarMedicamento(int idx) {
    _medControllers[idx]['nombre']!.dispose();
    _medControllers[idx]['dosis']!.dispose();
    setState(() {
      _medControllers.removeAt(idx);
      _medFrecuencia.removeAt(idx);
      _medTipo.removeAt(idx);
    });
  }

  void _siguiente() {
    if (_paso < _totalPasos - 1) {
      setState(() => _paso++);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _terminar();
    }
  }

  Future<void> _omitir() async {
    await _controller.guardar(uid: _uid, enfermedades: [], alergias: []);
    if (!mounted) return;
    AppRoutes.pushAndRemoveAll(context, AppRoutes.dashboard);
  }

  Future<void> _terminar() async {
    final enfermedadesFinal = _resolverItems(
      seleccion: _enfermedades,
      textoOtra: _otraCondicionCtrl.text.trim(),
      claveOtra: 'Otra',
      claveNinguna: 'Ninguna',
    );
    final alergiasFinal = _resolverItems(
      seleccion: _alergias,
      textoOtra: _otraAlergiaCtrl.text.trim(),
      claveOtra: 'Otra',
      claveNinguna: 'Ninguna',
    );

    // Construir lista de medicamentos
    final medicamentos = <Map<String, String?>>[];
    if (_tomaMedicacion) {
      for (var i = 0; i < _medControllers.length; i++) {
        final nombre = _medControllers[i]['nombre']!.text.trim();
        if (nombre.isEmpty) continue;
        medicamentos.add({
          'nombre': nombre,
          'dosis': _medControllers[i]['dosis']!.text.trim().isNotEmpty
              ? _medControllers[i]['dosis']!.text.trim()
              : null,
          'frecuencia': _medFrecuencia[i] ?? 'Una vez al día',
          'tipo': _medTipo[i],
        });
      }
    }

    // "No lo sé" equivale a null en Firestore
    final grupoFinal = (_grupoSanguineo == 'No lo sé') ? null : _grupoSanguineo;

    await _controller.guardar(
      uid: _uid,
      grupoSanguineo: grupoFinal,
      enfermedades: enfermedadesFinal,
      alergias: alergiasFinal,
      otraCondicionDescripcion: _otraCondicionCtrl.text.trim().isNotEmpty
          ? _otraCondicionCtrl.text.trim()
          : null,
      tipoCondicion: _tipoCondicion,
      alergiaMedicamentoDetalle: _alergias.contains('A medicamentos')
          ? _alergiaMedDetalleCtrl.text.trim()
          : null,
      alergiaMedicamentoReaccion: _alergias.contains('A medicamentos')
          ? _alergiaMedReaccionCtrl.text.trim()
          : null,
      medicamentos: medicamentos.isNotEmpty ? medicamentos : null,
      embarazoLactancia: _embarazoLactancia,
      preferenciaExplicacion: _preferenciaExplicacion,
      limitacionComunicacion: _limitacionComunicacion,
      categoriasTips: _categoriasTips.isNotEmpty ? _categoriasTips.toList() : null,
      objetivoSalud: _objetivoSalud,
      actividadFisica: _actividadFisica,
    );

    if (!mounted) return;
    if (_controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.error!),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.urgencyHigh,
        ),
      );
    }
    AppRoutes.pushAndRemoveAll(context, AppRoutes.dashboard);
  }

  List<String> _resolverItems({
    required Set<String> seleccion,
    required String textoOtra,
    required String claveOtra,
    required String claveNinguna,
  }) {
    if (seleccion.contains(claveNinguna)) return [];
    final items = seleccion.where((s) => s != claveOtra).toList();
    if (seleccion.contains(claveOtra) && textoOtra.isNotEmpty) {
      items.add(textoOtra);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            _IndicadorPasos(pasoActual: _paso, total: _totalPasos),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // ── 0: Presentación ──────────────────────────────────────
                  _PasoPresentacion(
                    fadeIn: _fadeIn,
                    onEmpezar: _siguiente,
                  ),

                  // ── 1: Sobre ti (nuevo) ───────────────────────────────────
                  _PasoSobreTi(
                    fechaNacimiento: _fechaNacimiento,
                    onFechaNacimiento: (d) => setState(() => _fechaNacimiento = d),
                    sexoUsuario: null, // se leerá del perfil si está disponible
                    embarazoLactancia: _embarazoLactancia,
                    onEmbarazo: (v) => setState(() => _embarazoLactancia = v),
                    preferenciaExplicacion: _preferenciaExplicacion,
                    onPrefExplicacion: (v) => setState(() => _preferenciaExplicacion = v),
                    limitacionComunicacion: _limitacionComunicacion,
                    onLimitacion: (v) => setState(() => _limitacionComunicacion = v),
                    onOmitir: _omitir,
                    onSiguiente: _siguiente,
                  ),

                  // ── 2: Datos de salud ─────────────────────────────────────
                  _PasoDatosSalud(
                    grupoSanguineo: _grupoSanguineo,
                    onGrupo: (g) => setState(() => _grupoSanguineo = g),
                    enfermedades: _enfermedades,
                    otraCondicionCtrl: _otraCondicionCtrl,
                    tipoCondicion: _tipoCondicion,
                    onTipoCondicion: (v) => setState(() => _tipoCondicion = v),
                    onToggleEnfermedad: (op) => setState(() {
                      if (op == 'Ninguna') {
                        _enfermedades..clear()..add('Ninguna');
                      } else {
                        _enfermedades.remove('Ninguna');
                        _enfermedades.contains(op)
                            ? _enfermedades.remove(op)
                            : _enfermedades.add(op);
                      }
                    }),
                    alergias: _alergias,
                    otraAlergiaCtrl: _otraAlergiaCtrl,
                    alergiaMedDetalleCtrl: _alergiaMedDetalleCtrl,
                    alergiaMedReaccionCtrl: _alergiaMedReaccionCtrl,
                    onToggleAlergia: (op) => setState(() {
                      if (op == 'Ninguna') {
                        _alergias..clear()..add('Ninguna');
                      } else {
                        _alergias.remove('Ninguna');
                        _alergias.contains(op)
                            ? _alergias.remove(op)
                            : _alergias.add(op);
                      }
                    }),
                    tomaMedicacion: _tomaMedicacion,
                    onToggleMedicacion: (v) => setState(() => _tomaMedicacion = v),
                    medControllers: _medControllers,
                    medFrecuencia: _medFrecuencia,
                    medTipo: _medTipo,
                    onSetFrecuencia: (i, v) => setState(() => _medFrecuencia[i] = v),
                    onSetTipo: (i, v) => setState(() => _medTipo[i] = v),
                    onAgregarMed: () => setState(_agregarMedicamento),
                    onEliminarMed: _eliminarMedicamento,
                    onOmitir: _omitir,
                    onSiguiente: _siguiente,
                  ),

                  // ── 3: Personaliza asistente (nuevo) ─────────────────────
                  _PasoPersonaliza(
                    categoriasTips: _categoriasTips,
                    onToggleCategoria: (c) => setState(() {
                      _categoriasTips.contains(c)
                          ? _categoriasTips.remove(c)
                          : _categoriasTips.add(c);
                    }),
                    objetivoSalud: _objetivoSalud,
                    onObjetivo: (v) => setState(() => _objetivoSalud = v),
                    actividadFisica: _actividadFisica,
                    onActividad: (v) => setState(() => _actividadFisica = v),
                    onOmitir: _omitir,
                    onSiguiente: _siguiente,
                  ),

                  // ── 4: Cómo usar ──────────────────────────────────────────
                  _PasoComoUsar(
                    onComenzar: _terminar,
                    cargando: _controller.guardando,
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

// ── Indicador de pasos ────────────────────────────────────────────────────────

class _IndicadorPasos extends StatelessWidget {
  const _IndicadorPasos({required this.pasoActual, required this.total});
  final int pasoActual;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Row(
        children: List.generate(total, (i) {
          final activo = i <= pasoActual;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: activo ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: AppRadius.fullBr,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Paso 0: Presentación ──────────────────────────────────────────────────────

class _PasoPresentacion extends StatelessWidget {
  const _PasoPresentacion({
    required this.fadeIn,
    required this.onEmpezar,
  });

  final Animation<double> fadeIn;
  final VoidCallback onEmpezar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return FadeTransition(
      opacity: fadeIn,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          children: [
            SvgPicture.asset(
              'assets/il_onboarding.svg',
              height: (screenHeight * 0.22).clamp(120.0, 200.0),
              fit: BoxFit.contain,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/logo_csjb.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Clínica San Juan Bautista',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tu orientación médica,\nsiempre disponible',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._capacidades.map((c) => _CapacidadRow(
                  icono: c.$1,
                  color: c.$2,
                  bg: c.$3,
                  texto: c.$4,
                )),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE5FF),
                borderRadius: AppRadius.lgBr,
                border: Border.all(
                  color: AppColors.primary.withAlpha(40),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/logo_csjb.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Esta app no reemplaza una consulta médica ni realiza diagnósticos. '
                      'Es una herramienta de orientación informativa de la Clínica San Juan Bautista.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Empezar',
              onPressed: onEmpezar,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }

  static const _capacidades = [
    (
      Icons.smart_toy_rounded,
      Color(0xFF5B2D8E),
      Color(0xFFEDE5FF),
      'Asistente IA disponible 24/7 para orientarte sobre síntomas y salud',
    ),
    (
      Icons.monitor_heart_rounded,
      Color(0xFFF47920),
      Color(0xFFFFF3E0),
      'Triaje informativo: evalúa tus síntomas y sugiere nivel de atención',
    ),
    (
      Icons.people_outline_rounded,
      Color(0xFF00697A),
      Color(0xFFD1EFEC),
      'Directorio de médicos de la Clínica San Juan Bautista por especialidad',
    ),
    (
      Icons.medication_rounded,
      Color(0xFF2E7D32),
      Color(0xFFE8F5E9),
      'Recordatorios de medicación y seguimiento de tu adherencia',
    ),
  ];
}

class _CapacidadRow extends StatelessWidget {
  const _CapacidadRow({
    required this.icono,
    required this.color,
    required this.bg,
    required this.texto,
  });

  final IconData icono;
  final Color color;
  final Color bg;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdBr),
            child: Icon(icono, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paso 1: Sobre ti (nuevo) ──────────────────────────────────────────────────

class _PasoSobreTi extends StatelessWidget {
  const _PasoSobreTi({
    required this.fechaNacimiento,
    required this.onFechaNacimiento,
    required this.sexoUsuario,
    required this.embarazoLactancia,
    required this.onEmbarazo,
    required this.preferenciaExplicacion,
    required this.onPrefExplicacion,
    required this.limitacionComunicacion,
    required this.onLimitacion,
    required this.onOmitir,
    required this.onSiguiente,
  });

  final DateTime? fechaNacimiento;
  final ValueChanged<DateTime> onFechaNacimiento;
  final String? sexoUsuario;
  final String? embarazoLactancia;
  final ValueChanged<String?> onEmbarazo;
  final String? preferenciaExplicacion;
  final ValueChanged<String?> onPrefExplicacion;
  final String? limitacionComunicacion;
  final ValueChanged<String?> onLimitacion;
  final VoidCallback onOmitir;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mostrarEmbarazo = sexoUsuario == null || sexoUsuario == 'Femenino';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2 de 5',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sobre ti',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Esto ayuda al asistente a entenderte mejor.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Fecha de nacimiento
          _Etiqueta(texto: 'Fecha de nacimiento', icono: Icons.cake_rounded),
          const SizedBox(height: AppSpacing.sm),
          _DatePickerField(
            value: fechaNacimiento,
            onChanged: onFechaNacimiento,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Embarazo / lactancia (solo si femenino o no definido)
          if (mostrarEmbarazo) ...[
            _Etiqueta(
              texto: '¿Estás embarazada o en periodo de lactancia?',
              icono: Icons.pregnant_woman_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ChipsUnico(
              opciones: const ['Sí', 'No', 'No aplica', 'Prefiero no responder'],
              seleccion: embarazoLactancia,
              onSeleccion: onEmbarazo,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Preferencia de explicaciones
          _Etiqueta(
            texto: '¿Cómo prefieres recibir las explicaciones?',
            icono: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChipsUnico(
            opciones: const [
              'Simples y directas',
              'Con más detalle',
              'Con pasos concretos',
            ],
            seleccion: preferenciaExplicacion,
            onSeleccion: onPrefExplicacion,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Limitación de comunicación
          _Etiqueta(
            texto: '¿Tienes alguna limitación para comunicarte?',
            icono: Icons.accessibility_new_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChipsUnico(
            opciones: const [
              'Ninguna',
              'Visual',
              'Auditiva',
              'Del habla',
              'Otra',
            ],
            seleccion: limitacionComunicacion,
            onSeleccion: onLimitacion,
          ),
          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: 'Continuar',
            onPressed: onSiguiente,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: onOmitir,
              child: Text(
                'Omitir por ahora',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paso 2: Datos de salud ────────────────────────────────────────────────────

class _PasoDatosSalud extends StatelessWidget {
  const _PasoDatosSalud({
    required this.grupoSanguineo,
    required this.onGrupo,
    required this.enfermedades,
    required this.otraCondicionCtrl,
    required this.tipoCondicion,
    required this.onTipoCondicion,
    required this.onToggleEnfermedad,
    required this.alergias,
    required this.otraAlergiaCtrl,
    required this.alergiaMedDetalleCtrl,
    required this.alergiaMedReaccionCtrl,
    required this.onToggleAlergia,
    required this.tomaMedicacion,
    required this.onToggleMedicacion,
    required this.medControllers,
    required this.medFrecuencia,
    required this.medTipo,
    required this.onSetFrecuencia,
    required this.onSetTipo,
    required this.onAgregarMed,
    required this.onEliminarMed,
    required this.onOmitir,
    required this.onSiguiente,
  });

  final String? grupoSanguineo;
  final ValueChanged<String?> onGrupo;
  final Set<String> enfermedades;
  final TextEditingController otraCondicionCtrl;
  final String? tipoCondicion;
  final ValueChanged<String?> onTipoCondicion;
  final ValueChanged<String> onToggleEnfermedad;
  final Set<String> alergias;
  final TextEditingController otraAlergiaCtrl;
  final TextEditingController alergiaMedDetalleCtrl;
  final TextEditingController alergiaMedReaccionCtrl;
  final ValueChanged<String> onToggleAlergia;
  final bool tomaMedicacion;
  final ValueChanged<bool> onToggleMedicacion;
  final List<Map<String, TextEditingController>> medControllers;
  final List<String?> medFrecuencia;
  final List<String?> medTipo;
  final void Function(int, String?) onSetFrecuencia;
  final void Function(int, String?) onSetTipo;
  final VoidCallback onAgregarMed;
  final ValueChanged<int> onEliminarMed;
  final VoidCallback onOmitir;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3 de 5',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Cuéntanos sobre tu salud',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Esta información ayuda al asistente IA a orientarte mejor. '
            'Todos los campos son opcionales.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Grupo sanguíneo ───────────────────────────────────────────────
          _Etiqueta(texto: 'Grupo sanguíneo', icono: Icons.water_drop_rounded),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _gruposSanguineos.map((g) {
              final activo = grupoSanguineo == g;
              return ChoiceChip(
                label: Text(g),
                selected: activo,
                onSelected: (_) => onGrupo(activo ? null : g),
                selectedColor: AppColors.primary.withAlpha(20),
                side: BorderSide(
                  color: activo ? AppColors.primary : AppColors.surfaceVariant,
                ),
                labelStyle: textTheme.labelMedium?.copyWith(
                  color: activo ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
                ),
                showCheckmark: false,
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.fullBr),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Condiciones de salud ──────────────────────────────────────────
          _Etiqueta(
              texto: 'Condiciones de salud',
              icono: Icons.health_and_safety_rounded),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Puedes seleccionar varias.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChipsMultiple(
            opciones: _opcionesEnfermedades,
            seleccion: enfermedades,
            onToggle: onToggleEnfermedad,
          ),
          if (enfermedades.contains('Otra')) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: otraCondicionCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descríbelo con tus palabras',
                hintText: 'Ej: tengo presión alta desde hace 2 años, me canso mucho al caminar',
                alignLabelWithHint: true,
              ),
            ),
          ],
          // Tipo de condición (solo si seleccionó algo que no sea "Ninguna")
          if (enfermedades.isNotEmpty && !enfermedades.containsOnly('Ninguna')) ...[
            const SizedBox(height: AppSpacing.sm),
            _ChipsUnico(
              opciones: const [
                'Tengo diagnóstico confirmado',
                'Solo tengo síntomas, sin diagnóstico',
              ],
              seleccion: tipoCondicion == 'diagnosticada'
                  ? 'Tengo diagnóstico confirmado'
                  : tipoCondicion == 'sintomas'
                      ? 'Solo tengo síntomas, sin diagnóstico'
                      : null,
              onSeleccion: (v) {
                if (v == 'Tengo diagnóstico confirmado') {
                  onTipoCondicion('diagnosticada');
                } else if (v == 'Solo tengo síntomas, sin diagnóstico') {
                  onTipoCondicion('sintomas');
                } else {
                  onTipoCondicion(null);
                }
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // ── Alergias ──────────────────────────────────────────────────────
          _Etiqueta(
              texto: 'Alergias conocidas',
              icono: Icons.warning_amber_rounded),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Puedes seleccionar varias.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChipsMultiple(
            opciones: _opcionesAlergias,
            seleccion: alergias,
            onToggle: onToggleAlergia,
          ),
          if (alergias.contains('A medicamentos')) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: alergiaMedDetalleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: '¿A qué medicamento(s)?',
                hintText: 'Ej: Ibuprofeno, Penicilina',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: alergiaMedReaccionCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: '¿Qué reacción tuviste?',
                hintText: 'Ej: urticaria, dificultad para respirar',
              ),
            ),
          ],
          if (alergias.contains('Otra')) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: otraAlergiaCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Especifica tu alergia',
                hintText: 'Ej: Penicilina, mariscos',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // ── Medicación actual ─────────────────────────────────────────────
          _Etiqueta(
              texto: 'Medicación actual', icono: Icons.medication_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _OpcionCard(
                  label: 'Sí, tomo medicamentos',
                  activo: tomaMedicacion,
                  onTap: () => onToggleMedicacion(true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _OpcionCard(
                  label: 'No por ahora',
                  activo: !tomaMedicacion,
                  onTap: () => onToggleMedicacion(false),
                ),
              ),
            ],
          ),
          if (tomaMedicacion) ...[
            const SizedBox(height: AppSpacing.sm),
            ...List.generate(medControllers.length, (i) => _MedicamentoCard(
              indice: i,
              controllers: medControllers[i],
              frecuencia: medFrecuencia[i],
              tipo: medTipo[i],
              onSetFrecuencia: (v) => onSetFrecuencia(i, v),
              onSetTipo: (v) => onSetTipo(i, v),
              onEliminar: medControllers.length > 1 ? () => onEliminarMed(i) : null,
            )),
            if (medControllers.length < 3) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onAgregarMed,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Agregar otro medicamento'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withAlpha(100)),
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.lgBr),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: 'Guardar y continuar',
            onPressed: onSiguiente,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: onOmitir,
              child: Text(
                'Omitir por ahora',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paso 3: Personaliza tu asistente (nuevo) ──────────────────────────────────

class _PasoPersonaliza extends StatelessWidget {
  const _PasoPersonaliza({
    required this.categoriasTips,
    required this.onToggleCategoria,
    required this.objetivoSalud,
    required this.onObjetivo,
    required this.actividadFisica,
    required this.onActividad,
    required this.onOmitir,
    required this.onSiguiente,
  });

  final Set<String> categoriasTips;
  final ValueChanged<String> onToggleCategoria;
  final String? objetivoSalud;
  final ValueChanged<String?> onObjetivo;
  final String? actividadFisica;
  final ValueChanged<String?> onActividad;
  final VoidCallback onOmitir;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '4 de 5',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Personaliza tu asistente',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '¿Sobre qué temas de salud te gustaría recibir tips diarios?',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          _Etiqueta(
            texto: 'Categorías de tips',
            icono: Icons.lightbulb_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Puedes seleccionar varias.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChipsMultiple(
            opciones: const [
              'Nutrición', 'Ejercicio', 'Sueño', 'Salud mental',
              'Hidratación', 'Prevención', 'Medicación', 'Otro',
            ],
            seleccion: categoriasTips,
            onToggle: onToggleCategoria,
          ),
          const SizedBox(height: AppSpacing.xl),

          _Etiqueta(
            texto: '¿Cuál es tu objetivo principal de salud?',
            icono: Icons.flag_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChipsUnico(
            opciones: const [
              'Prevenir enfermedades',
              'Manejar una condición existente',
              'Mejorar mi bienestar general',
              'Seguir mi medicación',
            ],
            seleccion: objetivoSalud,
            onSeleccion: onObjetivo,
          ),
          const SizedBox(height: AppSpacing.xl),

          _Etiqueta(
            texto: '¿Con qué frecuencia haces actividad física?',
            icono: Icons.directions_run_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChipsUnico(
            opciones: const [
              'Nunca',
              '1-2 veces/semana',
              '3-4 veces/semana',
              'Todos los días',
            ],
            seleccion: actividadFisica,
            onSeleccion: onActividad,
          ),
          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: 'Continuar',
            onPressed: onSiguiente,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: onOmitir,
              child: Text(
                'Omitir por ahora',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paso 4: Cómo usar la app ──────────────────────────────────────────────────

class _PasoComoUsar extends StatelessWidget {
  const _PasoComoUsar({
    required this.onComenzar,
    required this.cargando,
  });

  final Future<void> Function() onComenzar;
  final bool cargando;

  static const _acciones = [
    (
      Icons.smart_toy_rounded,
      Color(0xFF5B2D8E),
      Color(0xFFEDE5FF),
      'Consulta al asistente IA',
      'Hazle preguntas sobre síntomas, medicamentos o salud general. Orientación inmediata, disponible 24/7.',
    ),
    (
      Icons.monitor_heart_rounded,
      Color(0xFFF47920),
      Color(0xFFFFF3E0),
      'Evalúa tus síntomas',
      'El triaje te indica si tu situación requiere atención urgente, pronto o puede esperar.',
    ),
    (
      Icons.people_outline_rounded,
      Color(0xFF00697A),
      Color(0xFFD1EFEC),
      'Encuentra tu médico',
      'Directorio completo de especialistas de la Clínica San Juan Bautista, con días y horarios.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5 de 5',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Lo que puedes hacer\ndesde hoy',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Estas son las 3 funciones principales. Puedes usarlas todas en cuanto entres.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          ..._acciones.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgBr,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: a.$3,
                          borderRadius: AppRadius.mdBr,
                        ),
                        child: Icon(a.$1, size: 22, color: a.$2),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.$4,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              a.$5,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Comenzar',
            onPressed: cargando ? null : () => onComenzar(),
            loading: cargando,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}

// ── Widgets compartidos ───────────────────────────────────────────────────────

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.icono});
  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 15, color: AppColors.primary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _OpcionCard extends StatelessWidget {
  const _OpcionCard({
    required this.label,
    required this.activo,
    required this.onTap,
  });
  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + 2, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary.withAlpha(15) : AppColors.surface,
          borderRadius: AppRadius.lgBr,
          border: Border.all(
            color: activo ? AppColors.primary : AppColors.surfaceVariant,
            width: activo ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              activo
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: activo ? AppColors.primary : AppColors.textDisabled,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: activo
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          activo ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsMultiple extends StatelessWidget {
  const _ChipsMultiple({
    required this.opciones,
    required this.seleccion,
    required this.onToggle,
  });

  final List<String> opciones;
  final Set<String> seleccion;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const colorActivo = AppColors.primary;
    final bgActivo = colorActivo.withAlpha(18);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: opciones.map((op) {
        final activo = seleccion.contains(op);
        return FilterChip(
          label: Text(op),
          selected: activo,
          onSelected: (_) => onToggle(op),
          selectedColor: bgActivo,
          checkmarkColor: colorActivo,
          side: BorderSide(
            color: activo ? colorActivo : AppColors.surfaceVariant,
          ),
          labelStyle: textTheme.labelMedium?.copyWith(
            color: activo ? colorActivo : AppColors.textSecondary,
            fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
          ),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBr),
          showCheckmark: true,
        );
      }).toList(),
    );
  }
}

// Chips de selección única (radio-style)
class _ChipsUnico extends StatelessWidget {
  const _ChipsUnico({
    required this.opciones,
    required this.seleccion,
    required this.onSeleccion,
  });

  final List<String> opciones;
  final String? seleccion;
  final ValueChanged<String?> onSeleccion;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: opciones.map((op) {
        final activo = seleccion == op;
        return ChoiceChip(
          label: Text(op),
          selected: activo,
          onSelected: (_) => onSeleccion(activo ? null : op),
          selectedColor: AppColors.primary.withAlpha(20),
          side: BorderSide(
            color: activo ? AppColors.primary : AppColors.surfaceVariant,
          ),
          labelStyle: textTheme.labelMedium?.copyWith(
            color: activo ? AppColors.primary : AppColors.textSecondary,
            fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
          ),
          showCheckmark: false,
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBr),
        );
      }).toList(),
    );
  }
}

// DatePicker field
class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(now.year - 25),
          firstDate: DateTime(1920),
          lastDate: now,
          locale: const Locale('es'),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                    primary: AppColors.primary,
                  ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgBr,
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value != null
                    ? '${value!.day}/${value!.month}/${value!.year}'
                    : 'Selecciona tu fecha de nacimiento',
                style: textTheme.bodyMedium?.copyWith(
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

// Card de medicamento individual
class _MedicamentoCard extends StatelessWidget {
  const _MedicamentoCard({
    required this.indice,
    required this.controllers,
    required this.frecuencia,
    required this.tipo,
    required this.onSetFrecuencia,
    required this.onSetTipo,
    required this.onEliminar,
  });

  final int indice;
  final Map<String, TextEditingController> controllers;
  final String? frecuencia;
  final String? tipo;
  final ValueChanged<String?> onSetFrecuencia;
  final ValueChanged<String?> onSetTipo;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBr,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryLightBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.medication_rounded,
                    size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Medicamento ${indice + 1}',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onEliminar != null)
                GestureDetector(
                  onTap: onEliminar,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDEAEA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: AppColors.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controllers['nombre'],
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre del medicamento',
              hintText: 'Ej: Metformina',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controllers['dosis'],
            decoration: const InputDecoration(
              labelText: 'Dosis (opcional)',
              hintText: 'Ej: 500 mg',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Frecuencia',
            style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          _ChipsUnico(
            opciones: const [
              'Diario',
              'Interdiario',
              'Semanal',
              'Solo cuando lo necesito',
            ],
            seleccion: frecuencia,
            onSeleccion: onSetFrecuencia,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tipo',
            style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          _ChipsUnico(
            opciones: const ['Con receta', 'Venta libre', 'Suplemento'],
            seleccion: tipo,
            onSeleccion: onSetTipo,
          ),
        ],
      ),
    );
  }
}

// Extension helper
extension _SetContainsOnly<T> on Set<T> {
  bool containsOnly(T value) => length == 1 && contains(value);
}
