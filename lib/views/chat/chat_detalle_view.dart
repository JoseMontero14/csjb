import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../controllers/chat_controller.dart';
import '../../models/mensaje_model.dart';
import '../../models/recordatorio_model.dart';
import '../../models/usuario_model.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/emergencia_dialog.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

/// Lee el perfil del usuario y sus recordatorios activos desde Firestore en
/// paralelo y construye el string de contexto que se inyecta en el system
/// prompt. Devuelve null si falla.
Future<String?> _leerContextoUsuario(String uid) async {
  if (uid.isEmpty) return null;
  try {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('usuarios').doc(uid).get(),
      FirebaseFirestore.instance
          .collection('recordatorios')
          .where('uid', isEqualTo: uid)
          .get(),
    ]);
    final usuarioDoc = results[0] as DocumentSnapshot;
    final recSnap = results[1] as QuerySnapshot;
    if (!usuarioDoc.exists) return null;
    final u = UsuarioModel.fromFirestore(usuarioDoc);
    final partes = <String>[];

    // Identidad básica — siempre presente
    partes.add('nombre: ${u.nombre}');
    final edad = DateTime.now().difference(u.fechaNacimiento).inDays ~/ 365;
    partes.add('edad: $edad años');
    partes.add('sexo: ${u.sexo.label}');
    if (u.grupoSanguineo != null && u.grupoSanguineo!.isNotEmpty) {
      partes.add('grupo sanguíneo: ${u.grupoSanguineo}');
    }

    // Condiciones de salud
    if (u.enfermedades.isNotEmpty) {
      final condStr = u.enfermedades.join(', ');
      final tipo = u.tipoCondicion;
      final otra = u.otraCondicionDescripcion;
      partes.add('condiciones de salud: $condStr'
          '${tipo != null ? ' ($tipo)' : ''}'
          '${otra != null ? ' — $otra' : ''}');
    }
    if (u.alergias.isNotEmpty) {
      final alStr = u.alergias.join(', ');
      final prefs = u.preferenciasSalud;
      final detalle = prefs?['alergiaMedicamentoDetalle'] as String?;
      final reaccion = prefs?['alergiaMedicamentoReaccion'] as String?;
      partes.add('alergias: $alStr'
          '${detalle != null ? ' (medicamentos: $detalle' : ''}'
          '${reaccion != null ? ', reacción: $reaccion)' : (detalle != null ? ')' : '')}');
    }
    final actividad = u.actividadFisica
        ?? (u.preferenciasSalud?['actividadFisica'] as String?);
    if (actividad != null) partes.add('nivel de actividad física: $actividad');
    if (u.embarazoLactancia != null &&
        u.embarazoLactancia != 'No aplica' &&
        u.embarazoLactancia != 'Prefiero no responder') {
      partes.add('embarazo/lactancia: ${u.embarazoLactancia}');
    }
    if (u.preferenciaExplicacion != null) {
      partes.add('prefiere explicaciones: ${u.preferenciaExplicacion}');
    }
    if (u.objetivoSalud != null) {
      partes.add('objetivo de salud: ${u.objetivoSalud}');
    }

    // Medicamentos activos (filtrados por el getter activo del modelo)
    final medicamentosActivos = recSnap.docs
        .map((d) => RecordatorioModel.fromFirestore(d))
        .where((r) => r.activo)
        .toList();
    if (medicamentosActivos.isNotEmpty) {
      final medsStr = medicamentosActivos.map((r) {
        final partesMed = [r.nombreCompleto];
        if (r.dosis.isNotEmpty) partesMed.add(r.dosis);
        partesMed.add(r.frecuencia.label);
        return partesMed.join(' ');
      }).join(', ');
      partes.add('medicamentos actuales: $medsStr');
    }

    return partes.join('; ');
  } catch (e) {
    debugPrint('_leerContextoUsuario: $e');
    return null;
  }
}

