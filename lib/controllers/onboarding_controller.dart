import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recordatorio_model.dart';

enum OnboardingStatus { idle, guardando, listo, error }

class OnboardingController extends ChangeNotifier {
  OnboardingController({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  OnboardingStatus _status = OnboardingStatus.idle;
  String? _error;

  OnboardingStatus get status => _status;
  String? get error => _error;
  bool get guardando => _status == OnboardingStatus.guardando;

  Future<bool> guardar({
    required String uid,
    String? grupoSanguineo,
    required List<String> enfermedades,
    required List<String> alergias,
    // Campos existentes
    String? medicacionActual,
    // Campos nuevos — condiciones
    String? otraCondicionDescripcion,
    String? tipoCondicion,
    // Campos nuevos — alergias a medicamentos
    String? alergiaMedicamentoDetalle,
    String? alergiaMedicamentoReaccion,
    // Campos nuevos — medicamentos estructurados
    List<Map<String, String?>>? medicamentos,
    // Campos nuevos — paso "Sobre ti"
    String? embarazoLactancia,
    String? preferenciaExplicacion,
    String? limitacionComunicacion,
    // Campos nuevos — paso "Personaliza tu asistente"
    List<String>? categoriasTips,
    String? objetivoSalud,
    String? actividadFisica,
  }) async {
    _status = OnboardingStatus.guardando;
    _error = null;
    notifyListeners();

    try {
      final data = <String, dynamic>{};

      if (grupoSanguineo != null && grupoSanguineo.isNotEmpty) {
        data['grupoSanguineo'] = grupoSanguineo;
      }
      if (enfermedades.isNotEmpty) data['enfermedades'] = enfermedades;
      if (alergias.isNotEmpty) data['alergias'] = alergias;
      if (otraCondicionDescripcion != null && otraCondicionDescripcion.isNotEmpty) {
        data['otraCondicionDescripcion'] = otraCondicionDescripcion;
      }
      if (tipoCondicion != null) data['tipoCondicion'] = tipoCondicion;
      if (embarazoLactancia != null) data['embarazoLactancia'] = embarazoLactancia;
      if (preferenciaExplicacion != null) data['preferenciaExplicacion'] = preferenciaExplicacion;
      if (limitacionComunicacion != null) data['limitacionComunicacion'] = limitacionComunicacion;
      if (categoriasTips != null && categoriasTips.isNotEmpty) {
        data['categoriasTips'] = categoriasTips;
      }
      if (objetivoSalud != null) data['objetivoSalud'] = objetivoSalud;
      if (actividadFisica != null) data['actividadFisica'] = actividadFisica;

      // Construir preferenciasSalud
      final prefs = <String, dynamic>{'visto': true};
      if (medicacionActual != null && medicacionActual.isNotEmpty) {
        prefs['medicacionActual'] = medicacionActual;
      }
      if (medicamentos != null && medicamentos.isNotEmpty) {
        prefs['medicamentos'] = medicamentos;
      }
      if (alergiaMedicamentoDetalle != null && alergiaMedicamentoDetalle.isNotEmpty) {
        prefs['alergiaMedicamentoDetalle'] = alergiaMedicamentoDetalle;
      }
      if (alergiaMedicamentoReaccion != null && alergiaMedicamentoReaccion.isNotEmpty) {
        prefs['alergiaMedicamentoReaccion'] = alergiaMedicamentoReaccion;
      }
      data['preferenciasSalud'] = prefs;

      final batch = _db.batch();

      // Guardar datos del usuario
      batch.update(_db.collection('usuarios').doc(uid), data);

      // Crear recordatorios por cada medicamento del onboarding
      if (medicamentos != null) {
        final hoy = DateTime.now();
        for (final med in medicamentos) {
          final nombre = med['nombre'] ?? '';
          if (nombre.isEmpty) continue;

          final frecStr = med['frecuencia'] ?? 'Una vez al día';
          final frec = FrecuenciaX.fromString(frecStr);

          // Generar horarios por defecto según frecuencia
          final horarios = _horariosDefault(frec);

          final ref = _db.collection('recordatorios').doc();
          final recData = RecordatorioModel(
            id: ref.id,
            uid: uid,
            medicamento: nombre,
            presentacion: '',
            dosis: med['dosis'] ?? '',
            frecuencia: frec,
            horarios: horarios,
            fechaInicio: DateTime(hoy.year, hoy.month, hoy.day),
            sinFechaFin: true,
            notas: med['tipo'] != null ? 'Tipo: ${med['tipo']}' : null,
          ).toFirestore();

          // Marcar como originado en el onboarding
          recData['origenOnboarding'] = true;

          batch.set(ref, recData);
        }
      }

      await batch.commit();

      _status = OnboardingStatus.listo;
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('OnboardingController.guardar: ${e.runtimeType} - $e\n$st');
      _error = 'No se pudieron guardar tus datos.';
      _status = OnboardingStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Horarios por defecto según la frecuencia, en formato "HH:mm".
  List<String> _horariosDefault(Frecuencia frec) => switch (frec) {
        Frecuencia.unaVez || Frecuencia.unaVezAlDia => ['08:00'],
        Frecuencia.dosVeces || Frecuencia.cada12h => ['08:00', '20:00'],
        Frecuencia.tresVeces || Frecuencia.cada8h => ['08:00', '14:00', '20:00'],
        _ => ['08:00'],
      };
}
