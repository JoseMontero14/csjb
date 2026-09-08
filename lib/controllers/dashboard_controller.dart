import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/toma_model.dart';
import '../services/firestore_service.dart';
import '../utils/theme.dart';

class DashboardData {
  const DashboardData({
    required this.bienestarPct,
    required this.totalHoy,
    required this.tomadasHoy,
    required this.proximaToma,
    this.ultimoTriajeNivel,
    this.ultimoTriajeFecha,
  });

  final int bienestarPct;
  final int totalHoy;
  final int tomadasHoy;
  final TomaConRecordatorio? proximaToma;
  final UrgencyLevel? ultimoTriajeNivel;
  final DateTime? ultimoTriajeFecha;

  bool get sinRegistros => totalHoy == 0;
  bool get tieneTriaje => ultimoTriajeNivel != null;
}

enum DashboardStatus { idle, loading, loaded, error }

class DashboardController extends ChangeNotifier {
  DashboardController({FirestoreService? service})
      : _service = service ?? FirestoreService();

  final FirestoreService _service;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DashboardStatus _status = DashboardStatus.idle;
  DashboardData _data = const DashboardData(
    bienestarPct: 0,
    totalHoy: 0,
    tomadasHoy: 0,
    proximaToma: null,
  );
  String? _errorMessage;

  DashboardStatus get status => _status;
  DashboardData get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DashboardStatus.loading;

  Future<void> cargar(String uid) async {
    _status = DashboardStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final tomas = await _service.getTomasHoy(uid);
      final total = tomas.length;
      final tomadas = tomas.where((t) => t.toma.tomado).length;
      final pct = total == 0 ? 0 : (tomadas / total * 100).round();

      // Próxima toma: la más cercana en el tiempo que no esté tomada
      final now = DateTime.now();
      final pendientes = tomas.where((t) => !t.toma.tomado).toList()
        ..sort((a, b) => _minutosDesdeAhora(a.toma.hora, now)
            .compareTo(_minutosDesdeAhora(b.toma.hora, now)));

      final (:nivelTriaje, :fechaTriaje) = await _ultimoTriaje(uid);

      _data = DashboardData(
        bienestarPct: pct,
        totalHoy: total,
        tomadasHoy: tomadas,
        proximaToma: pendientes.isEmpty ? null : pendientes.first,
        ultimoTriajeNivel: nivelTriaje,
        ultimoTriajeFecha: fechaTriaje,
      );
      _status = DashboardStatus.loaded;
    } catch (e, st) {
      debugPrint('DashboardController.cargar: $e\n$st');
      _errorMessage = 'No se pudo cargar el resumen.';
      _status = DashboardStatus.error;
    }

    notifyListeners();
  }

  Future<({UrgencyLevel? nivelTriaje, DateTime? fechaTriaje})>
      _ultimoTriaje(String uid) async {
    try {
      final snap = await _db
          .collection('triajes')
          .where('uid', isEqualTo: uid)
          .where('guardado', isEqualTo: true)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return (nivelTriaje: null, fechaTriaje: null);
      final d = snap.docs.first.data();
      final nivelStr = d['nivelUrgencia'] as String?;
      final fecha = (d['fecha'] as Timestamp?)?.toDate();
      final nivel = UrgencyLevel.values.firstWhere(
        (e) => e.name == nivelStr,
        orElse: () => UrgencyLevel.medium,
      );
      return (nivelTriaje: nivel, fechaTriaje: fecha);
    } catch (e, st) {
      debugPrint('DashboardController._ultimoTriaje: $e\n$st');
      return (nivelTriaje: null, fechaTriaje: null);
    }
  }

  /// Minutos desde ahora hasta la hora "HH:mm" (puede ser negativo si ya pasó).
  int _minutosDesdeAhora(String hora, DateTime now) {
    final parts = hora.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final tomaMin = h * 60 + m;
    final nowMin = now.hour * 60 + now.minute;
    // Si ya pasó hoy, la ponemos al final (+ 1440 minutos = mañana)
    return tomaMin >= nowMin ? tomaMin - nowMin : tomaMin - nowMin + 1440;
  }
}
