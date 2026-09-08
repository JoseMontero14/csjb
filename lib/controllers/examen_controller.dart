import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/examen_model.dart';

class ExamenController extends ChangeNotifier {
  ExamenController({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  List<ExamenModel> _examenes = [];
  bool _cargando = false;
  String? _error;

  String _busqueda = '';
  String? _categoriaSeleccionada; // null = "Todos"

  bool get cargando => _cargando;
  String? get error => _error;
  List<ExamenModel> get examenes => _examenes;

  String get busqueda => _busqueda;
  String? get categoriaSeleccionada => _categoriaSeleccionada;

  /// Exámenes filtrados por búsqueda de texto y categoría activa.
  List<ExamenModel> get examenesFiltrados {
    final q = _busqueda.toLowerCase().trim();
    return _examenes.where((e) {
      final coincideCategoria = _categoriaSeleccionada == null ||
          e.categoria == _categoriaSeleccionada;
      final coincideBusqueda =
          q.isEmpty || e.nombre.toLowerCase().contains(q);
      return coincideCategoria && coincideBusqueda;
    }).toList();
  }

  /// Categorías únicas presentes en los exámenes cargados.
  List<String> get categorias {
    final cats = _examenes.map((e) => e.categoria).toSet().toList();
    cats.sort();
    return cats;
  }

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await _db
          .collection('examenes')
          .orderBy('nombre')
          .get();
      _examenes = snap.docs.map(ExamenModel.fromFirestore).toList();
    } catch (e, st) {
      debugPrint('ExamenController.cargar: $e\n$st');
      _error = 'No se pudieron cargar los exámenes.';
    }
    _cargando = false;
    notifyListeners();
  }

  void setBusqueda(String texto) {
    _busqueda = texto;
    notifyListeners();
  }

  void setCategoria(String? categoria) {
    _categoriaSeleccionada = categoria;
    notifyListeners();
  }

  Future<void> cargarDatosEjemplo() async {
    final ejemplos = _datosEjemplo();
    final batch = _db.batch();
    for (final e in ejemplos) {
      final ref = _db.collection('examenes').doc();
      batch.set(ref, e.toFirestore());
    }
    await batch.commit();
    await cargar();
  }
}

// ── Datos de ejemplo ──────────────────────────────────────────────────────────

