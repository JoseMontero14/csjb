import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mensaje_model.dart';
import '../models/triaje_model.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

// Orientación médica informativa — nunca diagnóstica.
const _kSystemPrompt = '''
Eres un asistente de orientación médica de la Clínica San Juan Bautista, Lima, Perú.
Tu rol es orientar informativamente a los pacientes sobre síntomas, medicamentos y salud general.
NUNCA debes dar diagnósticos médicos ni reemplazar la consulta médica presencial.

DERIVACIÓN A EMERGENCIAS — PRIORIDAD MÁXIMA:
Si el paciente menciona cualquiera de estas señales de riesgo, debes derivar a atención médica de inmediato ANTES de dar cualquier otra información:
- Dolor en el pecho u opresión torácica
- Dificultad para respirar o falta de aire severa
- Sangrado abundante o que no cede
- Confusión, desorientación o pérdida de consciencia
- Síntomas neurológicos: habla arrastrada, visión doble, debilidad súbita en un lado del cuerpo, convulsiones
- Signos de reacción alérgica grave (urticaria generalizada + dificultad respiratoria)
- Fiebre muy alta en recién nacidos o adultos mayores con mal estado general
En estos casos indica claramente "Esto puede ser una emergencia médica. Acude a urgencias o llama al SAMU (106) de inmediato." antes de cualquier otro consejo.

REGLAS DE RESPUESTA:
- Por defecto responde de forma breve y directa (2 a 4 oraciones). Ve al punto sin introducciones largas.
- Solo extiéndete cuando: el usuario pida más detalle explícitamente, o cuando sean señales de alarma o instrucciones de emergencia — en esos casos prioriza claridad y completitud.
- Si el usuario hace varias preguntas en un mismo mensaje, responde primero lo más urgente en pocas líneas y ofrece ampliar el resto.
- Cuando corresponda, recuerda que puede solicitar una cita en la clínica.
- Responde siempre en español, de forma clara y empática.
''';

