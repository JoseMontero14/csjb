import 'package:cloud_firestore/cloud_firestore.dart';

enum Sexo { masculino, femenino, prefierNoDecir }

extension SexoX on Sexo {
  String get label => switch (this) {
        Sexo.masculino => 'Masculino',
        Sexo.femenino => 'Femenino',
        Sexo.prefierNoDecir => 'Prefiero no decir',
      };

  static Sexo fromString(String value) => switch (value) {
        'Masculino' => Sexo.masculino,
        'Femenino' => Sexo.femenino,
        _ => Sexo.prefierNoDecir,
      };
}

class UsuarioModel {
  const UsuarioModel({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.sexo,
    required this.fechaNacimiento,
    required this.creadoEn,
    this.grupoSanguineo,
    this.enfermedades = const [],
    this.alergias = const [],
    this.preferenciasSalud,
    this.otraCondicionDescripcion,
    this.tipoCondicion,
    this.embarazoLactancia,
    this.preferenciaExplicacion,
    this.limitacionComunicacion,
    this.categoriasTips = const [],
    this.objetivoSalud,
    this.actividadFisica,
  });

  final String uid;
  final String nombre;
  final String correo;
  final Sexo sexo;
  final DateTime fechaNacimiento;
  final DateTime creadoEn;
  final String? grupoSanguineo;
  final List<String> enfermedades;
  final List<String> alergias;
  final Map<String, dynamic>? preferenciasSalud;

  // Campos agregados en onboarding ampliado
  final String? otraCondicionDescripcion;
  final String? tipoCondicion; // 'diagnosticada' | 'sintomas' | null
  final String? embarazoLactancia;
  final String? preferenciaExplicacion;
  final String? limitacionComunicacion;
  final List<String> categoriasTips;
  final String? objetivoSalud;
  final String? actividadFisica;

  factory UsuarioModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UsuarioModel(
      uid: doc.id,
      nombre: data['nombre'] as String,
      correo: data['correo'] as String,
      sexo: SexoX.fromString(data['sexo'] as String),
      fechaNacimiento: (data['fechaNacimiento'] as Timestamp).toDate(),
      creadoEn: (data['creadoEn'] as Timestamp).toDate(),
      grupoSanguineo: data['grupoSanguineo'] as String?,
      enfermedades: (data['enfermedades'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      alergias: (data['alergias'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      preferenciasSalud: data['preferenciasSalud'] as Map<String, dynamic>?,
      otraCondicionDescripcion: data['otraCondicionDescripcion'] as String?,
      tipoCondicion: data['tipoCondicion'] as String?,
      embarazoLactancia: data['embarazoLactancia'] as String?,
      preferenciaExplicacion: data['preferenciaExplicacion'] as String?,
      limitacionComunicacion: data['limitacionComunicacion'] as String?,
      categoriasTips: (data['categoriasTips'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      objetivoSalud: data['objetivoSalud'] as String?,
      actividadFisica: data['actividadFisica'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'correo': correo,
        'sexo': sexo.label,
        'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
        'creadoEn': Timestamp.fromDate(creadoEn),
        if (grupoSanguineo != null) 'grupoSanguineo': grupoSanguineo,
        if (enfermedades.isNotEmpty) 'enfermedades': enfermedades,
        if (alergias.isNotEmpty) 'alergias': alergias,
        if (preferenciasSalud != null) 'preferenciasSalud': preferenciasSalud,
        if (otraCondicionDescripcion != null) 'otraCondicionDescripcion': otraCondicionDescripcion,
        if (tipoCondicion != null) 'tipoCondicion': tipoCondicion,
        if (embarazoLactancia != null) 'embarazoLactancia': embarazoLactancia,
        if (preferenciaExplicacion != null) 'preferenciaExplicacion': preferenciaExplicacion,
        if (limitacionComunicacion != null) 'limitacionComunicacion': limitacionComunicacion,
        if (categoriasTips.isNotEmpty) 'categoriasTips': categoriasTips,
        if (objetivoSalud != null) 'objetivoSalud': objetivoSalud,
        if (actividadFisica != null) 'actividadFisica': actividadFisica,
      };

  UsuarioModel copyWith({
    String? nombre,
    Sexo? sexo,
    DateTime? fechaNacimiento,
    Object? grupoSanguineo = _sentinel,
    List<String>? enfermedades,
    List<String>? alergias,
    Object? preferenciasSalud = _sentinel,
    Object? otraCondicionDescripcion = _sentinel,
    Object? tipoCondicion = _sentinel,
    Object? embarazoLactancia = _sentinel,
    Object? preferenciaExplicacion = _sentinel,
    Object? limitacionComunicacion = _sentinel,
    List<String>? categoriasTips,
    Object? objetivoSalud = _sentinel,
    Object? actividadFisica = _sentinel,
  }) =>
      UsuarioModel(
        uid: uid,
        nombre: nombre ?? this.nombre,
        correo: correo,
        sexo: sexo ?? this.sexo,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        creadoEn: creadoEn,
        grupoSanguineo: identical(grupoSanguineo, _sentinel)
            ? this.grupoSanguineo
            : grupoSanguineo as String?,
        enfermedades: enfermedades ?? this.enfermedades,
        alergias: alergias ?? this.alergias,
        preferenciasSalud: identical(preferenciasSalud, _sentinel)
            ? this.preferenciasSalud
            : preferenciasSalud as Map<String, dynamic>?,
        otraCondicionDescripcion: identical(otraCondicionDescripcion, _sentinel)
            ? this.otraCondicionDescripcion
            : otraCondicionDescripcion as String?,
        tipoCondicion: identical(tipoCondicion, _sentinel)
            ? this.tipoCondicion
            : tipoCondicion as String?,
        embarazoLactancia: identical(embarazoLactancia, _sentinel)
            ? this.embarazoLactancia
            : embarazoLactancia as String?,
        preferenciaExplicacion: identical(preferenciaExplicacion, _sentinel)
            ? this.preferenciaExplicacion
            : preferenciaExplicacion as String?,
        limitacionComunicacion: identical(limitacionComunicacion, _sentinel)
            ? this.limitacionComunicacion
            : limitacionComunicacion as String?,
        categoriasTips: categoriasTips ?? this.categoriasTips,
        objetivoSalud: identical(objetivoSalud, _sentinel)
            ? this.objetivoSalud
            : objetivoSalud as String?,
        actividadFisica: identical(actividadFisica, _sentinel)
            ? this.actividadFisica
            : actividadFisica as String?,
      );
}

const _sentinel = Object();
