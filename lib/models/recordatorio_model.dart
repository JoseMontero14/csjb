import 'package:cloud_firestore/cloud_firestore.dart';

enum Frecuencia { cada8h, cada12h, unaVezAlDia, personalizado }

extension FrecuenciaX on Frecuencia {
  String get label => switch (this) {
        Frecuencia.cada8h => 'Cada 8h',
        Frecuencia.cada12h => 'Cada 12h',
        Frecuencia.unaVezAlDia => 'Una vez al día',
        Frecuencia.personalizado => 'Personalizado',
      };

  static Frecuencia fromString(String v) => switch (v) {
        'Cada 8h' => Frecuencia.cada8h,
        'Cada 12h' => Frecuencia.cada12h,
        'Una vez al día' => Frecuencia.unaVezAlDia,
        _ => Frecuencia.personalizado,
      };
}

class RecordatorioModel {
  const RecordatorioModel({
    required this.id,
    required this.uid,
    required this.medicamento,
    required this.dosis,
    required this.frecuencia,
    required this.horarios,
    required this.fechaInicio,
    required this.sinFechaFin,
    this.fechaFin,
    this.notas,
  });

  final String id;
  final String uid;
  final String medicamento;
  final String dosis;
  final Frecuencia frecuencia;
  final List<String> horarios; // "HH:mm"
  final DateTime fechaInicio;
  final bool sinFechaFin;
  final DateTime? fechaFin;
  final String? notas;

  factory RecordatorioModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RecordatorioModel(
      id: doc.id,
      uid: d['uid'] as String,
      medicamento: d['medicamento'] as String,
      dosis: d['dosis'] as String,
      frecuencia: FrecuenciaX.fromString(d['frecuencia'] as String),
      horarios: List<String>.from(d['horarios'] as List),
      fechaInicio: (d['fechaInicio'] as Timestamp).toDate(),
      sinFechaFin: d['sinFechaFin'] as bool? ?? true,
      fechaFin: d['fechaFin'] != null
          ? (d['fechaFin'] as Timestamp).toDate()
          : null,
      notas: d['notas'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'medicamento': medicamento,
        'dosis': dosis,
        'frecuencia': frecuencia.label,
        'horarios': horarios,
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        'sinFechaFin': sinFechaFin,
        if (fechaFin != null) 'fechaFin': Timestamp.fromDate(fechaFin!),
        if (notas != null && notas!.isNotEmpty) 'notas': notas,
      };

  bool get activo {
    final hoy = DateTime.now();
    if (hoy.isBefore(fechaInicio)) return false;
    if (!sinFechaFin && fechaFin != null && hoy.isAfter(fechaFin!)) {
      return false;
    }
    return true;
  }
}
