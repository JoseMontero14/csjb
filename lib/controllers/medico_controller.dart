import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/medico_model.dart';

class MedicoController extends ChangeNotifier {
  MedicoController({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  List<MedicoModel> _medicos = [];
  bool _cargando = false;
  String? _error;
  String? _especialidadSeleccionada;

  bool get cargando => _cargando;
  String? get error => _error;
  String? get especialidadSeleccionada => _especialidadSeleccionada;

  List<MedicoModel> get medicosFiltrados => _especialidadSeleccionada == null
      ? _medicos
      : _medicos
          .where((m) => m.especialidad == _especialidadSeleccionada)
          .toList();

  List<String> get especialidades {
    final esp = _medicos.map((m) => m.especialidad).toSet().toList();
    esp.sort();
    return esp;
  }

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final snap =
          await _db.collection('medicos').orderBy('nombre').get();
      _medicos = snap.docs.map(MedicoModel.fromFirestore).toList();
    } catch (e, st) {
      debugPrint('MedicoController.cargar: $e\n$st');
      _error = 'No se pudo cargar el directorio médico.';
    }
    _cargando = false;
    notifyListeners();
  }

  /// Carga los médicos y preselecciona una especialidad (usado desde Triaje).
  Future<void> cargarConFiltroInicial(String especialidad) async {
    _especialidadSeleccionada = especialidad;
    await cargar();
  }

  void setEspecialidad(String? especialidad) {
    _especialidadSeleccionada = especialidad;
    notifyListeners();
  }

  Future<void> cargarDatosEjemplo() async {
    final batch = _db.batch();
    for (final m in _datosEjemplo()) {
      final ref = _db.collection('medicos').doc();
      batch.set(ref, m.toFirestore());
    }
    await batch.commit();
    await cargar();
  }
}

// ── Datos de ejemplo ──────────────────────────────────────────────────────────

List<MedicoModel> _datosEjemplo() => [
      MedicoModel(
        id: '',
        nombre: 'Dr. Carlos Mendoza Ríos',
        especialidad: 'Medicina General',
        fotoUrl: 'https://i.pravatar.cc/300?img=11',
        dias: ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'],
        horario: '8:00 am - 2:00 pm',
        descripcionEspecialidad:
            'La Medicina General atiende las necesidades de salud del paciente '
            'de forma integral, desde enfermedades comunes hasta la coordinación '
            'con otras especialidades.',
      ),
      MedicoModel(
        id: '',
        nombre: 'Dra. Ana Sofía Paredes',
        especialidad: 'Medicina General',
        fotoUrl: 'https://i.pravatar.cc/300?img=47',
        dias: ['Lunes', 'Miércoles', 'Viernes'],
        horario: '2:00 pm - 8:00 pm',
        descripcionEspecialidad:
            'La Medicina General atiende las necesidades de salud del paciente '
            'de forma integral, desde enfermedades comunes hasta la coordinación '
            'con otras especialidades.',
      ),
      MedicoModel(
        id: '',
        nombre: 'Dra. Lucía Torres Vega',
        especialidad: 'Pediatría',
        fotoUrl: 'https://i.pravatar.cc/300?img=49',
        dias: ['Lunes', 'Martes', 'Jueves', 'Viernes'],
        horario: '9:00 am - 1:00 pm',
        descripcionEspecialidad:
            'La Pediatría se especializa en la salud y desarrollo de niños '
            'desde el nacimiento hasta la adolescencia, incluyendo prevención, '
            'diagnóstico y tratamiento de enfermedades infantiles.',
      ),
      MedicoModel(
        id: '',
        nombre: 'Dr. Roberto Salas Chávez',
        especialidad: 'Pediatría',
        fotoUrl: 'https://i.pravatar.cc/300?img=15',
        dias: ['Martes', 'Miércoles', 'Viernes'],
        horario: '3:00 pm - 7:00 pm',
        descripcionEspecialidad:
            'La Pediatría se especializa en la salud y desarrollo de niños '
            'desde el nacimiento hasta la adolescencia, incluyendo prevención, '
            'diagnóstico y tratamiento de enfermedades infantiles.',
      ),
      MedicoModel(
        id: '',
        nombre: 'Dra. Patricia Quispe Huanca',
        especialidad: 'Ginecología',
        fotoUrl: 'https://i.pravatar.cc/300?img=44',
        dias: ['Lunes', 'Miércoles', 'Jueves'],
        horario: '8:00 am - 12:00 pm',
        descripcionEspecialidad:
            'La Ginecología y Obstetricia atiende la salud del sistema '
            'reproductivo femenino, embarazo, parto y control prenatal.',
      ),
      MedicoModel(
        id: '',
        nombre: 'Dr. Javier Morales Estrada',
        especialidad: 'Traumatología',
        fotoUrl: 'https://i.pravatar.cc/300?img=12',
        dias: ['Lunes', 'Martes', 'Miércoles', 'Viernes'],
        horario: '10:00 am - 4:00 pm',
        descripcionEspecialidad:
            'La Traumatología y Ortopedia trata lesiones y enfermedades del '
            'sistema músculo-esquelético: huesos, articulaciones, músculos, '
            'tendones y ligamentos.',
      ),
      MedicoModel(
        id: '',
        nombre: 'Dra. Valeria Campos Ruiz',
        especialidad: 'Dermatología',
        fotoUrl: 'https://i.pravatar.cc/300?img=45',
        dias: ['Martes', 'Jueves'],
        horario: '9:00 am - 1:00 pm',
        descripcionEspecialidad:
            'La Dermatología diagnostica y trata enfermedades de la piel, '
            'cabello y uñas, incluyendo acné, eczema, psoriasis y control de '
            'lesiones cutáneas.',
      ),
      MedicoModel(
        id: '',
        nombre: 'Dr. Miguel Ángel Flores',
        especialidad: 'Cardiología',
        fotoUrl: 'https://i.pravatar.cc/300?img=13',
        dias: ['Lunes', 'Miércoles', 'Viernes'],
        horario: '8:00 am - 1:00 pm',
        descripcionEspecialidad:
            'La Cardiología se ocupa del diagnóstico y tratamiento de '
            'enfermedades del corazón y el sistema cardiovascular, incluyendo '
            'hipertensión, arritmias e insuficiencia cardíaca.',
      ),
      MedicoModel(
        id: '',
        nombre: 'Dra. Carmen Rosa Díaz',
        especialidad: 'Emergencias',
        fotoUrl: 'https://i.pravatar.cc/300?img=46',
        dias: ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'],
        horario: '7:00 am - 7:00 pm',
        descripcionEspecialidad:
            'El servicio de Emergencias atiende de forma inmediata situaciones '
            'que representan un riesgo vital o que requieren intervención '
            'médica urgente.',
      ),
    ];
