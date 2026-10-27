import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/usuario_model.dart';

enum PerfilStatus { idle, cargando, listo, guardando, error }

class PerfilController extends ChangeNotifier {
  PerfilController({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  PerfilStatus _status = PerfilStatus.idle;
  UsuarioModel? _usuario;
  String? _error;

  PerfilStatus get status => _status;
  UsuarioModel? get usuario => _usuario;
  String? get error => _error;

  bool get cargando => _status == PerfilStatus.cargando;
  bool get guardando => _status == PerfilStatus.guardando;
  bool get listo => _status == PerfilStatus.listo;

  Future<void> cargar(String uid) async {
    _status = PerfilStatus.cargando;
    _error = null;
    notifyListeners();

    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (!doc.exists) throw Exception('Usuario no encontrado');
      _usuario = UsuarioModel.fromFirestore(doc);
      _status = PerfilStatus.listo;
    } catch (e, st) {
      debugPrint('PerfilController.cargar: ${e.runtimeType} - $e\n$st');
      _error = 'No se pudo cargar el perfil.';
      _status = PerfilStatus.error;
    }
    notifyListeners();
  }

  Future<bool> guardar(String uid, UsuarioModel datos) async {
    _status = PerfilStatus.guardando;
    notifyListeners();

    try {
      await _db
          .collection('usuarios')
          .doc(uid)
          .update(datos.toFirestore());
      _usuario = datos;
      _status = PerfilStatus.listo;
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('PerfilController.guardar: $e\n$st');
      _error = 'No se pudo guardar el perfil.';
      _status = PerfilStatus.listo;
      notifyListeners();
      return false;
    }
  }
}
