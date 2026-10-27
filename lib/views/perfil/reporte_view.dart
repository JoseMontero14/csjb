import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/recordatorio_model.dart';
import '../../models/triaje_model.dart';
import '../../models/usuario_model.dart';
import '../../services/gemini_service.dart';
import '../../utils/theme.dart';

class ReporteView extends StatefulWidget {
  const ReporteView({super.key});

  @override
  State<ReporteView> createState() => _ReporteViewState();
}

class _ReporteViewState extends State<ReporteView> {
  late final Future<_DatosReporte> _futureReporte;

  _AnalisisIA? _analisis;
  bool _generandoAnalisis = false;
  String? _errorAnalisis;

  @override
  void initState() {
    super.initState();
    _futureReporte = _cargarDatos();
  }

  Future<void> _generarAnalisis(_DatosReporte datos) async {
    setState(() {
      _generandoAnalisis = true;
      _errorAnalisis = null;
    });
    try {
      final adherenciaMeds = {
        for (final entry in datos.adherencia.entries)
          entry.value.nombre: (
            total: entry.value.total,
            tomadas: entry.value.tomadas,
          )
      };
      final especialidades = datos.triajes
          .where((t) => t.especialidadSugerida != null)
          .map((t) => t.especialidadSugerida!)
          .toSet()
          .toList();

      final json = await GeminiService().generarAnalisisSalud(
        adherenciaMeds: adherenciaMeds,
        totalTriajes: datos.triajes.length,
        triajesLeve: datos.triajes
            .where((t) => t.nivelUrgencia == UrgencyLevel.low)
            .length,
        triajesMedio: datos.triajes
            .where((t) => t.nivelUrgencia == UrgencyLevel.medium)
            .length,
        triajesAlto: datos.triajes
            .where((t) => t.nivelUrgencia == UrgencyLevel.high)
            .length,
        especialidades: especialidades,
        totalChats: datos.totalChats,
        condiciones: datos.usuario?.enfermedades ?? [],
        objetivoSalud: datos.usuario?.objetivoSalud,
        actividadFisica: datos.usuario?.actividadFisica,
      );
      setState(() {
        _analisis = _AnalisisIA.fromJson(json);
        _generandoAnalisis = false;
      });
    } catch (e) {
      setState(() {
        _errorAnalisis = e.toString().replaceAll('Exception: ', '');
        _generandoAnalisis = false;
      });
    }
  }

  Future<_DatosReporte> _cargarDatos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final db = FirebaseFirestore.instance;

    // Usuario
    final usuarioSnap = await db.collection('usuarios').doc(uid).get();
    final usuario = usuarioSnap.exists
        ? UsuarioModel.fromFirestore(usuarioSnap)
        : null;

    // Recordatorios activos
    final recSnap = await db
        .collection('recordatorios')
        .where('uid', isEqualTo: uid)
        .get();
    final todosRecordatorios = recSnap.docs
        .map((d) => RecordatorioModel.fromFirestore(d))
        .toList();
    final recordatoriosActivos =
        todosRecordatorios.where((r) => r.activo).toList();

    // Adherencia últimos 7 días por recordatorio activo
    final Map<String, _AdherenciaRec> adherencia = {};
    final ahora = DateTime.now();
    final hace7 = ahora.subtract(const Duration(days: 7));

