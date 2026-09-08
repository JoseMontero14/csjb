import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Muestra el diálogo de contactos de emergencia.
/// Reutilizable desde cualquier módulo sin duplicar lógica.
void mostrarDialogoEmergencia(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppColors.urgencyHigh),
          const SizedBox(width: AppSpacing.sm),
          Text('Emergencia',
              style: Theme.of(ctx).textTheme.headlineSmall),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Contacto(
            nombre: 'SAMU',
            numero: '106',
            icono: Icons.local_hospital_rounded,
          ),
          Divider(),
          _Contacto(
            nombre: 'Bomberos',
            numero: '116',
            icono: Icons.fire_truck_rounded,
          ),
          Divider(),
          _Contacto(
            nombre: 'Policía',
            numero: '105',
            icono: Icons.local_police_rounded,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class _Contacto extends StatelessWidget {
  const _Contacto({
    required this.nombre,
    required this.numero,
    required this.icono,
  });

  final String nombre;
  final String numero;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: AppColors.urgencyHigh),
      title:
          Text(nombre, style: Theme.of(context).textTheme.titleSmall),
      trailing: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.phone_rounded, size: 16),
        label: Text(numero),
        style:
            TextButton.styleFrom(foregroundColor: AppColors.urgencyHigh),
      ),
    );
  }
}