class CloudFunctionsService {
  Future<String> llamarGemini(List<MensajeModel> mensajes) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${AppConstants.geminiModel}:generateContent'
      '?key=${AppConstants.geminiApiKey}',
    );

    final contents = mensajes
        .map((m) => {
              'role': m.rol == 'user' ? 'user' : 'model',
              'parts': [
                {'text': m.texto}
              ],
            })
        .toList();

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _kSystemPrompt}
        ],
      },
      'contents': contents,
      'generationConfig': {
        // gemini-3.6-flash usa "thinking" tokens que consumen del mismo límite;
        // 8192 garantiza espacio suficiente para razonar y responder completo.
        'maxOutputTokens': 8192,
        'temperature': 0.7,
      },
    });

    final http.Response response;
    try {
      response = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      debugPrint('Gemini red error [${e.runtimeType}]: $e');
      throw Exception(
          'Sin conexión o tiempo de espera agotado. Verifica tu internet.');
    }

    if (response.statusCode != 200) {
      debugPrint('Gemini error ${response.statusCode}: ${response.body}');
      final msg = switch (response.statusCode) {
        400 => 'Solicitud inválida. Intenta de nuevo.',
        401 || 403 => 'Error de autenticación con el asistente.',
        429 => 'Demasiadas consultas. Espera un momento e intenta de nuevo.',
        500 || 503 => 'El asistente no está disponible en este momento.',
        _ => 'Error al contactar el asistente (${response.statusCode}).',
      };
      throw Exception(msg);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      // Gemini bloquea por política de seguridad o respuesta vacía
      debugPrint('Gemini: candidates vacíos. Body: ${response.body}');
      throw Exception(
          'El asistente no pudo responder esta consulta. '
          'Intenta reformularla.');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final finishReason = candidate['finishReason'] as String? ?? 'UNKNOWN';
    debugPrint('Gemini finishReason: $finishReason');

    final parts = candidate['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Respuesta incompleta del asistente. Intenta de nuevo.');
    }

    // Concatena todos los parts — Gemini puede dividir la respuesta en varios.
    final text = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join()
        .trim();

    if (text.isEmpty) {
      throw Exception('Respuesta vacía del asistente. Intenta de nuevo.');
    }
    return text;
  }

  /// Evalúa un triaje y devuelve nivel de urgencia + recomendación + especialidad sugerida.
  /// Lanza [Exception] con mensaje en español si algo falla.
  Future<({UrgencyLevel nivel, String recomendacion, String especialidad})>
      evaluarTriaje({
    required List<String> sintomas,
    required IntensidadSintomas intensidad,
    required String duracion,
  }) async {
    final sintomasStr = sintomas.join(', ');

    const systemPrompt = '''
Eres un asistente médico informativo de la Clínica San Juan Bautista, Lima, Perú.
El paciente ha completado un triaje de síntomas. Tu tarea es:
1. Evaluar los síntomas y devolver un nivel de urgencia EXACTAMENTE como una de estas tres palabras: "Leve", "Moderado", "Alto".
2. Dar una recomendación breve (3-5 oraciones) en español, empática y clara.
3. Sugerir la especialidad médica más adecuada para este caso (ej. Medicina General, Pediatría, Traumatología, Dermatología, Ginecología, Cardiología, Neurología, Gastroenterología, etc.). Si el nivel es Alto, la especialidad debe ser "Emergencias". Si no hay suficiente información para determinar una especialidad específica, usa "Medicina General" por defecto.

REGLAS ESTRICTAS:
- NUNCA dar un diagnóstico médico. Solo orientación informativa.
- Si el nivel es Alto, la primera oración DEBE indicar que debe acudir a urgencias o llamar al SAMU (106) de inmediato. Si hay indicios de crisis de salud mental (pensamientos de hacerse daño, desesperación extrema), menciona también la Línea de la Vida (113).
- Si el nivel es Moderado, recomendar consulta médica en las próximas 24-48 horas.
- Si el nivel es Leve, dar consejos de autocuidado y cuándo buscar atención.
- Si los síntomas son insuficientes o ambiguos para evaluar con confianza, clasifica como "Moderado" por precaución y menciónalo en la recomendación.
- Responde ÚNICAMENTE en este formato JSON válido (sin markdown, sin texto adicional fuera del JSON):
  {"nivel": "Leve|Moderado|Alto", "recomendacion": "...", "especialidad": "..."}
''';

    final userContent =
        'Datos del paciente:\n- Síntomas: $sintomasStr\n- Intensidad: ${intensidad.label}\n- Duración: $duracion';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${AppConstants.geminiModel}:generateContent'
      '?key=${AppConstants.geminiApiKey}',
    );

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userContent}
          ],
        }
      ],
      'generationConfig': {
        // gemini-3.6-flash usa thinking tokens; 4096 da margen para razonar
        // y responder el JSON completo sin truncar.
        'maxOutputTokens': 4096,
        'temperature': 0.3,
        'responseMimeType': 'application/json',
      },
    });

    final http.Response response;
    try {
      response = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      debugPrint('Gemini triaje red error [${e.runtimeType}]: $e');
      throw Exception(
          'Sin conexión o tiempo de espera agotado. Verifica tu internet.');
    }

    if (response.statusCode != 200) {
      debugPrint('Gemini triaje error ${response.statusCode}: ${response.body}');
      final msg = switch (response.statusCode) {
        400 => 'Solicitud inválida. Intenta de nuevo.',
        401 || 403 => 'Error de autenticación con el asistente.',
        429 => 'Demasiadas consultas. Espera un momento e intenta de nuevo.',
        500 || 503 => 'El asistente no está disponible en este momento.',
        _ => 'Error al contactar el asistente (${response.statusCode}).',
      };
      throw Exception(msg);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      debugPrint('Gemini triaje: candidates vacíos. Body: ${response.body}');
      throw Exception(
          'El asistente no pudo evaluar los síntomas. Intenta de nuevo.');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final finishReason = candidate['finishReason'] as String? ?? 'UNKNOWN';
    debugPrint('Gemini triaje finishReason: $finishReason');

    final parts = candidate['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Respuesta incompleta del asistente. Intenta de nuevo.');
    }

    final rawText = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join()
        .trim();

    // Parseo defensivo — si el JSON es inválido mostramos error al usuario.
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(rawText) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Gemini triaje: JSON inválido recibido: $rawText');
      throw Exception(
          'La respuesta del asistente no pudo procesarse. Intenta de nuevo.');
    }

    final nivelStr = parsed['nivel'] as String?;
    final recomendacion = parsed['recomendacion'] as String?;
    final especialidad =
        (parsed['especialidad'] as String?)?.trim().isNotEmpty == true
            ? parsed['especialidad'] as String
            : 'Medicina General';

    if (nivelStr == null || recomendacion == null || recomendacion.isEmpty) {
      debugPrint('Gemini triaje: campos faltantes en JSON: $parsed');
      throw Exception('Respuesta incompleta del asistente. Intenta de nuevo.');
    }

    final nivel = switch (nivelStr) {
      'Leve' => UrgencyLevel.low,
      'Alto' => UrgencyLevel.high,
      _ => UrgencyLevel.medium, // 'Moderado' y cualquier valor inesperado
    };

    return (nivel: nivel, recomendacion: recomendacion, especialidad: especialidad);
  }
}
