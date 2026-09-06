import 'package:cloud_firestore/cloud_firestore.dart';

class TomaModel {
  const TomaModel({
    required this.id,
    required this.recordatorioId,
    required this.fecha,
    required this.hora,
    required this.tomado,
  });

  final String id;
  final String recordatorioId;
  final DateTime fecha;
  final String hora; // "HH:mm"
  final bool tomado;

  factory TomaModel.fromFirestore(DocumentSnapshot doc, String recId) {
    final d = doc.data() as Map<String, dynamic>;
    return TomaModel(
      id: doc.id,
      recordatorioId: recId,
      fecha: (d['fecha'] as Timestamp).toDate(),
      hora: d['hora'] as String,
      tomado: d['tomado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fecha': Timestamp.fromDate(fecha),
        'hora': hora,
        'tomado': tomado,
      };

  TomaModel copyWith({bool? tomado}) => TomaModel(
        id: id,
        recordatorioId: recordatorioId,
        fecha: fecha,
        hora: hora,
        tomado: tomado ?? this.tomado,
      );
}

// Agrupa toma con su recordatorio para mostrar en la lista de "Hoy"
class TomaConRecordatorio {
  const TomaConRecordatorio({required this.toma, required this.medicamento, required this.dosis});
  final TomaModel toma;
  final String medicamento;
  final String dosis;
}