    if (recordatoriosActivos.isNotEmpty) {
      final tomasResults = await Future.wait(
        recordatoriosActivos.map((rec) => db
            .collection('recordatorios')
            .doc(rec.id)
            .collection('historial_tomas')
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hace7))
            .get()),
      );
      for (int i = 0; i < recordatoriosActivos.length; i++) {
        final rec = recordatoriosActivos[i];
        final tomas = tomasResults[i].docs;
        final total = tomas.length;
        final tomadas = tomas.where((d) => d.data()['tomado'] == true).length;
        adherencia[rec.id] = _AdherenciaRec(
          nombre: rec.nombreCompleto,
          total: total,
          tomadas: tomadas,
        );
      }
    }

    // Triajes guardados (últimos 5)
    final triajeSnap = await db
        .collection('triajes')
        .where('uid', isEqualTo: uid)
        .where('guardado', isEqualTo: true)
        .orderBy('fecha', descending: true)
        .limit(5)
        .get();
    final triajes =
        triajeSnap.docs.map((d) => TriajeModel.fromFirestore(d)).toList();

    // Chats IA (últimos 5)
    final chatSnap = await db
        .collection('chats_ia')
        .where('uid', isEqualTo: uid)
        .orderBy('creadoEn', descending: true)
        .limit(5)
        .get();
    final chats = chatSnap.docs
        .map((d) => _ChatResumen(
              titulo: d.data()['titulo'] as String? ?? 'Sin título',
              fecha: (d.data()['creadoEn'] as Timestamp).toDate(),
            ))
        .toList();

    final totalChats = (await db
            .collection('chats_ia')
            .where('uid', isEqualTo: uid)
            .count()
            .get())
        .count;

    return _DatosReporte(
      usuario: usuario,
      recordatoriosActivos: recordatoriosActivos,
      adherencia: adherencia,
      triajes: triajes,
      chats: chats,
      totalChats: totalChats ?? 0,
    );
  }

  void _compartir(_DatosReporte datos) {
    final buf = StringBuffer();
    final ahora = DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy', 'es');

    buf.writeln('REPORTE DE SALUD — CLÍNICA SAN JUAN BAUTISTA');
    buf.writeln('Generado el ${fmt.format(ahora)}');
    buf.writeln();

    if (datos.usuario != null) {
      final u = datos.usuario!;
      buf.writeln('PACIENTE');
      buf.writeln('Nombre: ${u.nombre}');
      buf.writeln('Sexo: ${u.sexo.label}');
      buf.writeln('Grupo sanguíneo: ${u.grupoSanguineo ?? '—'}');
      if (u.enfermedades.isNotEmpty) {
        buf.writeln('Condiciones: ${u.enfermedades.join(', ')}');
      }
      if (u.alergias.isNotEmpty) {
        buf.writeln('Alergias: ${u.alergias.join(', ')}');
      }
      buf.writeln();
    }

    buf.writeln('MEDICACIÓN ACTIVA (${datos.recordatoriosActivos.length})');
    if (datos.recordatoriosActivos.isEmpty) {
      buf.writeln('Sin medicamentos registrados.');
    } else {
      for (final r in datos.recordatoriosActivos) {
        buf.writeln(
            '• ${r.nombreCompleto} — ${r.dosis} — ${r.frecuencia.label}');
      }
    }
    buf.writeln();

    buf.writeln('ADHERENCIA (últimos 7 días)');
    if (datos.adherencia.isEmpty) {
      buf.writeln('Sin datos de adherencia.');
    } else {
      for (final a in datos.adherencia.values) {
        final pct = a.total > 0
            ? (a.tomadas / a.total * 100).round()
            : 0;
        buf.writeln('• ${a.nombre}: $pct% (${a.tomadas}/${a.total})');
      }
    }
    buf.writeln();

    buf.writeln('TRIAJES GUARDADOS (${datos.triajes.length})');
    for (final t in datos.triajes) {
      buf.writeln(
          '• ${fmt.format(t.fecha)} — ${t.nivelUrgencia.label} — ${t.especialidadSugerida ?? '—'}');
    }
    buf.writeln();

    buf.writeln('CHAT IA — ${datos.totalChats} conversaciones');
    buf.writeln();

    if (_analisis != null) {
      buf.writeln('ANÁLISIS IA');
      buf.writeln(_analisis!.resumen);
      buf.writeln();
      buf.writeln('Observaciones:');
      for (final o in _analisis!.observaciones) {
        buf.writeln('• ${o.titulo}: ${o.texto}');
      }
      buf.writeln();
      buf.writeln('Recomendaciones:');
      for (final r in _analisis!.recomendaciones) {
        buf.writeln('• $r');
      }
      if (_analisis!.limitaciones.isNotEmpty) {
        buf.writeln();
        buf.writeln('Limitaciones: ${_analisis!.limitaciones}');
      }
      buf.writeln();
    }

    buf.writeln(
        'AVISO: Este reporte es un resumen informativo. No constituye un historial clínico oficial.');

    Share.share(buf.toString(), subject: 'Mi reporte de salud — CSJB');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        title: const Text(
          'Mi reporte',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          FutureBuilder<_DatosReporte>(
            future: _futureReporte,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                tooltip: 'Compartir',
                onPressed: () => _compartir(snap.data!),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<_DatosReporte>(
        future: _futureReporte,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Text('Error al cargar el reporte.',
                  style: textTheme.bodyMedium),
            );
          }
          final datos = snap.data!;
          return _CuerpoReporte(
            datos: datos,
            analisis: _analisis,
            generandoAnalisis: _generandoAnalisis,
            errorAnalisis: _errorAnalisis,
            onGenerar: () => _generarAnalisis(datos),
          );
        },
      ),
    );
  }
}

