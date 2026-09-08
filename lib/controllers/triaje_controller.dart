import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/triaje_model.dart';
import '../services/cloud_functions_service.dart';

enum TriajeStatus { idle, generando, listo, error, guardando, guardado }

class TriajeController extends ChangeNotifier {
  TriajeController({
    CloudFunctionsService? gemini,
    FirebaseFirestore? db,
  })  : _gemini = gemini ?? CloudFunctionsService(),
        _db = db ?? FirebaseFirestore.instance;

  final CloudFunctionsService _gemini;
  final FirebaseFirestore _db;

  // ── Estado del flujo de 3 pasos (en memoria, sin tocar Firestore) ──────────

  TriajeStatus _status = TriajeStatus.idle;
  TriajeStatus get status => _status;

  bool get generando => _status == TriajeStatus.generando;
  bool get listo => _status == TriajeStatus.listo;
  bool get guardando => _status == TriajeStatus.guardando;
  bool get yaGuardado => _status == TriajeStatus.guardado;
  String? get errorMensaje => _errorMensaje;

  String? _errorMensaje;

  // Paso 1
  final Set<String> _sintomasSeleccionados = {};
  String _sintomaLibre = '';

  Set<String> get sintomasSeleccionados =>
      Set.unmodifiable(_sintomasSeleccionados);

  List<String> get todosSintomas {
    final lista = [..._sintomasSeleccionados];
    if (_sintomaLibre.trim().isNotEmpty) lista.add(_sintomaLibre.trim());
    return lista;
  }

  // Paso 2
  IntensidadSintomas? _intensidad;
  String? _duracion;

  IntensidadSintomas? get intensidad => _intensidad;
  String? get duracion => _duracion;

  // Resultado (en memoria)
  TriajeModel? _resultado;
  TriajeModel? get resultado => _resultado;

  // Historial (solo triajes guardados, cargados desde Firestore)
  List<TriajeModel> _historial = [];
  List<TriajeModel> get historial => _historial;
  bool _cargandoHistorial = false;
  bool get cargandoHistorial => _cargandoHistorial;

  // ── Paso 1: Síntomas ───────────────────────────────────────────────────────

  void toggleSintoma(String sintoma) {
    if (_sintomasSeleccionados.contains(sintoma)) {
      _sintomasSeleccionados.remove(sintoma);
    } else {
      _sintomasSeleccionados.add(sintoma);
    }
    notifyListeners();
  }

  void setSintomaLibre(String texto) {
    _sintomaLibre = texto;
    notifyListeners();
  }

  bool get tieneSintomas => todosSintomas.isNotEmpty;

  // ── Paso 2: Intensidad y duración ─────────────────────────────────────────

  void setIntensidad(IntensidadSintomas valor) {
    _intensidad = valor;
    notifyListeners();
  }

  void setDuracion(String valor) {
    _duracion = valor;
    notifyListeners();
  }

  bool get paso2Completo => _intensidad != null && _duracion != null;

  // ── Paso 3: Generar resultado vía Gemini ───────────────────────────────────

  Future<void> generarResultado(String uid) async {
    if (!tieneSintomas || _intensidad == null || _duracion == null) return;

    _status = TriajeStatus.generando;
    _errorMensaje = null;
    notifyListeners();

    try {
      final (:nivel, :recomendacion, :especialidad) = await _gemini.evaluarTriaje(
        sintomas: todosSintomas,
        intensidad: _intensidad!,
        duracion: _duracion!,
      );

      _resultado = TriajeModel(
        uid: uid,
        sintomas: todosSintomas,
        intensidad: _intensidad!,
        duracionSintomas: _duracion!,
        nivelUrgencia: nivel,
        recomendacion: recomendacion,
        especialidadSugerida: especialidad,
        fecha: DateTime.now(),
        guardado: false,
      );
      _status = TriajeStatus.listo;
    } catch (e, st) {
      debugPrint('TriajeController.generarResultado [${e.runtimeType}]: $e\n$st');
      _errorMensaje = e.toString().replaceFirst('Exception: ', '');
      _status = TriajeStatus.error;
    }

    notifyListeners();
  }

  // ── Guardar en Firestore (solo si el usuario lo pide explícitamente) ───────

  Future<void> guardarResultado() async {
    final r = _resultado;
    if (r == null || yaGuardado || guardando) return;

    _status = TriajeStatus.guardando;
    notifyListeners();

    try {
      final ref = await _db.collection('triajes').add(r.toFirestore());
      _resultado = r.copyWith(id: ref.id, guardado: true);
      _status = TriajeStatus.guardado;
    } catch (e, st) {
      debugPrint('TriajeController.guardarResultado: $e\n$st');
      _errorMensaje = 'No se pudo guardar el resultado. Intenta de nuevo.';
      _status = TriajeStatus.listo; // Deja que el usuario reintente
    }

    notifyListeners();
  }

  // ── Historial ──────────────────────────────────────────────────────────────

  Future<void> cargarHistorial(String uid) async {
    _cargandoHistorial = true;
    notifyListeners();

    try {
      final snap = await _db
          .collection('triajes')
          .where('uid', isEqualTo: uid)
          .where('guardado', isEqualTo: true)
          .orderBy('fecha', descending: true)
          .get();
      _historial = snap.docs.map(TriajeModel.fromFirestore).toList();
    } catch (e, st) {
      debugPrint('TriajeController.cargarHistorial: $e\n$st');
      _historial = [];
    }

    _cargandoHistorial = false;
    notifyListeners();
  }

  // ── Reiniciar flujo ────────────────────────────────────────────────────────

  void reiniciar() {
    _sintomasSeleccionados.clear();
    _sintomaLibre = '';
    _intensidad = null;
    _duracion = null;
    _resultado = null;
    _errorMensaje = null;
    _status = TriajeStatus.idle;
    notifyListeners();
  }
}

// Opciones fijas para los selectores de las vistas
abstract final class TriajeOpciones {
  static const List<String> sintomas = [
    'Dolor de cabeza',
    'Fiebre',
    'Tos',
    'Fatiga',
    'Náuseas',
    'Dolor abdominal',
    'Mareo',
    'Falta de aire',
    'Dolor de garganta',
  ];

  static const List<String> duraciones = [
    'Menos de 1 día',
    '1 a 3 días',
    '4 a 7 días',
    'Más de 1 semana',
  ];
}
