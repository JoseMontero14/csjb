import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/triaje_model.dart';
import '../services/gemini_service.dart';
import '../utils/theme.dart' show UrgencyLevel;

enum TriajeStatus { idle, generando, listo, error, guardando, guardado }

class TriajeController extends ChangeNotifier {
  TriajeController({
    GeminiService? gemini,
    FirebaseFirestore? db,
  })  : _gemini = gemini ?? GeminiService(),
        _db = db ?? FirebaseFirestore.instance;

  final GeminiService _gemini;
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
      // Fallback seguro: resultado neutro para que el usuario no quede sin orientación.
      _resultado = TriajeModel(
        uid: uid,
        sintomas: todosSintomas,
        intensidad: _intensidad!,
        duracionSintomas: _duracion!,
        nivelUrgencia: UrgencyLevel.medium,
        recomendacion:
            'No pudimos procesar tu triaje en este momento. '
            'Si tus síntomas son intensos o te preocupan, te recomendamos '
            'acudir directamente a la clínica o comunicarte con emergencias (SAMU 106).',
        especialidadSugerida: 'Medicina Interna',
        fecha: DateTime.now(),
        guardado: false,
      );
      _status = TriajeStatus.listo;
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

  // ── Seguimiento post-triaje ────────────────────────────────────────────────

  static const int _notifIdBase = 2000;

  Future<void> guardarSeguimiento({
    required DateTime fechaHora,
    required FlutterLocalNotificationsPlugin notificaciones,
  }) async {
    final r = _resultado;
    if (r == null || r.id == null) return;

    final seguimiento = SeguimientoTriaje(
      programado: true,
      fechaHora: fechaHora,
      estado: EstadoSeguimiento.pendiente,
    );

    try {
      await _db.collection('triajes').doc(r.id).update({
        'seguimiento': seguimiento.toMap(),
      });
      _resultado = r.copyWith(seguimiento: seguimiento);

      final notifId = _notifIdBase + r.id.hashCode.abs() % 10000;
      const androidDetails = AndroidNotificationDetails(
        'triaje_seguimiento',
        'Seguimiento de triaje',
        channelDescription: 'Recordatorios de seguimiento post-triaje',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await notificaciones.zonedSchedule(
        notifId,
        '¿Cómo te sientes hoy?',
        'Cuéntanos cómo evolucionaron tus síntomas desde tu último triaje.',
        tz.TZDateTime.from(fechaHora, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'seguimiento:${r.id}',
      );

      notifyListeners();
    } catch (e, st) {
      debugPrint('TriajeController.guardarSeguimiento: $e\n$st');
    }
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
