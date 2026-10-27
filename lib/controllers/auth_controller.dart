import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  AuthController({AuthService? service})
      : _service = service ?? AuthService() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
      if (firebaseUser == null) {
        _usuario = null;
        _status = AuthStatus.idle;
        _errorMessage = null;
        notifyListeners();
      }
    });
  }

  final AuthService _service;
  late final StreamSubscription<User?> _authSub;

  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;
  UsuarioModel? _usuario;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  UsuarioModel? get usuario => _usuario;
  bool get isLoading => _status == AuthStatus.loading;

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<bool> login({
    required String correo,
    required String contrasena,
  }) async {
    _setLoading();
    try {
      _usuario = await _service.login(
        correo: correo,
        contrasena: contrasena,
      );
      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(AuthService.traducirError(e));
      return false;
    } catch (e, st) {
      debugPrint('AuthController.login error: $e\n$st');
      _setError('Ocurrió un error inesperado: $e');
      return false;
    }
  }

  Future<bool> registro({
    required String nombre,
    required String correo,
    required String contrasena,
    required Sexo sexo,
    required DateTime fechaNacimiento,
  }) async {
    _setLoading();
    try {
      _usuario = await _service.registro(
        nombre: nombre,
        correo: correo,
        contrasena: contrasena,
        sexo: sexo,
        fechaNacimiento: fechaNacimiento,
      );
      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(AuthService.traducirError(e));
      return false;
    } catch (e, st) {
      debugPrint('AuthController.registro error: $e\n$st');
      _setError('Ocurrió un error inesperado: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _usuario = null;
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> enviarResetPassword(String correo) async {
    _setLoading();
    try {
      await _service.enviarResetPassword(correo);
      _setSuccess();
    } on FirebaseAuthException catch (e) {
      _setError(AuthService.traducirError(e));
    } catch (_) {
      _setError('No se pudo enviar el correo de recuperación.');
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      _status = AuthStatus.idle;
      notifyListeners();
    }
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = AuthStatus.success;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}