class ChatDetalleView extends StatefulWidget {
  const ChatDetalleView({super.key});

  @override
  State<ChatDetalleView> createState() => _ChatDetalleViewState();
}

class _ChatDetalleViewState extends State<ChatDetalleView> {
  final _controller = ChatController();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _inicializado = false;
  bool _cargandoContexto = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      String? chatId;
      String? mensajeInicial;
      if (args is String) {
        chatId = args;
      } else if (args is Map) {
        chatId = args['chatId'] as String?;
        mensajeInicial = args['mensajeInicial'] as String?;
      }
      _inicializarChat(chatId: chatId, mensajeInicial: mensajeInicial);
    }
  }

  Future<void> _inicializarChat({
    String? chatId,
    String? mensajeInicial,
  }) async {
    final uid = _uid;
    if (chatId != null) {
      // Chat existente: muestra el historial de inmediato y actualiza el
      // contexto en segundo plano sin bloquear la UI.
      _controller.iniciarChat(uid, chatId: chatId);
      final ctx = await _leerContextoUsuario(uid);
      if (!mounted) return;
      _controller.iniciarChat(uid, chatId: chatId, contextoUsuario: ctx);
    } else {
      // Chat nuevo: espera el contexto antes de mostrar la interfaz para que
      // el primer mensaje ya lleve el perfil del paciente completo.
      setState(() => _cargandoContexto = true);
      final ctx = await _leerContextoUsuario(uid);
      if (!mounted) return;
      setState(() => _cargandoContexto = false);
      _controller.iniciarChat(uid, contextoUsuario: ctx);
      if (mensajeInicial != null && mensajeInicial.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _enviar(mensajeInicial);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _enviar(String texto) async {
    if (texto.trim().isEmpty) return;
    _textController.clear();
    await _controller.enviarMensaje(texto);
    _scrollAlFinal();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE5FF),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SvgPicture.asset(
                  'assets/il_asistente_avatar.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Asistente CSJB',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('En línea',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
      body: _cargandoContexto
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : Column(
        children: [
          const _DisclaimerBanner(),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAlFinal());
                return _MensajesLista(
                  mensajes: _controller.mensajes,
                  escribiendo: _controller.escribiendo,
                  scrollController: _scrollController,
                  onSugerencia: _enviar,
                );
              },
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.errorMensaje != null) {
                return _ErrorBanner(mensaje: _controller.errorMensaje!);
              }
              return const SizedBox.shrink();
            },
          ),
          _InputArea(
            controller: _textController,
            onEnviar: _enviar,
            listenable: _controller,
          ),
        ],
      ),
    );
  }
}


// Detecta si el texto de un mensaje IA contiene señales de alarma médica.
bool _contieneAlarma(String texto) {
  final lower = texto.toLowerCase();
  return const [
    'emergencia', 'urgencias', 'acude', 'inmediato', 'inmediatamente',
    'ambulancia', 'llama al samu', 'llama al 106', 'sin demora',
    'de inmediato', 'peligro de vida', 'crítico', 'crítica',
    'atención de urgencia', 'sala de emergencias',
  ].any(lower.contains);
}

// ── Lista de mensajes ─────────────────────────────────────────────────────────

class _MensajesLista extends StatelessWidget {
  const _MensajesLista({
    required this.mensajes,
    required this.escribiendo,
    required this.scrollController,
    required this.onSugerencia,
  });

  final List<MensajeModel> mensajes;
  final bool escribiendo;
  final ScrollController scrollController;
  final Future<void> Function(String) onSugerencia;

