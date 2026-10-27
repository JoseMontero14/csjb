import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/recordatorio_model.dart';
import '../models/toma_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

enum MedicacionStatus { idle, loading, loaded, error }

class MedicacionController extends ChangeNotifier {
  MedicacionController({FirestoreService? service})
      : _service = service ?? FirestoreService();

  final FirestoreService _service;
  StreamSubscription<List<RecordatorioModel>>? _sub;

  MedicacionStatus _status = MedicacionStatus.idle;
  List<TomaConRecordatorio> _tomasHoy = [];
  List<RecordatorioModel> _recordatorios = [];
  double _adherenciaSemanal = 0;
  String? _errorMessage;
  String? _uid;

  MedicacionStatus get status => _status;
  List<TomaConRecordatorio> get tomasHoy => _tomasHoy;
  List<RecordatorioModel> get recordatorios => _recordatorios;
  double get adherenciaSemanal => _adherenciaSemanal;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == MedicacionStatus.loading;

  int get totalHoy => _tomasHoy.length;
  int get tomadasHoy => _tomasHoy.where((t) => t.toma.tomado).length;

  /// Tomas de hoy agrupadas por recordatorioId.
  Map<String, List<TomaConRecordatorio>> get tomasAgrupadas {
    final mapa = <String, List<TomaConRecordatorio>>{};
    for (final t in _tomasHoy) {
      mapa.putIfAbsent(t.toma.recordatorioId, () => []).add(t);
    }
    return mapa;
  }

  RecordatorioModel? recordatorioPorId(String recId) {
    try {
      return _recordatorios.firstWhere((r) => r.id == recId);
    } catch (_) {
      return null;
    }
  }

  // ── Stream en tiempo real ─────────────────────────────────────────────────────

  Future<void> reintentar() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    _uid = null;
    await iniciarStream(uid);
  }

  Future<void> iniciarStream(String uid) async {
    if (uid.isEmpty) {
      debugPrint('MedicacionController: uid vacío, no se puede cargar');
      _errorMessage = 'No hay sesión activa. Inicia sesión e intenta de nuevo.';
      _status = MedicacionStatus.error;
      notifyListeners();
      return;
    }
    // Permitir reinicio si estaba en error
    if (_uid == uid && _sub != null && _status != MedicacionStatus.error) return;
    _uid = uid;
    await _sub?.cancel();

    _status = MedicacionStatus.loading;
    notifyListeners();

    _sub = _service.streamRecordatoriosActivos(uid).listen(
      (recs) async {
        _recordatorios = recs;
        await _recargarTomas(uid);
      },
      onError: (e, st) {
        debugPrint('MedicacionController stream error: $e\n$st');
        _errorMessage = 'No se pudieron cargar los medicamentos.';
        _status = MedicacionStatus.error;
        notifyListeners();
      },
    );
  }

  Future<void> _recargarTomas(String uid) async {
    try {
      _tomasHoy = await _service.getTomasHoy(uid);
      _adherenciaSemanal = await _service.getAdherenciaSemanal(uid);
      _status = MedicacionStatus.loaded;
    } catch (e, st) {
      debugPrint('MedicacionController._recargarTomas ERROR: $e\n$st');
      _status = MedicacionStatus.error;
      _errorMessage = 'No se pudieron cargar los medicamentos. '
          'Verifica tu conexión y vuelve a intentar.';
    }
    notifyListeners();
  }

  // Mantenido para compatibilidad con código existente
  Future<void> cargarHoy(String uid) => iniciarStream(uid);

  // ── Tomas ─────────────────────────────────────────────────────────────────────

  Future<void> marcarToma(TomaConRecordatorio item, bool tomado) async {
    final idx = _tomasHoy.indexOf(item);
    if (idx == -1) return;

    // Optimistic update
    _tomasHoy[idx] = TomaConRecordatorio(
      toma: item.toma.copyWith(tomado: tomado),
      medicamento: item.medicamento,
      presentacion: item.presentacion,
      dosis: item.dosis,
    );
    _recalcularAdherencia();
    notifyListeners();

    try {
      await _service.marcarToma(item.toma.recordatorioId, item.toma.id, tomado);
    } catch (e, st) {
      debugPrint('MedicacionController.marcarToma: $e\n$st');
      _tomasHoy[idx] = item;
      _recalcularAdherencia();
      notifyListeners();
    }
  }

  // ── CRUD de recordatorios ─────────────────────────────────────────────────────

  Future<void> agregarRecordatorio(RecordatorioModel recordatorio) async {
    try {
      final recId = await _service.agregarRecordatorio(recordatorio);
      if (!kIsWeb) {
        await NotificationService.instance.programarRecordatorios(
          recordatorio,
          recId,
        );
      }
      // El stream detecta el cambio y recarga automáticamente.
    } catch (e, st) {
      debugPrint('MedicacionController.agregarRecordatorio: $e\n$st');
      _errorMessage = 'No se pudo guardar el medicamento.';
      notifyListeners();
    }
  }

  Future<void> editarRecordatorio(
    String recId,
    RecordatorioModel recordatorio,
  ) async {
    // Optimistic update: reemplazar en lista local antes del await
    final prevRecordatorios = List<RecordatorioModel>.from(_recordatorios);
    final idx = _recordatorios.indexWhere((r) => r.id == recId);
    if (idx != -1) {
      _recordatorios[idx] = recordatorio.copyWith(id: recId);
      notifyListeners();
    }

    try {
      if (!kIsWeb) {
        await NotificationService.instance.cancelarRecordatorios(recId);
      }
      await _service.actualizarRecordatorio(recId, recordatorio);
      if (!kIsWeb) {
        await NotificationService.instance.programarRecordatorios(
          recordatorio,
          recId,
        );
      }
    } catch (e, st) {
      _recordatorios = prevRecordatorios;
      notifyListeners();
      debugPrint('MedicacionController.editarRecordatorio: $e\n$st');
      _errorMessage = 'No se pudo actualizar el medicamento.';
      notifyListeners();
    }
  }

  Future<void> eliminarRecordatorio(String uid, String recId) async {
    // Optimistic update: quitar de la lista local antes del await
    final prevRecordatorios = List<RecordatorioModel>.from(_recordatorios);
    final prevTomas = List<TomaConRecordatorio>.from(_tomasHoy);
    _recordatorios.removeWhere((r) => r.id == recId);
    _tomasHoy.removeWhere((t) => t.toma.recordatorioId == recId);
    notifyListeners();

    try {
      if (!kIsWeb) {
        await NotificationService.instance.cancelarRecordatorios(recId);
      }
      await _service.eliminarRecordatorio(recId);
    } catch (e, st) {
      _recordatorios = prevRecordatorios;
      _tomasHoy = prevTomas;
      notifyListeners();
      debugPrint('MedicacionController.eliminarRecordatorio: $e\n$st');
      _errorMessage = 'No se pudo eliminar el medicamento.';
      notifyListeners();
    }
  }

  void _recalcularAdherencia() {
    if (_tomasHoy.isEmpty) {
      _adherenciaSemanal = 0;
      return;
    }
    final tomadas = _tomasHoy.where((t) => t.toma.tomado).length;
    _adherenciaSemanal = tomadas / _tomasHoy.length;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
