import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  const ChatModel({
    required this.id,
    required this.uid,
    required this.titulo,
    required this.creadoEn,
    this.preview,
  });

  final String id;
  final String uid;
  final String titulo;
  final DateTime creadoEn;
  final String? preview;

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      uid: data['uid'] as String,
      titulo: data['titulo'] as String? ?? 'Nueva consulta',
      creadoEn: (data['creadoEn'] as Timestamp).toDate(),
      preview: data['preview'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'titulo': titulo,
        'creadoEn': Timestamp.fromDate(creadoEn),
        if (preview != null) 'preview': preview,
      };

  ChatModel copyWith({String? titulo, String? preview}) => ChatModel(
        id: id,
        uid: uid,
        titulo: titulo ?? this.titulo,
        creadoEn: creadoEn,
        preview: preview ?? this.preview,
      );
}
