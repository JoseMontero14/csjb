import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<String> agregarRecordatorio(RecordatorioModel recordatorio) async {
    final ref = await _db
        .collection('recordatorios')
        .add(recordatorio.toFirestore());
    return ref.id;
  }

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
}
