import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mensaje_model.dart';
import '../models/tip_model.dart';
import '../models/triaje_model.dart';
import '../models/usuario_model.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

// ── Código no reintentable (400, 401, 403) ────────────────────────────────────
class _NoReintentar {
  const _NoReintentar(this.inner);
  final Exception inner;
}

// ── Códigos HTTP que sí vale la pena reintentar ───────────────────────────────
const _kReintentables = {429, 500, 502, 503, 504};

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

class GeminiService {
  // ── Helper de reintento con backoff exponencial ──────────────────────────────
  //
  // Reintenta hasta 3 veces ante errores de red y códigos HTTP transitoriamente
  // fallidos. Devuelve el primer Response exitoso (status no en _kReintentables
  // y no 400/401/403). Lanza Exception en español si los 3 intentos fallan.
  Future<http.Response> _postConReintento(Uri url, String body) async {
    const maxIntentos = 3;
    const backoff = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];

    Exception? ultimoError;

    for (int i = 0; i < maxIntentos; i++) {
      if (i > 0) await Future.delayed(backoff[i - 1]);

      try {
        final response = await http
            .post(url, headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 25));

        // Sin reintento: errores en el lado del cliente o autenticación
        if (response.statusCode == 400) {
          throw _NoReintentar(Exception('Solicitud inválida. Intenta de nuevo.'));
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw _NoReintentar(
              Exception('Error de autenticación con el asistente.'));
        }

        // Reintentable: servidor caído o rate limit
        if (_kReintentables.contains(response.statusCode)) {
          debugPrint(
              'Gemini ${response.statusCode} — intento ${i + 1}/$maxIntentos');
          ultimoError = Exception(switch (response.statusCode) {
            429 => 'Demasiadas consultas. Espera un momento e intenta de nuevo.',
            500 || 503 => 'El asistente no está disponible en este momento.',
            _ => 'Error al contactar el asistente (${response.statusCode}).',
          });
          continue;
        }

        return response; // éxito
      } on _NoReintentar catch (e) {
        throw e.inner;
      } on TimeoutException catch (e) {
        debugPrint('Gemini timeout — intento ${i + 1}/$maxIntentos: $e');
        ultimoError =
            Exception('Tiempo de espera agotado. Verifica tu conexión.');
      } on SocketException catch (e) {
        debugPrint('Gemini SocketException — intento ${i + 1}/$maxIntentos: $e');
        ultimoError =
            Exception('Sin conexión a internet. Verifica tu red.');
      } on Exception catch (e) {
        debugPrint('Gemini error inesperado — intento ${i + 1}/$maxIntentos: $e');
        ultimoError = Exception('Error al conectar con el asistente.');
      }
    }

    throw ultimoError ?? Exception('Error al conectar con el asistente.');
  }

  Future<String> llamarGemini(
    List<MensajeModel> mensajes, {
    String? contextoUsuario,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${AppConstants.geminiModel}:generateContent'
      '?key=${AppConstants.geminiApiKey}',
    );

    final systemPrompt = contextoUsuario != null
        ? '$_kSystemPrompt\nContexto del paciente (confidencial — úsalo para '
            'personalizar tus respuestas, sin mencionarlo explícitamente a '
            'menos que sea directamente relevante para la pregunta del '
            'usuario):\n$contextoUsuario'
        : _kSystemPrompt;

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
          {'text': systemPrompt}
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

    final response = await _postConReintento(url, body);

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
3. Sugerir la especialidad médica más adecuada eligiendo EXACTAMENTE una de las siguientes (copia el texto tal cual, sin cambiar mayúsculas ni tildes):
   ANESTESIOLOGIA, CARDIOLOGIA, CIRUG.CABEZA-CUELLO MAXILOFACIAL, CIRUG.PLASTICA ESTET.QUEMADOS, CIRUGIA GENERAL, CIRUGIA ORAL Y MAXILO FACIAL, CIRUGIA PEDIATRICA, CIRUGIA TORACICA Y CARDIOVASCULAR, DERMATOLOGIA, EMERGENCISTA, ENDOCRINOLOGIA, GASTROENTEROLOGIA, GERIATRIA, GINECO-OBSTETRICIA, GINECOLOGIA ONCOLOGICA, MEDICINA FISICA-REHABILITACION, MEDICINA INTERNA, NEFROLOGIA, NEUMOLOGIA, NEUROCIRUGIA, NEUROLOGIA, NUTRICIONISTA, ODONTOLOGIA GENERAL, ODONTOPEDIATRIA, OFTALMOLOGIA, ONCOLOGIA MEDICA, OTORRINO LARINGOLOGIA, PEDIATRIA Y NEONATOLOGIA, PSIQUIATRIA, REUMATOLOGIA, TRAUMATOLOGIA Y CIRUGIA ARTROSCOPICA, UROLOGIA.
   Si el nivel es Alto, usa "EMERGENCISTA". Si los síntomas no apuntan claramente a ninguna especialidad, usa "MEDICINA INTERNA".

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

    final response = await _postConReintento(url, body);

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

  /// Genera 2 tips de salud personalizados para [usuario] usando Gemini.
  /// Devuelve una lista de 2 pares (texto, categoría).
  /// Lanza [Exception] con mensaje en español si algo falla.
  Future<List<({String texto, TipCategoria categoria})>> generarTipDelDia(
    UsuarioModel usuario,
  ) async {
    const systemPrompt = '''
Eres un generador de consejos de salud para la Clínica San Juan Bautista, Lima, Perú.
Tu tarea es generar EXACTAMENTE 2 consejos de salud personalizados para el paciente, de categorías distintas.

REGLAS ABSOLUTAS:
- NUNCA des diagnósticos médicos.
- NUNCA menciones medicamentos específicos por nombre.
- NUNCA menciones datos del paciente explícitamente (úsalos solo para personalizar el enfoque).
- Cada consejo: máximo 1 oración corta (~15-20 palabras), accionable y positivo.
- Las 2 categorías deben ser diferentes entre sí.
- Responde SOLO con el JSON indicado, sin texto adicional.

Responde ÚNICAMENTE en este formato JSON válido (sin markdown):
[
  {"texto": "Consejo breve aquí.", "categoria": "UNA de: nutricion | actividad_fisica | bienestar_mental | sueno | hidratacion | prevencion | medicacion"},
  {"texto": "Otro consejo breve.", "categoria": "OTRA categoría diferente a la anterior"}
]
''';

    final edad = DateTime.now().difference(usuario.fechaNacimiento).inDays ~/ 365;
    final sexoLabel = usuario.sexo.label;
    final enfermedades = usuario.enfermedades.isEmpty
        ? 'ninguna registrada'
        : usuario.enfermedades.join(', ');
    final alergias = usuario.alergias.isEmpty
        ? 'ninguna registrada'
        : usuario.alergias.join(', ');
    final prefs = usuario.preferenciasSalud;

    // Actividad física: campo top-level primero, fallback a preferenciasSalud legacy
    final actividad = usuario.actividadFisica
        ?? prefs?['actividadFisica'] as String?
        ?? 'no registrado';

    // Categorías de tips preferidas
    final temas = usuario.categoriasTips.isNotEmpty
        ? usuario.categoriasTips.join(', ')
        : (prefs != null
            ? (prefs['temasInteres'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .join(', ') ??
                'general'
            : 'general');

    // Campos adicionales del perfil ampliado (null-safe)
    final tipoCondicion = usuario.tipoCondicion;
    final otraCondicion = usuario.otraCondicionDescripcion;
    final embarazo = usuario.embarazoLactancia;
    final prefExplicacion = usuario.preferenciaExplicacion;
    final objetivo = usuario.objetivoSalud;

    final buffer = StringBuffer('''
Genera 2 consejos de salud para hoy, de categorías distintas.

Perfil del paciente (confidencial — úsalo para personalizar sin mencionar los datos directamente):
- Sexo: $sexoLabel
- Edad aproximada: $edad años
- Condiciones de salud: $enfermedades${tipoCondicion != null ? ' ($tipoCondicion)' : ''}${otraCondicion != null ? ' — detalle: $otraCondicion' : ''}
- Alergias: $alergias
- Nivel de actividad física: $actividad
- Temas de interés en salud: $temas
''');
    if (embarazo != null && embarazo != 'No aplica' && embarazo != 'Prefiero no responder') {
      buffer.writeln('- Embarazo/lactancia: $embarazo');
    }
    if (prefExplicacion != null) {
      buffer.writeln('- Prefiere explicaciones: $prefExplicacion');
    }
    if (objetivo != null) {
      buffer.writeln('- Objetivo principal de salud: $objetivo');
    }
    buffer.writeln('\nPrioriza las categorías que coincidan con los temas de interés del paciente.');

    final userContent = buffer.toString();

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
        'maxOutputTokens': 4096,
        'temperature': 0.8,
        'responseMimeType': 'application/json',
      },
    });

    final response = await _postConReintento(url, body);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      debugPrint('Gemini tip: candidates vacíos. Body: ${response.body}');
      throw Exception('El asistente no pudo generar el tip. Intenta de nuevo.');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final parts = candidate['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Respuesta incompleta del asistente. Intenta de nuevo.');
    }

    final rawText = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join()
        .trim();

    final List<dynamic> parsed;
    try {
      parsed = jsonDecode(rawText) as List<dynamic>;
    } catch (e) {
      debugPrint('Gemini tip: JSON inválido: $rawText');
      throw Exception(
          'La respuesta del asistente no pudo procesarse. Intenta de nuevo.');
    }

    if (parsed.length < 2) {
      debugPrint('Gemini tip: se esperaban 2 items, llegaron ${parsed.length}');
      throw Exception('Respuesta incompleta del asistente. Intenta de nuevo.');
    }

    return parsed.take(2).map((item) {
      final m = item as Map<String, dynamic>;
      final texto = (m['texto'] as String? ?? '').trim();
      final categoriaRaw = m['categoria'] as String? ?? '';
      if (texto.isEmpty) {
        throw Exception('Respuesta incompleta del asistente. Intenta de nuevo.');
      }
      return (texto: texto, categoria: TipCategoriaX.fromGeminiString(categoriaRaw));
    }).toList();
  }

  /// Genera un análisis inteligente del estado de salud del paciente basado en
  /// sus registros de los últimos 7 días. Devuelve el JSON parseado.
  /// Lanza [Exception] con mensaje en español si algo falla.
  Future<Map<String, dynamic>> generarAnalisisSalud({
    required Map<String, ({int total, int tomadas})> adherenciaMeds,
    required int totalTriajes,
    required int triajesLeve,
    required int triajesMedio,
    required int triajesAlto,
    required List<String> especialidades,
    required int totalChats,
    required List<String> condiciones,
    String? objetivoSalud,
    String? actividadFisica,
  }) async {
    const systemPrompt = '''
Eres un asistente de análisis de salud de la Clínica San Juan Bautista, Lima, Perú.
Tu tarea es analizar los registros del paciente de los últimos 7 días y generar un análisis estructurado.
NUNCA des diagnósticos médicos ni reemplaces la evaluación médica presencial.
NUNCA menciones los datos del paciente explícitamente — úsalos solo para personalizar el análisis.
Usa lenguaje empático, claro y en español.
Responde SOLO con el JSON indicado, sin texto adicional ni markdown.

Responde ÚNICAMENTE en este formato JSON válido:
{
  "resumen": "2-3 oraciones que sintetizan la situación general del paciente",
  "observaciones": [
    {
      "area": "adherencia | triajes | actividad | medicacion",
      "titulo": "Título corto de la observación",
      "texto": "1-2 oraciones con la observación basada en los datos",
      "tipo": "positivo | neutro | atencion"
    }
  ],
  "recomendaciones": [
    "Recomendación informativa corta 1",
    "Recomendación informativa corta 2"
  ],
  "limitaciones": "Una oración sobre las limitaciones del análisis"
}
''';

    int totalTomas = 0, totalTomadas = 0;
    for (final a in adherenciaMeds.values) {
      totalTomas += a.total;
      totalTomadas += a.tomadas;
    }
    final adherenciaGlobal =
        totalTomas > 0 ? (totalTomadas / totalTomas * 100).round() : 0;

    final buffer = StringBuffer(
      'Analiza los siguientes registros de salud del paciente '
      'de los últimos 7 días y genera un análisis estructurado.\n\n'
      'DATOS DEL PERIODO:\n\n'
      'Adherencia a medicamentos:\n'
      '- Global: $adherenciaGlobal% ($totalTomadas/$totalTomas tomas registradas)\n',
    );
    for (final entry in adherenciaMeds.entries) {
      final pct = entry.value.total > 0
          ? (entry.value.tomadas / entry.value.total * 100).round()
          : 0;
      buffer.writeln(
          '  · ${entry.key}: $pct% (${entry.value.tomadas}/${entry.value.total})');
    }
    buffer.writeln('\nTriajes guardados: $totalTriajes');
    if (totalTriajes > 0) {
      buffer.writeln(
          '  · Leve: $triajesLeve, Moderado: $triajesMedio, Alto: $triajesAlto');
      if (especialidades.isNotEmpty) {
        buffer.writeln(
            '  · Especialidades sugeridas: ${especialidades.join(', ')}');
      }
    }
    buffer.writeln('\nActividad en Chat IA: $totalChats conversaciones en total');
    if (condiciones.isNotEmpty) {
      buffer.writeln(
          '\nCondiciones de salud del paciente: ${condiciones.join(', ')}');
    }
    if (objetivoSalud != null) {
      buffer.writeln('Objetivo de salud: $objetivoSalud');
    }
    if (actividadFisica != null) {
      buffer.writeln('Nivel de actividad física: $actividadFisica');
    }

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
            {'text': buffer.toString()}
          ],
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 2048,
        'temperature': 0.4,
        'responseMimeType': 'application/json',
      },
    });

    final response = await _postConReintento(url, body);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      debugPrint('Gemini análisis: candidates vacíos. Body: ${response.body}');
      throw Exception(
          'El asistente no pudo generar el análisis. Intenta de nuevo.');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final parts = candidate['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Respuesta incompleta del asistente. Intenta de nuevo.');
    }

    final rawText = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join()
        .trim();

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(rawText) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Gemini análisis: JSON inválido: $rawText');
      throw Exception(
          'La respuesta del asistente no pudo procesarse. Intenta de nuevo.');
    }

    final resumen = parsed['resumen'] as String?;
    final observaciones = parsed['observaciones'] as List?;
    final recomendaciones = parsed['recomendaciones'] as List?;

    if (resumen == null ||
        resumen.isEmpty ||
        observaciones == null ||
        observaciones.isEmpty ||
        recomendaciones == null ||
        recomendaciones.isEmpty) {
      debugPrint('Gemini análisis: campos faltantes en JSON: $parsed');
      throw Exception('Respuesta incompleta del asistente. Intenta de nuevo.');
    }

    return parsed;
  }
}
