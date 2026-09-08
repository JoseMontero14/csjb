import 'package:cloud_firestore/cloud_firestore.dart';

class MensajeModel {
  const MensajeModel({
    required this.id,
    required this.rol,
    required this.texto,
    required this.timestamp,
  });

  final String id;

  /// 'user' | 'assistant'
  final String rol;
  final String texto;
  final DateTime timestamp;

  bool get esUsuario => rol == 'user';

  factory MensajeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return MensajeModel(
      id: doc.id,
      rol: data['rol'] as String,
      texto: data['texto'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'rol': rol,
        'texto': texto,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
