import 'package:cloud_firestore/cloud_firestore.dart';

class MedicoModel {
  MedicoModel({
    required this.id,
    required this.nombre,
    required this.especialidad,
    required this.fotoUrl,
    required this.dias,
    required this.horario,
    required this.descripcionEspecialidad,
  });

  final String id;
  final String nombre;
  final String especialidad;
  final String fotoUrl;
  final List<String> dias;
  final String horario;
  final String descripcionEspecialidad;

  static MedicoModel fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MedicoModel(
      id: doc.id,
      nombre: d['nombre'] as String,
      especialidad: d['especialidad'] as String,
      fotoUrl: d['fotoUrl'] as String? ?? d['foto_url'] as String? ?? '',
      dias: List<String>.from(d['dias'] as List? ?? []),
      horario: d['horario'] as String,
      descripcionEspecialidad: d['descripcionEspecialidad'] as String,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'especialidad': especialidad,
        'fotoUrl': fotoUrl,
        'dias': dias,
        'horario': horario,
        'descripcionEspecialidad': descripcionEspecialidad,
      };
}
