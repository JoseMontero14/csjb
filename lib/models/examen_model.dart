import 'package:cloud_firestore/cloud_firestore.dart';

class ExamenModel {
  ExamenModel({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.queEs,
    required this.paraQueSirve,
    required this.requierePreparacion,
    this.indicacionesPreparacion,
  });

  final String id;
  final String nombre;
  final String categoria;
  final String queEs;
  final String paraQueSirve;
  final bool requierePreparacion;
  final String? indicacionesPreparacion;

  static ExamenModel fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ExamenModel(
      id: doc.id,
      nombre: d['nombre'] as String,
      categoria: d['categoria'] as String,
      queEs: d['queEs'] as String,
      paraQueSirve: d['paraQueSirve'] as String,
      requierePreparacion: d['requierePreparacion'] as bool? ?? false,
      indicacionesPreparacion: d['indicacionesPreparacion'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'categoria': categoria,
        'queEs': queEs,
        'paraQueSirve': paraQueSirve,
        'requierePreparacion': requierePreparacion,
        if (indicacionesPreparacion != null)
          'indicacionesPreparacion': indicacionesPreparacion,
      };
}