List<ExamenModel> _datosEjemplo() => [
      // Sangre
      ExamenModel(
        id: '',
        nombre: 'Hemograma completo',
        categoria: 'Sangre',
        queEs: 'Análisis de los componentes de la sangre: glóbulos rojos, '
            'glóbulos blancos y plaquetas.',
        paraQueSirve: 'Detectar anemia, infecciones, trastornos de coagulación '
            'y otras condiciones hematológicas.',
        requierePreparacion: false,
      ),
      ExamenModel(
        id: '',
        nombre: 'Perfil lipídico',
        categoria: 'Sangre',
        queEs: 'Mide los niveles de colesterol total, LDL, HDL y triglicéridos '
            'en sangre.',
        paraQueSirve: 'Evaluar el riesgo cardiovascular y controlar el '
            'tratamiento de dislipidemia.',
        requierePreparacion: true,
        indicacionesPreparacion:
            'Ayuno de 9 a 12 horas antes de la extracción. '
            'Solo puede tomar agua durante ese período.',
      ),
      ExamenModel(
        id: '',
        nombre: 'Glucosa en ayunas',
        categoria: 'Sangre',
        queEs: 'Mide el nivel de azúcar (glucosa) en sangre tras un período '
            'de ayuno.',
        paraQueSirve: 'Diagnóstico y seguimiento de diabetes mellitus y '
            'prediabetes.',
        requierePreparacion: true,
        indicacionesPreparacion:
            'Ayuno mínimo de 8 horas. No consuma alimentos ni bebidas '
            'azucaradas antes de la prueba.',
      ),
      ExamenModel(
        id: '',
        nombre: 'Perfil tiroideo (TSH, T3, T4)',
        categoria: 'Sangre',
        queEs: 'Evalúa el funcionamiento de la glándula tiroides midiendo las '
            'hormonas TSH, T3 libre y T4 libre.',
        paraQueSirve: 'Detectar hipotiroidismo, hipertiroidismo y monitorear '
            'el tratamiento tiroideo.',
        requierePreparacion: false,
      ),
      ExamenModel(
        id: '',
        nombre: 'Prueba de embarazo (HCG en sangre)',
        categoria: 'Sangre',
        queEs: 'Detecta la hormona gonadotropina coriónica humana (HCG) en '
            'sangre, producida durante el embarazo.',
        paraQueSirve: 'Confirmar el embarazo con mayor sensibilidad que la '
            'prueba de orina, especialmente en etapas tempranas.',
        requierePreparacion: false,
      ),
      // Orina
      ExamenModel(
        id: '',
        nombre: 'Examen completo de orina',
        categoria: 'Orina',
        queEs: 'Análisis físico, químico y microscópico de una muestra de '
            'orina.',
        paraQueSirve: 'Detectar infecciones urinarias, enfermedad renal, '
            'diabetes y otras alteraciones metabólicas.',
        requierePreparacion: true,
        indicacionesPreparacion:
            'Recolectar la primera orina de la mañana. Limpiar la zona '
            'genital antes de la muestra y descartar el primer chorro.',
      ),
      ExamenModel(
        id: '',
        nombre: 'Urocultivo',
        categoria: 'Orina',
        queEs: 'Cultivo de orina en laboratorio para identificar bacterias y '
            'su sensibilidad a antibióticos.',
        paraQueSirve: 'Confirmar infección urinaria y determinar el antibiótico '
            'más adecuado para el tratamiento.',
        requierePreparacion: true,
        indicacionesPreparacion:
            'Recolectar la primera orina de la mañana con técnica de chorro '
            'medio en recipiente estéril. No orinar por al menos 4 horas antes.',
      ),
      // Imágenes
      ExamenModel(
        id: '',
        nombre: 'Radiografía de tórax',
        categoria: 'Imágenes',
        queEs: 'Imagen de rayos X que muestra los pulmones, el corazón y la '
            'estructura ósea del tórax.',
        paraQueSirve: 'Evaluar infecciones pulmonares, fracturas costales, '
            'tamaño del corazón y otras patologías torácicas.',
        requierePreparacion: false,
      ),
      ExamenModel(
        id: '',
        nombre: 'Ecografía abdominal',
        categoria: 'Imágenes',
        queEs: 'Estudio de ultrasonido que visualiza los órganos del abdomen '
            '(hígado, vesícula, páncreas, riñones, bazo).',
        paraQueSirve: 'Detectar cálculos biliares, quistes, tumores, '
            'inflamaciones y otras anomalías abdominales.',
        requierePreparacion: true,
        indicacionesPreparacion:
            'Ayuno de 6 horas antes del examen. Evitar alimentos flatulentos '
            'el día previo (legumbres, lácteos, bebidas gaseosas).',
      ),
      ExamenModel(
        id: '',
        nombre: 'Radiografía de columna lumbar',
        categoria: 'Imágenes',
        queEs: 'Imagen de rayos X de la región lumbar de la columna vertebral.',
        paraQueSirve: 'Evaluar fracturas, desviaciones, desgaste articular y '
            'otras alteraciones de la columna baja.',
        requierePreparacion: false,
      ),
      ExamenModel(
        id: '',
        nombre: 'Tomografía computarizada (TAC) de abdomen',
        categoria: 'Imágenes',
        queEs: 'Estudio de imágenes por rayos X computarizados que genera '
            'cortes transversales detallados del abdomen.',
        paraQueSirve: 'Diagnóstico de tumores, apendicitis, traumatismos '
            'abdominales y otras condiciones complejas.',
        requierePreparacion: true,
        indicacionesPreparacion:
            'Ayuno de 4 horas. Si se usa contraste intravenoso, informe '
            'sobre alergias y función renal. Retire joyas y objetos metálicos.',
      ),
      // Cardiología
      ExamenModel(
        id: '',
        nombre: 'Electrocardiograma (ECG)',
        categoria: 'Cardiología',
        queEs: 'Registro de la actividad eléctrica del corazón mediante '
            'electrodos colocados en la piel.',
        paraQueSirve: 'Detectar arritmias, infartos, bloqueos cardíacos y '
            'otras alteraciones del ritmo y conducción cardíaca.',
        requierePreparacion: false,
      ),
      ExamenModel(
        id: '',
        nombre: 'Ecocardiograma',
        categoria: 'Cardiología',
        queEs: 'Ultrasonido del corazón que muestra su estructura y '
            'funcionamiento en tiempo real.',
        paraQueSirve: 'Evaluar válvulas cardíacas, función del músculo '
            'cardíaco, presión pulmonar y malformaciones.',
        requierePreparacion: false,
      ),
      // Preventivo
      ExamenModel(
        id: '',
        nombre: 'Papanicolaou (PAP)',
        categoria: 'Preventivo',
        queEs: 'Toma de muestra de células del cuello uterino para análisis '
            'microscópico.',
        paraQueSirve: 'Detectar cambios celulares precancerosos o cáncer de '
            'cuello uterino en etapa temprana.',
        requierePreparacion: true,
        indicacionesPreparacion:
            'No tener relaciones sexuales 48 horas antes. No usar '
            'óvulos, cremas vaginales ni duchas en ese período. '
            'Realizarlo fuera del período menstrual.',
      ),
      ExamenModel(
        id: '',
        nombre: 'Densitometría ósea',
        categoria: 'Preventivo',
        queEs: 'Medición de la densidad mineral de los huesos mediante rayos '
            'X de baja radiación.',
        paraQueSirve: 'Diagnosticar osteoporosis y evaluar el riesgo de '
            'fracturas, especialmente en mujeres postmenopáusicas.',
        requierePreparacion: true,
        indicacionesPreparacion:
            'No tomar suplementos de calcio 24 horas antes. '
            'Informar si tuvo estudios con contraste de bario recientemente.',
      ),
    ];
