import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/mensaje_model.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';

enum ChatStatus { idle, loading, loaded, error }

class ChatController extends ChangeNotifier {
  ChatController({
    FirestoreService? firestore,
    GeminiService? gemini,
  })  : _firestore = firestore ?? FirestoreService(),
        _gemini = gemini ?? GeminiService();

  final FirestoreService _firestore;
  final GeminiService _gemini;

  // ── Chat list ──────────────────────────────────────────────────────────────
  ChatStatus _statusLista = ChatStatus.idle;
  List<ChatModel> _chats = [];

  ChatStatus get statusLista => _statusLista;
  List<ChatModel> get chats => _chats;
  bool get cargandoLista => _statusLista == ChatStatus.loading;

  Future<void> cargarChats(String uid) async {
    _statusLista = ChatStatus.loading;
    notifyListeners();
    try {
      _chats = await _firestore.getChats(uid);
      _statusLista = ChatStatus.loaded;
    } catch (e, st) {
      debugPrint('ChatController.cargarChats: $e\n$st');
      _statusLista = ChatStatus.error;
    }
    notifyListeners();
  }

  // ── Active chat ────────────────────────────────────────────────────────────
  String? _chatId;
  String? _uid;
  String? _contextoUsuario;
  List<MensajeModel> _mensajes = [];
  bool _enviando = false;
  bool _escribiendo = false; // indicador "IA está escribiendo"
  String? _errorMensaje;

  String? get chatId => _chatId;
  List<MensajeModel> get mensajes => _mensajes;
  bool get enviando => _enviando;
  bool get escribiendo => _escribiendo;
  String? get errorMensaje => _errorMensaje;

  void iniciarChat(String uid, {String? chatId, String? contextoUsuario}) {
    _uid = uid;
    _chatId = chatId;
    _contextoUsuario = contextoUsuario;
    _mensajes = [];
    _enviando = false;
    _escribiendo = false;
    _errorMensaje = null;
    if (chatId != null) _cargarMensajes(chatId);
  }

  Future<void> _cargarMensajes(String chatId) async {
    try {
      _mensajes = await _firestore.getMensajes(chatId);
      notifyListeners();
    } catch (e, st) {
      debugPrint('ChatController._cargarMensajes: $e\n$st');
    }
  }

  Future<void> enviarMensaje(String texto) async {
    if (_uid == null || _enviando || texto.trim().isEmpty) return;

    final textoLimpio = texto.trim();
    _errorMensaje = null;

    // Agregar mensaje del usuario localmente de inmediato (antes de cualquier red)
    final msgUsuario = MensajeModel(
      id: '_local',
      rol: 'user',
      texto: textoLimpio,
      timestamp: DateTime.now(),
    );
    _mensajes.add(msgUsuario);
    _enviando = true;
    _escribiendo = true;
    notifyListeners();

    // Crear chat en Firestore si es nuevo
    if (_chatId == null) {
      try {
        final nuevoChat = ChatModel(
          id: '',
          uid: _uid!,
          titulo: _tituloDesde(textoLimpio),
          creadoEn: DateTime.now(),
          preview: textoLimpio,
        );
        _chatId = await _firestore.crearChat(nuevoChat);
      } catch (e, st) {
        debugPrint('ChatController: error creando chat: $e\n$st');
        _mensajes.removeLast();
        _enviando = false;
        _escribiendo = false;
        _errorMensaje = 'No se pudo iniciar la conversación.';
        notifyListeners();
        return;
      }
    }

    try {
      // Persistir mensaje del usuario
      final savedUser =
          await _firestore.agregarMensaje(_chatId!, msgUsuario);
      _mensajes[_mensajes.length - 1] = savedUser;

      // Actualizar preview del chat
      await _firestore.actualizarChat(_chatId!, preview: textoLimpio);

      // Si es el primer mensaje, actualizar título
      if (_mensajes.length == 1) {
        await _firestore.actualizarChat(
            _chatId!, titulo: _tituloDesde(textoLimpio));
      }

      // Llamar a Gemini con el historial completo y contexto del paciente
      final respuestaTexto = await _gemini.llamarGemini(
        _mensajes,
        contextoUsuario: _contextoUsuario,
      );

      // Persistir respuesta IA
      final msgIA = MensajeModel(
        id: '_local_ia',
        rol: 'assistant',
        texto: respuestaTexto,
        timestamp: DateTime.now(),
      );
      final savedIA = await _firestore.agregarMensaje(_chatId!, msgIA);
      _mensajes.add(savedIA);

      await _firestore.actualizarChat(_chatId!, preview: respuestaTexto);
    } catch (e, st) {
      debugPrint('ChatController.enviarMensaje [${e.runtimeType}]: $e\n$st');
      // Mostrar el fallo como burbuja de la IA — nunca banner de error.
      // No se persiste en Firestore: es solo orientación de fallback.
      _mensajes.add(MensajeModel(
        id: '_fallback_${DateTime.now().millisecondsSinceEpoch}',
        rol: 'assistant',
        texto: 'En este momento no puedo darte una respuesta detallada. '
            'Por favor intenta nuevamente en unos segundos, o si es urgente, '
            'comunícate directamente con la Clínica San Juan Bautista.',
        timestamp: DateTime.now(),
      ));
    } finally {
      _enviando = false;
      _escribiendo = false;
      notifyListeners();
    }
  }

  Future<void> eliminarChat(String chatId) async {
    try {
      await _firestore.eliminarChat(chatId);
      _chats.removeWhere((c) => c.id == chatId);
      notifyListeners();
    } catch (e, st) {
      debugPrint('ChatController.eliminarChat: $e\n$st');
    }
  }

  String _tituloDesde(String texto) {
    final limpio = texto.replaceAll('\n', ' ').trim();
    return limpio.length <= 40 ? limpio : '${limpio.substring(0, 37)}...';
  }
}
