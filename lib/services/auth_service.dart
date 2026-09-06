import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario_model.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UsuarioModel> login({
    required String correo,
    required String contrasena,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
    return _fetchUsuario(credential.user!.uid);
  }

  Future<UsuarioModel> registro({
    required String nombre,
    required String correo,
    required String contrasena,
    required Sexo sexo,
    required DateTime fechaNacimiento,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );

    final uid = credential.user!.uid;
    final usuario = UsuarioModel(
      uid: uid,
      nombre: nombre.trim(),
      correo: correo.trim(),
      sexo: sexo,
      fechaNacimiento: fechaNacimiento,
      creadoEn: DateTime.now(),
    );

    await _db.collection('usuarios').doc(uid).set(usuario.toFirestore());
    await credential.user!.updateDisplayName(nombre.trim());

    return usuario;
  }

  Future<void> logout() => _auth.signOut();

  Future<void> enviarResetPassword(String correo) =>
      _auth.sendPasswordResetEmail(email: correo.trim());

  Future<UsuarioModel> _fetchUsuario(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) {
      // Usuario existe en Auth pero no tiene documento Firestore todavía.
      // Ocurre si la cuenta fue creada antes de esta app o el registro falló a medias.
      final user = _auth.currentUser!;
      final fallback = UsuarioModel(
        uid: uid,
        nombre: user.displayName ?? user.email!.split('@').first,
        correo: user.email!,
        sexo: Sexo.prefierNoDecir,
        fechaNacimiento: DateTime(2000),
        creadoEn: user.metadata.creationTime ?? DateTime.now(),
      );
      // Crear el documento para que la próxima vez ya exista
      await _db.collection('usuarios').doc(uid).set(fallback.toFirestore());
      return fallback;
    }
    return UsuarioModel.fromFirestore(doc);
  }

  // Traduce FirebaseAuthException a mensajes en español
  static String traducirError(FirebaseAuthException e) => switch (e.code) {
        'user-not-found' => 'No existe una cuenta con ese correo.',
        'wrong-password' => 'Contraseña incorrecta.',
        'invalid-credential' => 'Correo o contraseña incorrectos.',
        'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
        'weak-password' => 'La contraseña es muy débil.',
        'invalid-email' => 'El correo no tiene un formato válido.',
        'too-many-requests' =>
          'Demasiados intentos. Intenta de nuevo más tarde.',
        'network-request-failed' =>
          'Sin conexión a internet. Verifica tu red.',
        _ => 'Ocurrió un error. Intenta de nuevo.',
      };
}
