import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/mensaje_model.dart';
import '../models/recordatorio_model.dart';
import '../models/toma_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Recordatorios ──────────────────────────────────────────────────────────

  Future<List<RecordatorioModel>> getRecordatoriosActivos(String uid) async {
    final snap = await _db
        .collection('recordatorios')
        .where('uid', isEqualTo: uid)
        .get();
    return snap.docs
        .map(RecordatorioModel.fromFirestore)
        .where((r) => r.activo)
        .toList();
  }

  /// Stream en tiempo real de los recordatorios activos del usuario.
  Stream<List<RecordatorioModel>> streamRecordatoriosActivos(String uid) {
    return _db
        .collection('recordatorios')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map(RecordatorioModel.fromFirestore)
            .where((r) => r.activo)
            .toList());
  }

  Future<String> agregarRecordatorio(RecordatorioModel recordatorio) async {
    final ref = await _db
        .collection('recordatorios')
        .add(recordatorio.toFirestore());
    return ref.id;
  }

  Future<void> actualizarRecordatorio(
    String recordatorioId,
    RecordatorioModel recordatorio,
  ) =>
      _db
          .collection('recordatorios')
          .doc(recordatorioId)
          .update(recordatorio.toFirestore());

  Future<void> eliminarRecordatorio(String recordatorioId) =>
      _db.collection('recordatorios').doc(recordatorioId).delete();

  // ── Tomas ──────────────────────────────────────────────────────────────────

  /// Obtiene (o crea) las tomas de hoy para todos los recordatorios activos.
  Future<List<TomaConRecordatorio>> getTomasHoy(String uid) async {
    final recordatorios = await getRecordatoriosActivos(uid);
    final hoy = _soloFecha(DateTime.now());
    final resultado = <TomaConRecordatorio>[];

    for (final rec in recordatorios) {
      for (final hora in rec.horarios) {
        // Buscar si ya existe la toma de hoy para este horario
        final snap = await _db
            .collection('recordatorios')
            .doc(rec.id)
            .collection('historial_tomas')
            .where('fecha', isEqualTo: Timestamp.fromDate(hoy))
            .where('hora', isEqualTo: hora)
            .limit(1)
            .get();

        TomaModel toma;
        if (snap.docs.isEmpty) {
          // Crear la toma pendiente automáticamente
          final data = TomaModel(
            id: '',
            recordatorioId: rec.id,
            fecha: hoy,
            hora: hora,
            tomado: false,
          );
          final ref = await _db
              .collection('recordatorios')
              .doc(rec.id)
              .collection('historial_tomas')
              .add(data.toFirestore());
          toma = TomaModel(
            id: ref.id,
            recordatorioId: rec.id,
            fecha: hoy,
            hora: hora,
            tomado: false,
          );
        } else {
          toma = TomaModel.fromFirestore(snap.docs.first, rec.id);
        }

        resultado.add(TomaConRecordatorio(
          toma: toma,
          medicamento: rec.medicamento,
          presentacion: rec.presentacion,
          dosis: rec.dosis,
        ));
      }
    }

    // Ordenar por hora
    resultado.sort((a, b) => a.toma.hora.compareTo(b.toma.hora));
    return resultado;
  }

  Future<void> marcarToma(
    String recordatorioId,
    String tomaId,
    bool tomado,
  ) =>
      _db
          .collection('recordatorios')
          .doc(recordatorioId)
          .collection('historial_tomas')
          .doc(tomaId)
          .update({'tomado': tomado});

  /// Alias llamado desde el handler de notificaciones en background.
  Future<void> marcarTomaDesdeNotificacion(
    String recordatorioId,
    String tomaId,
    bool tomado,
  ) =>
      marcarToma(recordatorioId, tomaId, tomado);

  /// Calcula porcentaje de adherencia de los últimos 7 días (0.0 – 1.0).
  Future<double> getAdherenciaSemanal(String uid) async {
    final recordatorios = await getRecordatoriosActivos(uid);
    if (recordatorios.isEmpty) return 0;

    final hoy = _soloFecha(DateTime.now());
    final hace7 = hoy.subtract(const Duration(days: 6));
    int total = 0;
    int tomadas = 0;

    for (final rec in recordatorios) {
      final snap = await _db
          .collection('recordatorios')
          .doc(rec.id)
          .collection('historial_tomas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hace7))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hoy))
          .get();
      for (final doc in snap.docs) {
        total++;
        if (doc['tomado'] == true) tomadas++;
      }
    }

    return total == 0 ? 0 : tomadas / total;
  }

  DateTime _soloFecha(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // ── Chats IA ───────────────────────────────────────────────────────────────

  Future<List<ChatModel>> getChats(String uid) async {
    final snap = await _db
        .collection('chats_ia')
        .where('uid', isEqualTo: uid)
        .orderBy('creadoEn', descending: true)
        .get();
    return snap.docs.map(ChatModel.fromFirestore).toList();
  }

  Future<String> crearChat(ChatModel chat) async {
    final ref = await _db.collection('chats_ia').add(chat.toFirestore());
    return ref.id;
  }

  Future<void> actualizarChat(String chatId, {String? titulo, String? preview}) =>
      _db.collection('chats_ia').doc(chatId).update({
        'titulo': titulo,
        'preview': preview,
      }..removeWhere((_, v) => v == null));

  Future<List<MensajeModel>> getMensajes(String chatId) async {
    final snap = await _db
        .collection('chats_ia')
        .doc(chatId)
        .collection('mensajes')
        .orderBy('timestamp')
        .get();
    return snap.docs.map(MensajeModel.fromFirestore).toList();
  }

  Future<MensajeModel> agregarMensaje(
      String chatId, MensajeModel mensaje) async {
    final ref = await _db
        .collection('chats_ia')
        .doc(chatId)
        .collection('mensajes')
        .add(mensaje.toFirestore());
    return MensajeModel(
      id: ref.id,
      rol: mensaje.rol,
      texto: mensaje.texto,
      timestamp: mensaje.timestamp,
    );
  }

  /// Elimina un chat y todos sus mensajes en un batch atómico.
  Future<void> eliminarChat(String chatId) async {
    final mensajesSnap = await _db
        .collection('chats_ia')
        .doc(chatId)
        .collection('mensajes')
        .get();
    final batch = _db.batch();
    for (final doc in mensajesSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('chats_ia').doc(chatId));
    await batch.commit();
  }
}
