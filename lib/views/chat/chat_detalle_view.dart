import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../controllers/chat_controller.dart';
import '../../models/mensaje_model.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/emergencia_dialog.dart';

const _kUidPlaceholder = 'uid-placeholder';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      final chatId =
          ModalRoute.of(context)?.settings.arguments as String?;
      _controller.iniciarChat(_kUidPlaceholder, chatId: chatId);
      _inicializado = true;
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
        title: const Text('Asistente CSJB'),
        leading: const BackButton(),
      ),
      body: Column(
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

class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({
    required this.mensaje,
    this.mostrarBotonEmergencia = false,
  });

  final MensajeModel mensaje;
  final bool mostrarBotonEmergencia;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final esUsuario = mensaje.esUsuario;

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
          Flexible(
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
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.fullBr,
      ),
      child: const Icon(Icons.health_and_safety_rounded,
          color: AppColors.primary, size: 16),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.health_and_safety_rounded,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Asistente de orientación médica',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Puedo orientarte sobre síntomas, medicamentos y salud general. '
              'Recuerda que no reemplaza la consulta médica.',
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
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      color: AppColors.surfaceVariant,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textSecondary, size: 14),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Orientación informativa — no reemplaza la consulta médica. '
              'Las respuestas generadas por IA pueden contener imprecisiones.',
              style: textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
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
