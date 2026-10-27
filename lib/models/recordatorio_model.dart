import 'package:cloud_firestore/cloud_firestore.dart';

enum Frecuencia {
  unaVez,
  dosVeces,
  tresVeces,
  segunNecesidad,
  // Alias legacy para documentos anteriores en Firestore
  cada8h,
  cada12h,
  unaVezAlDia,
  personalizado,
}

extension FrecuenciaX on Frecuencia {
  String get label => switch (this) {
        Frecuencia.unaVez => 'Una vez al día',
        Frecuencia.dosVeces => 'Dos veces al día',
        Frecuencia.tresVeces => 'Tres veces al día',
        Frecuencia.segunNecesidad => 'Cuando sea necesario',
        // Legacy
        Frecuencia.cada8h => 'Cada 8h',
        Frecuencia.cada12h => 'Cada 12h',
        Frecuencia.unaVezAlDia => 'Una vez al día',
        Frecuencia.personalizado => 'Personalizado',
      };

  /// Cuántas tomas diarias programadas tiene esta frecuencia.
  /// 0 = sin recordatorio (segunNecesidad).
  int get cantidadTomas => switch (this) {
        Frecuencia.unaVez || Frecuencia.unaVezAlDia => 1,
        Frecuencia.dosVeces || Frecuencia.cada12h => 2,
        Frecuencia.tresVeces || Frecuencia.cada8h => 3,
        Frecuencia.personalizado => 1,
        Frecuencia.segunNecesidad => 0,
      };

  bool get conRecordatorio => cantidadTomas > 0;

  static Frecuencia fromString(String v) => switch (v) {
        'Una vez al día' => Frecuencia.unaVez,
        'Dos veces al día' => Frecuencia.dosVeces,
        'Tres veces al día' => Frecuencia.tresVeces,
        'Cuando sea necesario' => Frecuencia.segunNecesidad,
        'Cada 8h' => Frecuencia.cada8h,
        'Cada 12h' => Frecuencia.cada12h,
        'Personalizado' => Frecuencia.personalizado,
        _ => Frecuencia.unaVez,
      };
}

class RecordatorioModel {
  const RecordatorioModel({
    required this.id,
    required this.uid,
    required this.medicamento,
    required this.presentacion,
    required this.frecuencia,
    required this.horarios,
    required this.fechaInicio,
    required this.sinFechaFin,
    this.dosis = '',
    this.fechaFin,
    this.notas,
  });

  final String id;
  final String uid;
  final String medicamento;
  final String presentacion;
  final String dosis;
  final Frecuencia frecuencia;
  final List<String> horarios; // "HH:mm"
  final DateTime fechaInicio;
  final bool sinFechaFin;
  final DateTime? fechaFin;
  final String? notas;

  String get nombreCompleto => presentacion.isEmpty
      ? medicamento
      : '$medicamento $presentacion';

  factory RecordatorioModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RecordatorioModel(
      id: doc.id,
      uid: d['uid'] as String,
      medicamento: d['medicamento'] as String,
      presentacion: d['presentacion'] as String? ?? '',
      dosis: d['dosis'] as String? ?? '',
      frecuencia: FrecuenciaX.fromString(d['frecuencia'] as String? ?? ''),
      horarios: List<String>.from(d['horarios'] as List? ?? []),
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
        'presentacion': presentacion,
        if (dosis.isNotEmpty) 'dosis': dosis,
        'frecuencia': frecuencia.label,
        'horarios': horarios,
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        'sinFechaFin': sinFechaFin,
        if (fechaFin != null) 'fechaFin': Timestamp.fromDate(fechaFin!),
        if (notas != null && notas!.isNotEmpty) 'notas': notas,
      };

  RecordatorioModel copyWith({
    String? id,
    String? uid,
    String? medicamento,
    String? presentacion,
    String? dosis,
    Frecuencia? frecuencia,
    List<String>? horarios,
    DateTime? fechaInicio,
    bool? sinFechaFin,
    DateTime? fechaFin,
    String? notas,
  }) =>
      RecordatorioModel(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        medicamento: medicamento ?? this.medicamento,
        presentacion: presentacion ?? this.presentacion,
        dosis: dosis ?? this.dosis,
        frecuencia: frecuencia ?? this.frecuencia,
        horarios: horarios ?? this.horarios,
        fechaInicio: fechaInicio ?? this.fechaInicio,
        sinFechaFin: sinFechaFin ?? this.sinFechaFin,
        fechaFin: fechaFin ?? this.fechaFin,
        notas: notas ?? this.notas,
      );

  bool get activo {
    final hoy = DateTime.now();
    if (hoy.isBefore(fechaInicio)) return false;
    if (!sinFechaFin && fechaFin != null && hoy.isAfter(fechaFin!)) {
      return false;
    }
    return true;
  }
}