  @override
  Widget build(BuildContext context) {
    if (mensajes.isEmpty && !escribiendo) {
      return _BienvenidaChat(onSugerencia: onSugerencia);
    }

    final mostrarSugerencias = !escribiendo &&
        mensajes.isNotEmpty &&
        !mensajes.last.esUsuario;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount:
          mensajes.length + (escribiendo ? 1 : 0) + (mostrarSugerencias ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < mensajes.length) {
          final msg = mensajes[i];
          final esAlerta =
              !msg.esUsuario && _contieneAlarma(msg.texto);
          return _BurbujaMensaje(
            mensaje: msg,
            mostrarBotonEmergencia: esAlerta,
          );
        }
        if (escribiendo && i == mensajes.length) {
          return const _IndicadorEscribiendo();
        }
        return _SugerenciasRapidas(onTap: onSugerencia);
      },
    );
  }
}

// ── Burbuja de mensaje ────────────────────────────────────────────────────────

class _BurbujaMensaje extends StatefulWidget {
  const _BurbujaMensaje({
    required this.mensaje,
    this.mostrarBotonEmergencia = false,
  });

  final MensajeModel mensaje;
  final bool mostrarBotonEmergencia;

  @override
  State<_BurbujaMensaje> createState() => _BurbujaMensajeState();
}

class _BurbujaMensajeState extends State<_BurbujaMensaje>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(widget.mensaje.esUsuario ? 0.08 : -0.08, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final esUsuario = widget.mensaje.esUsuario;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _BurbujaContenido(
          mensaje: widget.mensaje,
          mostrarBotonEmergencia: widget.mostrarBotonEmergencia,
          textTheme: textTheme,
          esUsuario: esUsuario,
        ),
      ),
    );
  }
}

class _BurbujaContenido extends StatelessWidget {
  const _BurbujaContenido({
    required this.mensaje,
    required this.mostrarBotonEmergencia,
    required this.textTheme,
    required this.esUsuario,
  });

  final MensajeModel mensaje;
  final bool mostrarBotonEmergencia;
  final TextTheme textTheme;
  final bool esUsuario;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esUsuario) ...[
            _AvatarIA(),
            const SizedBox(width: AppSpacing.xs),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Column(
              crossAxisAlignment: esUsuario
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: esUsuario ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(esUsuario ? 16 : 4),
                      bottomRight: Radius.circular(esUsuario ? 4 : 16),
                    ),
                    border: esUsuario
                        ? null
                        : Border.all(color: AppColors.surfaceVariant),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(esUsuario ? 30 : 10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: esUsuario
                      ? Text(
                          mensaje.texto,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        )
                      : MarkdownBody(
                          data: mensaje.texto,
                          shrinkWrap: true,
                          styleSheet: _mdStyle(textTheme),
                        ),
                ),
                if (mostrarBotonEmergencia) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _BotonEmergenciaContextual(),
                ],
              ],
            ),
          ),
          if (esUsuario) const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}

// Estilo markdown que hereda la tipografía Poppins y AppColors del tema.
MarkdownStyleSheet _mdStyle(TextTheme t) => MarkdownStyleSheet(
      p: t.bodyMedium?.copyWith(color: AppColors.textPrimary),
      strong: t.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      em: t.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        fontStyle: FontStyle.italic,
      ),
      h1: t.titleLarge?.copyWith(color: AppColors.textPrimary),
      h2: t.titleMedium?.copyWith(color: AppColors.textPrimary),
      h3: t.titleSmall?.copyWith(color: AppColors.textPrimary),
      listBullet: t.bodyMedium?.copyWith(color: AppColors.textPrimary),
      code: t.bodySmall?.copyWith(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.smBr,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      blockquotePadding:
          const EdgeInsets.only(left: AppSpacing.sm, top: 2, bottom: 2),
      pPadding: const EdgeInsets.only(bottom: 4),
      // Sin fondo adicional — la burbuja ya tiene su propio Container.
      blockSpacing: 8,
    );

