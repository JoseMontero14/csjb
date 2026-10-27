import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/chat_controller.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

class ChatListaView extends StatefulWidget {
  const ChatListaView({super.key});

  @override
  State<ChatListaView> createState() => _ChatListaViewState();
}

class _ChatListaViewState extends State<ChatListaView> {
  final _controller = ChatController();

  @override
  void initState() {
    super.initState();
    _controller.cargarChats(_uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _nuevaConsulta() async {
    await AppRoutes.push(context, AppRoutes.chatDetalle);
    if (mounted) _controller.cargarChats(_uid);
  }

  Future<void> _abrirChat(String chatId) async {
    await AppRoutes.push(context, AppRoutes.chatDetalle, args: chatId);
    if (mounted) _controller.cargarChats(_uid);
  }

  Future<bool?> _confirmarEliminar() => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar conversación'),
          content: const Text(
              '¿Quieres eliminar esta conversación? No se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.urgencyHigh),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

  Future<void> _eliminarChat(String chatId) =>
      _controller.eliminarChat(chatId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chat IA'),
            Text(
              'Orientación médica 24/7',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary.withAlpha(160),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ClipOval(
              child: Image.asset('assets/logo_csjb.png',
                  width: 28, height: 28, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.chats.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _nuevaConsulta,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva consulta'),
          );
        },
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.cargandoLista) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (_controller.chats.isEmpty) {
            return _EstadoVacio(onNuevaConsulta: _nuevaConsulta);
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _controller.cargarChats(_uid),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
              itemCount: _controller.chats.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) return _HeaderAsistente(onNuevaConsulta: _nuevaConsulta);
                if (i == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(
                        top: AppSpacing.md, bottom: AppSpacing.sm),
                    child: Text(
                      'Consultas recientes',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  );
                }
                final chat = _controller.chats[i - 2];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Dismissible(
                    key: ValueKey(chat.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmarEliminar(),
                    onDismissed: (_) => _eliminarChat(chat.id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.urgencyHighBg,
                        borderRadius: AppRadius.lgBr,
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.urgencyHigh),
                    ),
                    child: _ChatCard(
                      titulo: chat.titulo,
                      preview: chat.preview,
                      fecha: chat.creadoEn,
                      onTap: () => _abrirChat(chat.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Header asistente ──────────────────────────────────────────────────────────

class _HeaderAsistente extends StatelessWidget {
  const _HeaderAsistente({required this.onNuevaConsulta});
  final VoidCallback onNuevaConsulta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.xs),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF5B2D8E), Color(0xFF7B3FB8)],
        ),
        borderRadius: AppRadius.xlBr,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Círculo decorativo
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(12),
              ),
            ),
          ),
          // Ilustración SVG a la derecha
          Positioned(
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.25,
              child: SvgPicture.asset(
                'assets/il_chat_empty.svg',
                height: 110,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge "En línea 24/7"
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: AppRadius.fullBr,
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'En línea 24/7',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Asistente médico IA',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Orientación informativa,\nno reemplaza al médico.',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Botón Consultar
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: onNuevaConsulta,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.fullBr),
                      textStyle: textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Consultar'),
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

// Color de avatar para chat card según hash del título
({Color bg, Color icon}) _paletaChat(String titulo) {
  const opciones = [
    (bg: Color(0xFFEDE5FF), icon: AppColors.primary),
    (bg: Color(0xFFD1EFEC), icon: Color(0xFF00697A)),
    (bg: Color(0xFFE3F2FD), icon: Color(0xFF1976D2)),
    (bg: Color(0xFFFFF3E0), icon: Color(0xFFF59E0B)),
  ];
  return opciones[titulo.hashCode.abs() % opciones.length];
}

// ── Chat card ─────────────────────────────────────────────────────────────────

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.titulo,
    required this.fecha,
    required this.onTap,
    this.preview,
  });

  final String titulo;
  final String? preview;
  final DateTime fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hoy = DateTime.now();
    final mismaFecha = fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
    final fechaStr = mismaFecha
        ? DateFormat('HH:mm', 'es').format(fecha)
        : DateFormat('d MMM', 'es').format(fecha);

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgBr,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBr,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          child: Row(
            children: [
              // Avatar asistente IA con color variado por título
              Builder(builder: (ctx) {
                final paleta = _paletaChat(titulo);
                return Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: paleta.bg,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: SvgPicture.asset(
                      'assets/il_asistente_avatar.svg',
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(paleta.icon, BlendMode.srcIn),
                    ),
                  ),
                );
              }),
              const SizedBox(width: AppSpacing.md),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          fechaStr,
                          style: textTheme.labelSmall
                              ?.copyWith(color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textDisabled, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.onNuevaConsulta});
  final VoidCallback onNuevaConsulta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/il_chat_empty.svg',
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Aún no tienes consultas',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'El asistente de la Clínica San Juan Bautista\npuede orientarte sobre síntomas y salud.',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Iniciar consulta',
              onPressed: onNuevaConsulta,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