// ── Cuerpo del reporte ────────────────────────────────────────────────────────

class _CuerpoReporte extends StatelessWidget {
  const _CuerpoReporte({
    required this.datos,
    required this.analisis,
    required this.generandoAnalisis,
    required this.errorAnalisis,
    required this.onGenerar,
  });
  final _DatosReporte datos;
  final _AnalisisIA? analisis;
  final bool generandoAnalisis;
  final String? errorAnalisis;
  final VoidCallback onGenerar;

  int _calcEdad(DateTime nacimiento) {
    final hoy = DateTime.now();
    int e = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) { e--; }
    return e;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ahora = DateTime.now();
    final fmt = DateFormat("d 'de' MMMM 'de' yyyy", 'es');
    final u = datos.usuario;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera ──────────────────────────────────────────────────────
          Text(
            u?.nombre ?? 'Paciente',
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Generado el ${fmt.format(ahora)}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Sección 1: Resumen de salud ───────────────────────────────────
          _SeccionHeader(
            icono: Icons.favorite_border_rounded,
            titulo: 'Resumen de salud',
          ),
          const SizedBox(height: AppSpacing.sm),

          if (u != null) ...[
            // Chips de datos clave
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    icono: Icons.cake_rounded,
                    valor: '${_calcEdad(u.fechaNacimiento)} años',
                    label: 'Edad',
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _StatChip(
                    icono: Icons.wc_rounded,
                    valor: u.sexo.label,
                    label: 'Sexo',
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _StatChip(
                    icono: Icons.water_drop_rounded,
                    valor: u.grupoSanguineo ?? '—',
                    label: 'Sangre',
                    iconColor: const Color(0xFFE53935),
                  ),
                ),
              ],
            ),

