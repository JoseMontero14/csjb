import 'package:flutter/foundation.dart';
import '../models/recordatorio_model.dart';
import '../models/toma_model.dart';
import '../services/firestore_service.dart';

enum MedicacionStatus { idle, loading, loaded, error }

class MedicacionController extends ChangeNotifier {
  MedicacionController({FirestoreService? service})
      : _service = service ?? FirestoreService();

  final FirestoreService _service;

  MedicacionStatus _status = MedicacionStatus.idle;
  List<TomaConRecordatorio> _tomasHoy = [];
  double _adherenciaSemanal = 0;
  String? _errorMessage;

  MedicacionStatus get status => _status;
  List<TomaConRecordatorio> get tomasHoy => _tomasHoy;
  double get adherenciaSemanal => _adherenciaSemanal;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == MedicacionStatus.loading;

  int get totalHoy => _tomasHoy.length;
  int get tomadasHoy => _tomasHoy.where((t) => t.toma.tomado).length;

  Future<void> cargarHoy(String uid) async {
    _status = MedicacionStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _tomasHoy = await _service.getTomasHoy(uid);
      _adherenciaSemanal = await _service.getAdherenciaSemanal(uid);
      _status = MedicacionStatus.loaded;
    } catch (e, st) {
      debugPrint('MedicacionController.cargarHoy: $e\n$st');
      _errorMessage = 'No se pudieron cargar los medicamentos.';
      _status = MedicacionStatus.error;
    }
    notifyListeners();
  }

  Future<void> marcarToma(TomaConRecordatorio item, bool tomado) async {
    // Actualización optimista en UI
    final idx = _tomasHoy.indexOf(item);
    if (idx == -1) return;
    _tomasHoy[idx] = TomaConRecordatorio(
      toma: item.toma.copyWith(tomado: tomado),
      medicamento: item.medicamento,
      dosis: item.dosis,
    );
    _recalcularAdherencia();
    notifyListeners();

    try {
      await _service.marcarToma(item.toma.recordatorioId, item.toma.id, tomado);
    } catch (e, st) {
      debugPrint('MedicacionController.marcarToma: $e\n$st');
      // Revertir en caso de error
      _tomasHoy[idx] = item;
      _recalcularAdherencia();
      notifyListeners();
    }
  }

  Future<void> agregarRecordatorio(RecordatorioModel recordatorio) async {
    try {
      await _service.agregarRecordatorio(recordatorio);
      await cargarHoy(recordatorio.uid);
    } catch (e, st) {
      debugPrint('MedicacionController.agregarRecordatorio: $e\n$st');
      _errorMessage = 'No se pudo guardar el medicamento.';
      notifyListeners();
    }
  }

  void _recalcularAdherencia() {
    if (_tomasHoy.isEmpty) {
      _adherenciaSemanal = 0;
      return;
    }
    // Aproximación local con las tomas de hoy mientras no recargamos Firestore
    final tomadas = _tomasHoy.where((t) => t.toma.tomado).length;
    _adherenciaSemanal = tomadas / _tomasHoy.length;
  }
}
