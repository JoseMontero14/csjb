import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/chat_controller.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';

const _kUidPlaceholder = 'uid-placeholder';

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
    _controller.cargarChats(_kUidPlaceholder);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _nuevaConsulta() async {
    await AppRoutes.push(context, AppRoutes.chatDetalle);
    if (mounted) _controller.cargarChats(_kUidPlaceholder);
  }

  Future<void> _abrirChat(String chatId) async {
    await AppRoutes.push(context, AppRoutes.chatDetalle, args: chatId);
    if (mounted) _controller.cargarChats(_kUidPlaceholder);
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
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.urgencyHigh),
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
      appBar: AppBar(title: const Text('Chat IA')),
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
            onRefresh: () => _controller.cargarChats(_kUidPlaceholder),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              itemCount: _controller.chats.length,
              separatorBuilder: (context2, i2) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final chat = _controller.chats[i];
                return Dismissible(
                  key: ValueKey(chat.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmarEliminar(),
                  onDismissed: (_) => _eliminarChat(chat.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    color: AppColors.urgencyHighBg,
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.urgencyHigh),
                  ),
                  child: _ChatTile(
                    titulo: chat.titulo,
                    preview: chat.preview,
                    fecha: chat.creadoEn,
                    onTap: () => _abrirChat(chat.id),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaConsulta,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva consulta'),
      ),
    );
  }
}

// ── Chat tile ─────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  const _ChatTile({
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

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.mdBr,
        ),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            color: AppColors.primary, size: 22),
      ),
      title: Text(
        titulo,
        style: textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: preview != null
          ? Text(
              preview!,
              style: textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(fechaStr,
          style: textTheme.labelSmall
              ?.copyWith(color: AppColors.textDisabled)),
      onTap: onTap,
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
            Icon(Icons.chat_bubble_outline_rounded,
                size: 72, color: AppColors.surfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin consultas aún',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Escríbele al asistente tus dudas sobre síntomas, '
              'medicamentos o salud en general.',
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