class _AvatarIA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFFEDE5FF),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: SvgPicture.asset(
          'assets/il_asistente_avatar.svg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ── Indicador "escribiendo" ───────────────────────────────────────────────────

class _IndicadorEscribiendo extends StatefulWidget {
  const _IndicadorEscribiendo();

  @override
  State<_IndicadorEscribiendo> createState() => _IndicadorEscribiendoState();
}

class _IndicadorEscribiendoState extends State<_IndicadorEscribiendo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AvatarIA(),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (idx) => _Punto(anim: _anim, delay: idx * 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.anim, required this.delay});
  final AnimationController anim;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (ctx, child) {
        final t = ((anim.value + delay) % 1.0);
        final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha((opacity * 255).round()),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// ── Sugerencias rápidas ───────────────────────────────────────────────────────

class _SugerenciasRapidas extends StatelessWidget {
  const _SugerenciasRapidas({required this.onTap});
  final Future<void> Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sugerencias',
            style: textTheme.labelSmall
                ?.copyWith(color: AppColors.textDisabled),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: AppConstants.sugerenciasChat
                .map((s) => ActionChip(
                      label: Text(s),
                      onPressed: () => onTap(s),
                      side: const BorderSide(color: AppColors.primary),
                      labelStyle: textTheme.labelMedium
                          ?.copyWith(color: AppColors.primary),
                      backgroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: 2),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Área de entrada ───────────────────────────────────────────────────────────

class _InputArea extends StatelessWidget {
  const _InputArea({
    required this.controller,
    required this.onEnviar,
    required this.listenable,
  });

  final TextEditingController controller;
  final Future<void> Function(String) onEnviar;
  final ChatController listenable;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(
              top: BorderSide(color: AppColors.surfaceVariant)),
        ),
        child: ListenableBuilder(
          listenable: listenable,
          builder: (context, _) {
            final enviando = listenable.enviando;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !enviando,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu consulta...',
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textDisabled),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 10),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: AppRadius.xlBr,
                      ),
                    ),
                    onSubmitted: enviando ? null : onEnviar,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _BotonEnviar(enviando: enviando, onEnviar: () {
                  onEnviar(controller.text);
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BotonEnviar extends StatelessWidget {
  const _BotonEnviar({required this.enviando, required this.onEnviar});
  final bool enviando;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDuration.fast,
      width: 44,
      height: 44,
      child: enviando
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              ),
            )
          : FilledButton(
              onPressed: onEnviar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.send_rounded,
                  color: AppColors.onPrimary, size: 20),
            ),
    );
  }
}

// ── Bienvenida (chat vacío) ───────────────────────────────────────────────────

class _BienvenidaChat extends StatelessWidget {
  const _BienvenidaChat({required this.onSugerencia});
  final Future<void> Function(String) onSugerencia;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ilustración principal
            SvgPicture.asset(
              'assets/il_chat_welcome.svg',
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: AppSpacing.md),
            // Identidad del asistente
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE5FF),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.asset('assets/logo_csjb.png',
                          fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Asistente CSJB',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Estoy aquí para orientarte sobre síntomas,\nmedicamentos y salud general.',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            _SugerenciasRapidas(onTap: onSugerencia),
          ],
        ),
      ),
    );
  }
}

// ── Disclaimer banner (fijo debajo del AppBar) ────────────────────────────────

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      decoration: const BoxDecoration(
        color: Color(0xFFEDE5FF),
        border: Border(
          bottom: BorderSide(color: Color(0xFFD4C5F9), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.asset(
              'assets/logo_csjb.png',
              width: 18,
              height: 18,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Asistente CSJB — orientación informativa, no diagnóstico médico.',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón de emergencia contextual ───────────────────────────────────────────

class _BotonEmergenciaContextual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => mostrarDialogoEmergencia(context),
      icon: const Icon(Icons.emergency_rounded, size: 16),
      label: const Text('Ver números de emergencia'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.urgencyHigh,
        side: const BorderSide(color: AppColors.urgencyHigh),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        textStyle: Theme.of(context).textTheme.labelSmall,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Banner de error ───────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: AppColors.urgencyHighBg,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.urgencyHigh, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.urgencyHigh,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
