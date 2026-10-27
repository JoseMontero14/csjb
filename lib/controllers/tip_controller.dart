import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/tip_model.dart';
import '../models/usuario_model.dart';
import '../services/gemini_service.dart';

enum TipStatus { idle, cargando, listo, error }

class TipController extends ChangeNotifier {
  TipController({GeminiService? gemini})
      : _gemini = gemini ?? GeminiService();

  final GeminiService _gemini;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TipStatus _status = TipStatus.idle;

  /// Los 2 tips del día (puede estar vacío si aún no se cargaron).
  List<TipModel> _tipsHoy = [];
  String? _errorMessage;

  TipStatus get status => _status;
  List<TipModel> get tipsHoy => _tipsHoy;
  String? get errorMessage => _errorMessage;
  bool get cargando => _status == TipStatus.cargando;

  /// Carga los 2 tips del día para [uid].
  /// Cache-first: reutiliza tips de hoy si existen, genera los que faltan si no.
  /// Fallback: si la generación falla, intenta mostrar tips de ayer.
  Future<void> cargar(String uid, UsuarioModel usuario) async {
    if (uid.isEmpty) return;
    _status = TipStatus.cargando;
    _errorMessage = null;
    notifyListeners();

    try {
      final hoy = _inicioDia(DateTime.now());
      final existentes = await _buscarTipsHoy(uid, hoy);

      if (existentes.length >= 2) {
        _tipsHoy = existentes.take(2).toList();
        _status = TipStatus.listo;
      } else {
        try {
          _tipsHoy = await _generarYGuardar(uid, usuario, hoy);
          _status = TipStatus.listo;
        } catch (e) {
          debugPrint('TipController._generarYGuardar ERROR [${e.runtimeType}]: $e');
          // Fallback: intentar tips del día anterior
          final ayer = hoy.subtract(const Duration(days: 1));
          final tipsAyer = await _buscarTipsEnRango(uid, ayer, hoy);
          if (tipsAyer.isNotEmpty) {
            _tipsHoy = tipsAyer.take(2).toList();
            _status = TipStatus.listo;
          } else {
            final es429 = e.toString().contains('429') ||
                e.toString().toLowerCase().contains('demasiadas');
            _errorMessage = es429
                ? 'Tips disponibles mañana. La IA está descansando 😄'
                : 'No se pudo cargar los tips del día.';
            _status = TipStatus.error;
          }
        }
      }
    } catch (e, st) {
      debugPrint('TipController.cargar ERROR [${e.runtimeType}]: $e\n$st');
      _errorMessage = 'No se pudo cargar los tips del día.';
      _status = TipStatus.error;
    }

    notifyListeners();
  }

  Future<List<TipModel>> _buscarTipsHoy(String uid, DateTime hoy) async {
    final manana = hoy.add(const Duration(days: 1));
    final snap = await _db
        .collection('tips_diarios')
        .where('uid', isEqualTo: uid)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hoy))
        .where('fecha', isLessThan: Timestamp.fromDate(manana))
        .orderBy('fecha', descending: false)
        .limit(2)
        .get();

    return snap.docs.map(TipModel.fromFirestore).toList();
  }

  Future<List<TipModel>> _buscarTipsEnRango(
    String uid,
    DateTime desde,
    DateTime hasta,
  ) async {
    final snap = await _db
        .collection('tips_diarios')
        .where('uid', isEqualTo: uid)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThan: Timestamp.fromDate(hasta))
        .orderBy('fecha', descending: false)
        .limit(2)
        .get();

    return snap.docs.map(TipModel.fromFirestore).toList();
  }

  Future<List<TipModel>> _generarYGuardar(
    String uid,
    UsuarioModel usuario,
    DateTime hoy,
  ) async {
    final resultados = await _gemini.generarTipDelDia(usuario);
    final batch = _db.batch();
    final refs = <DocumentReference>[];

    for (final r in resultados) {
      final ref = _db.collection('tips_diarios').doc();
      refs.add(ref);
      batch.set(ref, TipModel(
        id: ref.id,
        texto: r.texto,
        categoria: r.categoria,
        fecha: hoy,
        generadoPor: 'gemini',
        uid: uid,
      ).toFirestore());
    }

    await batch.commit();

    return [
      for (var i = 0; i < resultados.length; i++)
        TipModel(
          id: refs[i].id,
          texto: resultados[i].texto,
          categoria: resultados[i].categoria,
          fecha: hoy,
          generadoPor: 'gemini',
          uid: uid,
        ),
    ];
  }

  DateTime _inicioDia(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
