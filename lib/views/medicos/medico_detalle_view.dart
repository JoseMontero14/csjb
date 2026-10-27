import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/medico_model.dart';
import '../../utils/routes.dart';
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
      _medico = ModalRoute.of(context)!.settings.arguments as MedicoModel;
      _inicializado = true;
    }
  }

  Future<void> _solicitarCita() async {
    const numero = '51939222667';
    final mensaje = Uri.encodeComponent(
      'Hola Clínica San Juan Bautista, deseo reservar una consulta '
      'en la especialidad de ${_medico.especialidadDisplay}',
    );
    final url = Uri.parse('https://wa.me/$numero?text=$mensaje');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          child: AppButton(
            label: 'Solicitar cita',
            onPressed: _solicitarCita,
            icon: const Icon(Icons.chat_rounded),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar con hero expandible ────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 200,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              _medico.nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const BackButton(color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6B48FF), Color(0xFFA78BFA)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Espacio para la status bar / collapsed app bar
                    const SizedBox(height: 56),
                    // Avatar centrado verticalmente
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white, width: 3),
                        color: AppColors.primaryLightBg,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: _FotoDetalle(fotoUrl: _medico.fotoUrl),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenido con top padding para el overlap ───────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + especialidad pill + rating
                  Text(
                    _medico.nombre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLightBg,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          _medico.especialidadDisplay,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFF57F17)),
                      const SizedBox(width: 2),
                      Text(
                        '4.8',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Stats ─────────────────────────────────────────────────
                  _FilaStats(medico: _medico),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Especialidad card ─────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
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
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.info_outline_rounded,
                                  size: 15, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'ESPECIALIDAD',
                              style: textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF424242),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _medico.descripcionEspecialidad,
                          style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Consultas frecuentes ──────────────────────────────────
                  _SeccionConsultas(medico: _medico),
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

// ── Stats inline con divisores ────────────────────────────────────────────────

class _FilaStats extends StatelessWidget {
  const _FilaStats({required this.medico});
  final MedicoModel medico;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = [
      ('1.2k', 'Pacientes'),
      ('8 años', 'Experiencia'),
      ('Lun – Vie', 'Disponibilidad'),
    ];

    return IntrinsicHeight(
      child: Row(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(
              width: 1,
              color: const Color(0xFFE0E0E0),
              margin: const EdgeInsets.symmetric(vertical: 4),
            );
          }
          final idx = i ~/ 2;
          final item = items[idx];
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.$1,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.$2,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Consultas frecuentes ──────────────────────────────────────────────────────

class _SeccionConsultas extends StatelessWidget {
  const _SeccionConsultas({required this.medico});
  final MedicoModel medico;

  static const _iconos = [
    Icons.help_outline_rounded,
    Icons.schedule_rounded,
    Icons.monitor_heart_rounded,
  ];

  List<Map<String, String>> _preguntas(String especialidad) => [
        {
          'titulo': '¿Qué trata ${especialidad.toLowerCase()}?',
          'subtitulo': 'Conoce el alcance de esta especialidad',
          'pregunta':
              '¿Qué enfermedades y condiciones trata la especialidad de $especialidad? Dame un resumen claro.',
        },
        {
          'titulo': '¿Cuándo debo consultar?',
          'subtitulo': 'Síntomas que indican visitar al especialista',
          'pregunta':
              '¿Qué síntomas me indican que debo consultar con un especialista en $especialidad? Explica de forma sencilla.',
        },
        {
          'titulo': '¿Cómo prepararme?',
          'subtitulo': 'Pasos antes de tu primera consulta',
          'pregunta':
              '¿Cómo me preparo para una consulta con un especialista en $especialidad? ¿Qué documentos o información debo llevar?',
        },
      ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final especialidad = medico.especialidadDisplay;
    final preguntas = _preguntas(especialidad);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consultas frecuentes',
            style: textTheme.titleSmall?.copyWith(
              color: const Color(0xFF424242),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(preguntas.length, (i) {
            final p = preguntas[i];
            return Column(
              children: [
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFEEEEEE),
                  ),
                InkWell(
                  borderRadius: AppRadius.smBr,
                  onTap: () => AppRoutes.push(
                    context,
                    AppRoutes.chatDetalle,
                    args: {'mensajeInicial': p['pregunta']},
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          _iconos[i],
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['titulo']!,
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1A2E),
                                ),
                              ),
                              Text(
                                p['subtitulo']!,
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _FotoDetalle extends StatelessWidget {
  const _FotoDetalle({required this.fotoUrl});
  final String fotoUrl;

  @override
  Widget build(BuildContext context) {
    if (fotoUrl.startsWith('data:image')) {
      final b64 = fotoUrl.contains(',') ? fotoUrl.split(',').last : fotoUrl;
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    } else if (fotoUrl.isNotEmpty) {
      return Image.network(
        fotoUrl,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => const _PlaceholderFoto(),
      );
    }
    return const _PlaceholderFoto();
  }
}

class _PlaceholderFoto extends StatelessWidget {
  const _PlaceholderFoto();
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFEDE5FF),
        child: Center(
          child: SvgPicture.asset(
            'assets/il_doctor_placeholder.svg',
            height: 60,
            fit: BoxFit.contain,
          ),
        ),
      );
}
