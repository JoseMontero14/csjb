// Copia este archivo como constants.dart y rellena los valores reales.
// constants.dart está en .gitignore — nunca subas la key real.
//
// TODO producción: eliminar geminiApiKey de aquí y moverlo a
// Cloud Functions (Node.js) para que la key nunca llegue al cliente.

abstract final class AppConstants {
  static const geminiApiKey = 'TU_API_KEY_DE_GEMINI_AQUI';
  static const geminiModel = 'gemini-1.5-flash';

  static const List<String> sugerenciasChat = [
    '¿Debo ir a urgencias?',
    '¿Qué significa mi resultado?',
    'Efectos de mi medicamento',
  ];
}