            if (u.enfermedades.isNotEmpty || u.otraCondicionDescripcion != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Descripción del paciente',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE5FF),
                  borderRadius: AppRadius.lgBr,
                ),
                child: Text(
                  [
                    if (u.enfermedades.isNotEmpty) u.enfermedades.join(', '),
                    if (u.otraCondicionDescripcion != null &&
                        u.otraCondicionDescripcion!.isNotEmpty)
                      u.otraCondicionDescripcion!,
                  ].join('\n'),
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF1A1A2E),
                    height: 1.5,
                  ),
                ),
              ),
            ],

            if (u.alergias.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Alergias',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: u.alergias
                    .map((a) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: AppRadius.fullBr,
                          ),
                          child: Text(a,
                              style: textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ))
                    .toList(),
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Sin datos de salud.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          const SizedBox(height: AppSpacing.lg),

          // ── Sección 2: Medicación activa ──────────────────────────────────
          _SeccionHeader(
            icono: Icons.medication_rounded,
            titulo: 'Medicación activa',
            conteo: datos.recordatoriosActivos.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (datos.recordatoriosActivos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text('Sin medicamentos registrados.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            )
          else
            ...datos.recordatoriosActivos.map((r) => _CardMedicamento(rec: r)),

          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          const SizedBox(height: AppSpacing.lg),

          // ── Sección 3: Adherencia ─────────────────────────────────────────
          _SeccionHeader(
            icono: Icons.bar_chart_rounded,
            titulo: 'Adherencia — últimos 7 días',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (datos.adherencia.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text('Sin datos de adherencia.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            )
          else
            ...datos.adherencia.values.map((a) => _FilaAdherencia(datos: a)),

          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          const SizedBox(height: AppSpacing.lg),

          // ── Sección 4: Historial triajes ──────────────────────────────────
          _SeccionHeader(
            icono: Icons.health_and_safety_rounded,
            titulo: 'Historial de triajes',
            conteo: datos.triajes.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (datos.triajes.isNotEmpty) ...[
            _DistribucionTriajes(triajes: datos.triajes),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (datos.triajes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text('Sin triajes guardados.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            )
          else
            ...datos.triajes.map((t) => _FilaTriaje(triaje: t)),

          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          const SizedBox(height: AppSpacing.lg),

          // ── Sección 5: Chat IA ────────────────────────────────────────────
          _SeccionHeader(
            icono: Icons.chat_bubble_outline_rounded,
            titulo: 'Actividad en Chat IA',
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icono: Icons.forum_rounded,
                  valor: '${datos.totalChats}',
                  label: 'Conversaciones',
                ),
              ),
              if (datos.chats.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _StatChip(
                    icono: Icons.access_time_rounded,
                    valor: DateFormat('dd/MM/yy', 'es')
                        .format(datos.chats.first.fecha),
                    label: 'Última consulta',
                  ),
                ),
              ],
            ],
          ),
          if (datos.chats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...datos.chats.take(3).map(
                  (c) => Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            c.titulo,
                            style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM', 'es').format(c.fecha),
                          style: textTheme.labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
          ],

          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          const SizedBox(height: AppSpacing.lg),

          // ── Sección 6: Análisis inteligente con IA ────────────────────────
          _SeccionAnalisisIA(
            analisis: analisis,
            generandoAnalisis: generandoAnalisis,
            errorAnalisis: errorAnalisis,
            onGenerar: onGenerar,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Footer disclaimer ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5FF),
              borderRadius: AppRadius.lgBr,
            ),
            child: Text(
              'Este reporte es un resumen informativo generado por la app '
              'Clínica San Juan Bautista. No constituye un historial clínico oficial.',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.primary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SeccionHeader extends StatelessWidget {
  const _SeccionHeader({
    required this.icono,
    required this.titulo,
    this.conteo,
  });
  final IconData icono;
  final String titulo;
  final int? conteo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.primaryLightBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          titulo.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: const Color(0xFF424242),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        if (conteo != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: AppRadius.fullBr,
            ),
            child: Text(
              '$conteo',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icono,
    required this.valor,
    required this.label,
    this.iconColor,
  });
  final IconData icono;
  final String valor;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = iconColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.3,
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

class _CardMedicamento extends StatelessWidget {
  const _CardMedicamento({required this.rec});
  final RecordatorioModel rec;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.mdBr,
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLightBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medication_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.nombreCompleto,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${rec.dosis} · ${rec.frecuencia.label}',
                    style: textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary),
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


class _FilaAdherencia extends StatelessWidget {
  const _FilaAdherencia({required this.datos});
  final _AdherenciaRec datos;

  Color _barColor(int pct) {
    if (pct >= 80) return const Color(0xFF4CAF50);
    if (pct >= 50) return AppColors.accent;
    return AppColors.urgencyHigh;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = datos.total > 0 ? (datos.tomadas / datos.total) : 0.0;
    final pctInt = (pct * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  datos.nombre,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '$pctInt%',
                style: textTheme.labelSmall?.copyWith(
                  color: _barColor(pctInt),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: AppRadius.fullBr,
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(_barColor(pctInt)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistribucionTriajes extends StatelessWidget {
  const _DistribucionTriajes({required this.triajes});
  final List<TriajeModel> triajes;

  @override
  Widget build(BuildContext context) {
    final leve = triajes.where((t) => t.nivelUrgencia == UrgencyLevel.low).length;
    final medio = triajes.where((t) => t.nivelUrgencia == UrgencyLevel.medium).length;
    final alto = triajes.where((t) => t.nivelUrgencia == UrgencyLevel.high).length;

    return IntrinsicHeight(
      child: Row(
        children: [
          _DistItem(valor: '$leve', label: 'Leve', color: const Color(0xFF558B2F)),
          Container(width: 1, color: const Color(0xFFE0E0E0), margin: const EdgeInsets.symmetric(vertical: 4)),
          _DistItem(valor: '$medio', label: 'Medio', color: const Color(0xFFF57F17)),
          Container(width: 1, color: const Color(0xFFE0E0E0), margin: const EdgeInsets.symmetric(vertical: 4)),
          _DistItem(valor: '$alto', label: 'Alto', color: const Color(0xFFC62828)),
        ],
      ),
    );
  }
}

class _DistItem extends StatelessWidget {
  const _DistItem({required this.valor, required this.label, required this.color});
  final String valor;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(valor, style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700, color: color)),
          Text(label, style: textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _FilaTriaje extends StatelessWidget {
  const _FilaTriaje({required this.triaje});
  final TriajeModel triaje;

  Color get _nivelColor => switch (triaje.nivelUrgencia) {
        UrgencyLevel.high => const Color(0xFFC62828),
        UrgencyLevel.medium => const Color(0xFFF57F17),
        UrgencyLevel.low => const Color(0xFF558B2F),
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fmt = DateFormat('dd/MM/yy', 'es');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          // Fecha izquierda
          SizedBox(
            width: 72,
            child: Text(
              fmt.format(triaje.fecha),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          // Badge nivel centro
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _nivelColor.withAlpha(20),
              borderRadius: AppRadius.fullBr,
            ),
            child: Text(
              triaje.nivelUrgencia.label,
              style: textTheme.labelSmall?.copyWith(
                color: _nivelColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Especialidad derecha
          Expanded(
            child: Text(
              triaje.especialidadSugerida ?? '—',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modelos internos ──────────────────────────────────────────────────────────

class _DatosReporte {
  const _DatosReporte({
    required this.usuario,
    required this.recordatoriosActivos,
    required this.adherencia,
    required this.triajes,
    required this.chats,
    required this.totalChats,
  });
  final UsuarioModel? usuario;
  final List<RecordatorioModel> recordatoriosActivos;
  final Map<String, _AdherenciaRec> adherencia;
  final List<TriajeModel> triajes;
  final List<_ChatResumen> chats;
  final int totalChats;
}

class _AdherenciaRec {
  const _AdherenciaRec({
    required this.nombre,
    required this.total,
    required this.tomadas,
  });
  final String nombre;
  final int total;
  final int tomadas;
}

class _ChatResumen {
  const _ChatResumen({required this.titulo, required this.fecha});
  final String titulo;
  final DateTime fecha;
}

class _AnalisisIA {
  const _AnalisisIA({
    required this.resumen,
    required this.observaciones,
    required this.recomendaciones,
    required this.limitaciones,
  });
  final String resumen;
  final List<_ObservacionIA> observaciones;
  final List<String> recomendaciones;
  final String limitaciones;

  factory _AnalisisIA.fromJson(Map<String, dynamic> json) => _AnalisisIA(
        resumen: json['resumen'] as String,
        observaciones: (json['observaciones'] as List)
            .map((o) => _ObservacionIA.fromJson(o as Map<String, dynamic>))
            .toList(),
        recomendaciones: (json['recomendaciones'] as List)
            .map((r) => r as String)
            .toList(),
        limitaciones: json['limitaciones'] as String? ?? '',
      );
}

class _ObservacionIA {
  const _ObservacionIA({
    required this.area,
    required this.titulo,
    required this.texto,
    required this.tipo,
  });
  final String area;
  final String titulo;
  final String texto;
  final String tipo; // 'positivo' | 'neutro' | 'atencion'

  factory _ObservacionIA.fromJson(Map<String, dynamic> json) => _ObservacionIA(
        area: json['area'] as String? ?? '',
        titulo: json['titulo'] as String? ?? '',
        texto: json['texto'] as String? ?? '',
        tipo: json['tipo'] as String? ?? 'neutro',
      );
}

// ── Sección Análisis IA ───────────────────────────────────────────────────────

class _SeccionAnalisisIA extends StatelessWidget {
  const _SeccionAnalisisIA({
    required this.analisis,
    required this.generandoAnalisis,
    required this.errorAnalisis,
    required this.onGenerar,
  });
  final _AnalisisIA? analisis;
  final bool generandoAnalisis;
  final String? errorAnalisis;
  final VoidCallback onGenerar;

  @override
  Widget build(BuildContext context) {
    if (analisis != null) {
      return _AnalisisResultado(analisis: analisis!, onRegenerar: onGenerar);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SeccionHeader(
          icono: Icons.auto_awesome_rounded,
          titulo: 'Análisis inteligente',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (generandoAnalisis)
          _AnalisisCargando()
        else if (errorAnalisis != null)
          _AnalisisError(mensaje: errorAnalisis!, onReintentar: onGenerar)
        else
          _AnalisisInicial(onGenerar: onGenerar),
      ],
    );
  }
}

class _AnalisisInicial extends StatelessWidget {
  const _AnalisisInicial({required this.onGenerar});
  final VoidCallback onGenerar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgBr,
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLightBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis inteligente',
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Generado por IA · basado en tus registros',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Obtén un resumen personalizado de tu actividad de salud de los últimos 7 días.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onGenerar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.lgBr),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Generar análisis'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalisisCargando extends StatelessWidget {
  const _AnalisisCargando();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgBr,
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Analizando tus registros...',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalisisError extends StatelessWidget {
  const _AnalisisError({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: AppRadius.lgBr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: AppColors.urgencyHigh),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  mensaje,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFC62828),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onReintentar,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    );
  }
}

class _AnalisisResultado extends StatelessWidget {
  const _AnalisisResultado(
      {required this.analisis, required this.onRegenerar});
  final _AnalisisIA analisis;
  final VoidCallback onRegenerar;

  Color _colorTipo(String tipo) => switch (tipo) {
        'positivo' => const Color(0xFF4CAF50),
        'atencion' => const Color(0xFFF57C00),
        _ => const Color(0xFF78909C),
      };

  IconData _iconoTipo(String tipo) => switch (tipo) {
        'positivo' => Icons.check_circle_outline_rounded,
        'atencion' => Icons.warning_amber_rounded,
        _ => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con badge IA + botón Regenerar
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'Análisis inteligente',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLightBg,
                borderRadius: AppRadius.fullBr,
              ),
              child: Text(
                'IA',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onRegenerar,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text(
                'Regenerar',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Resumen
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEDE9FF), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.lgBr,
          ),
          child: Text(
            analisis.resumen,
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF1A1A2E),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Observaciones
        Text(
          'OBSERVACIONES',
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...analisis.observaciones.map((o) {
          final color = _colorTipo(o.tipo);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.mdBr,
                border: Border(
                    left: BorderSide(color: color, width: 3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.titulo,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          o.texto,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(_iconoTipo(o.tipo), size: 16, color: color),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),

        // Recomendaciones
        Text(
          'RECOMENDACIONES',
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...analisis.recomendaciones.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    r,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (analisis.limitaciones.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: AppRadius.mdBr,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: Color(0xFFF57F17)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    analisis.limitaciones,
                    style: textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF795548),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            'Análisis generado por Gemini · No reemplaza evaluación médica',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
