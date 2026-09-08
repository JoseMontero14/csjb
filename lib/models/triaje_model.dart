import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme.dart';

enum IntensidadSintomas { leve, moderada, intensa }

extension IntensidadSintomasX on IntensidadSintomas {
  String get label => switch (this) {
        IntensidadSintomas.leve => 'Leve',
        IntensidadSintomas.moderada => 'Moderada',
        IntensidadSintomas.intensa => 'Intensa',
      };
}

class TriajeModel {
  TriajeModel({
    this.id,
    required this.uid,
    required this.sintomas,
    required this.intensidad,
    required this.duracionSintomas,
    required this.nivelUrgencia,
    required this.recomendacion,
    required this.fecha,
    this.especialidadSugerida,
    this.guardado = false,
  });

  final String? id;
  final String uid;
  final List<String> sintomas;
  final IntensidadSintomas intensidad;
  final String duracionSintomas;
  final UrgencyLevel nivelUrgencia;
  final String recomendacion;
  final String? especialidadSugerida;
  final DateTime fecha;
  final bool guardado;

  TriajeModel copyWith({String? id, bool? guardado}) => TriajeModel(
        id: id ?? this.id,
        uid: uid,
        sintomas: sintomas,
        intensidad: intensidad,
        duracionSintomas: duracionSintomas,
        nivelUrgencia: nivelUrgencia,
        recomendacion: recomendacion,
        especialidadSugerida: especialidadSugerida,
        fecha: fecha,
        guardado: guardado ?? this.guardado,
      );

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'sintomas': sintomas,
        'intensidad': intensidad.label,
        'duracionSintomas': duracionSintomas,
        'nivelUrgencia': nivelUrgencia.name,
        'recomendacion': recomendacion,
        if (especialidadSugerida != null)
          'especialidadSugerida': especialidadSugerida,
        'fecha': Timestamp.fromDate(fecha),
        'guardado': true,
      };

  static TriajeModel fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TriajeModel(
      id: doc.id,
      uid: d['uid'] as String,
      sintomas: List<String>.from(d['sintomas'] as List),
      intensidad: IntensidadSintomas.values.firstWhere(
        (e) => e.label == d['intensidad'],
        orElse: () => IntensidadSintomas.moderada,
      ),
      duracionSintomas: d['duracionSintomas'] as String,
      nivelUrgencia: UrgencyLevel.values.firstWhere(
        (e) => e.name == d['nivelUrgencia'],
        orElse: () => UrgencyLevel.medium,
      ),
      recomendacion: d['recomendacion'] as String,
      especialidadSugerida: d['especialidadSugerida'] as String?,
      fecha: (d['fecha'] as Timestamp).toDate(),
      guardado: d['guardado'] as bool? ?? true,
    );
  }
}
