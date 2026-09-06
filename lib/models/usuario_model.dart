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
  });

  final String uid;
  final String nombre;
  final String correo;
  final Sexo sexo;
  final DateTime fechaNacimiento;
  final DateTime creadoEn;

  factory UsuarioModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UsuarioModel(
      uid: doc.id,
      nombre: data['nombre'] as String,
      correo: data['correo'] as String,
      sexo: SexoX.fromString(data['sexo'] as String),
      fechaNacimiento: (data['fechaNacimiento'] as Timestamp).toDate(),
      creadoEn: (data['creadoEn'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'correo': correo,
        'sexo': sexo.label,
        'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
        'creadoEn': Timestamp.fromDate(creadoEn),
      };

  UsuarioModel copyWith({
    String? nombre,
    String? correo,
    Sexo? sexo,
    DateTime? fechaNacimiento,
  }) =>
      UsuarioModel(
        uid: uid,
        nombre: nombre ?? this.nombre,
        correo: correo ?? this.correo,
        sexo: sexo ?? this.sexo,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        creadoEn: creadoEn,
      );
}
