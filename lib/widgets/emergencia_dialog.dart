import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';

void mostrarDialogoEmergencia(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _EmergenciaSheet(),
  );
}

class _EmergenciaSheet extends StatelessWidget {
  const _EmergenciaSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.urgencyHighBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emergency_rounded,
                color: AppColors.urgencyHigh, size: 32),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Números de emergencia',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text('Llama solo en caso de emergencia real',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),

          // Contactos
          _ContactoCard(
            nombre: 'SAMU',
            descripcion: 'Emergencias médicas',
            numero: '106',
            bg: const Color(0xFFFFE8E8),
            iconColor: AppColors.urgencyHigh,
            icono: Icons.local_hospital_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ContactoCard(
            nombre: 'Bomberos',
            descripcion: 'Incendios y rescate',
            numero: '116',
            bg: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
            icono: Icons.fire_truck_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ContactoCard(
            nombre: 'Policía',
            descripcion: 'Seguridad ciudadana',
            numero: '105',
            bg: const Color(0xFFE8EAF6),
            iconColor: const Color(0xFF283593),
            icono: Icons.local_police_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactoCard extends StatelessWidget {
  const _ContactoCard({
    required this.nombre,
    required this.descripcion,
    required this.numero,
    required this.bg,
    required this.iconColor,
    required this.icono,
  });

  final String nombre;
  final String descripcion;
  final String numero;
  final Color bg;
  final Color iconColor;
  final IconData icono;

  Future<void> _confirmarLlamada(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nombre),
        content: Text('¿Llamar al número de $nombre ($numero)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Llamar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final url = Uri.parse('tel:$numero');
    if (!await launchUrl(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el marcador.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.lgBr,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: AppRadius.mdBr,
            ),
            child: Icon(icono, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(descripcion,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _confirmarLlamada(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: AppRadius.fullBr,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(numero,
                      style: textTheme.labelLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
