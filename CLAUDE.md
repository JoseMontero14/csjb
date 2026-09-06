# Aplicación Móvil de Orientación Médica — CSJB

## Contexto del proyecto
- **Tesis:** "Aplicación móvil con IA para la orientación médica a pacientes de una clínica privada en Lima, 2026"
- **Desarrollador:** José Montero (solo developer)
- **Clínica:** San Juan Bautista — Red San Pablo, Lima, Perú
- **Estado:** Fase de desarrollo — diseño UI completado

## Stack técnico
- Flutter/Dart — frontend mobile (Android + iOS)
- Firebase Auth — autenticación correo/contraseña
- Firestore — base de datos principal
- Firebase Cloud Functions — intermediario seguro con OpenAI
- FCM — notificaciones de medicamentos y seguimiento de triaje
- Firebase Storage — fotos de médicos
- OpenAI GPT-4o — chat IA y triaje
- OpenAI GPT-4o Mini — tips de salud diarios
- Durante desarrollo: Ollama local → swap a GPT-4o al finalizar

## Arquitectura
- Patrón MVC + backend serverless Firebase
- Flutter NUNCA llama directo a OpenAI
- Flujo: Flutter → Cloud Function → OpenAI → respuesta al cliente
- Roles admin via Firebase Custom Claims (sin colección "admins")

## Módulos y pantallas

### 1. Autenticación
- Login: correo + contraseña, link "¿Olvidaste tu contraseña?"
- Registro: nombre, correo, contraseña (mín 8 car.), confirmar,
  fecha nacimiento, sexo (Masculino / Femenino / Prefiero no decir)

### 2. Dashboard (Inicio)
- Saludo con fecha
- Card bienestar general (% basado en adherencia a medicamentos)
- Card próximo recordatorio de medicamento
- Card último triaje con nivel de urgencia
- Card tip del día
- Botón emergencia FIJO en el dashboard (no es módulo separado)
- Bottom nav: Inicio · Chat · Triaje · Exámenes · Médicos

### 3. Chat IA
- Listado de conversaciones previas (título auto-generado, fecha, preview)
- Botón "Nueva consulta"
- Pantalla de chat: burbujas usuario (purple) / IA (outline)
- Sugerencias rápidas como chips debajo de la respuesta IA
- Historial persistido en Firestore (colección chats_ia > subcol mensajes)

### 4. Triaje Informativo
- Paso 1/3: selección de síntomas con chips
  (Dolor de cabeza, Fiebre, Tos, Fatiga, Náuseas,
  Dolor abdominal, Mareo, Falta de aire, Dolor de garganta)
- Paso 2/3: intensidad de síntomas → define nivel Leve/Medio/Alto
- Paso 3/3: resultado con nivel de urgencia (orange=Medio, red=Alto, green=Leve)
  + recomendación + fecha de seguimiento
- IMPORTANTE: resultados NO se guardan en Firestore por defecto
- Solo se guarda si el usuario pulsa "Guardar en mi historial"
- Seguimiento a los 3 días vía FCM: pantalla "¿Cómo te sientes?"
  con opciones Mejoré / Sigo igual / Empeoré
- Historial de triajes: fecha, síntomas, badge urgencia,
  estado seguimiento (Pendiente / Respondido)

### 5. Catálogo de Exámenes
- Búsqueda + filtros: Todos / Laboratorio / Imagen / Cardiología
- Lista con nombre, categoría, icono favorito (estrella)
- Bottom sheet detalle: ¿Qué es? / ¿Para qué sirve? / ¿Requiere preparación?
  (keywords importantes en color orange)
- Favoritos marcados con estrella purple

### 6. Directorio Médico
- Filtros por especialidad: chips horizontales scrolleables
- Lista: foto, nombre, especialidad, favorito
- Detalle médico: foto (fuente web San Pablo), nombre, especialidad,
  descripción de la especialidad, días y horarios de atención,
  botón "Ver otros médicos de esta especialidad"

### 7. Medicación
- Tab "Hoy": lista de tomas del día con checkbox + horario
- Tab "Adherencia": vista semanal de cumplimiento
- Bottom sheet "Agregar medicamento": nombre, dosis, frecuencia
  (Cada 8h / Cada 12h / Una vez al día / Personalizado),
  horarios de toma, fecha inicio, checkbox "Sin fecha de fin",
  notas adicionales
- FCM para recordatorios en el horario configurado

### 8. Tips de Salud
- Card destacada (bg purple): tip del día con categoría y descripción
- Feed por categoría: Salud mental / Nutrición / Ejercicio
- Botón "+" para guardar tip
- Generados por GPT-4o Mini, no son estáticos

## Modelo de datos Firestore

```
usuarios/{uid}
  nombre, correo, sexo, fechaNacimiento, grupoSanguineo, enfermedades, alergias

chats_ia/{chatId}
  titulo, creadoEn, uid
  mensajes/{msgId} — rol (user/assistant), texto, timestamp

recordatorios/{recId}
  uid, medicamento, dosis, frecuencia, horarios[], fechaInicio, sinFechaFin, notas
  historial_tomas/{tomaId} — fecha, hora, tomado (bool)

tips_diarios/{tipId}
  texto, categoria, fecha, generadoPor (gpt-4o-mini)

emergencias/{docId}
  nombre, telefono, tipo

medicos/{medicoId}
  nombre, especialidad, foto_url, dias, horario, descripcionEspecialidad

examenes/{examenId}
  nombre, categoria, queEs, parqueServe, requierePreparacion
```

## UI / Diseño
- Primary: #5B2D8E (purple)
- Accent: #F47920 (orange)
- Background: #FAFAF8 (warm white)
- Tipografía: Poppins
- Estilo: cards redondeadas, chips para filtros, bottom sheets para detalles
- Keywords importantes en texto: color orange (#F47920)
- Bottom navigation bar: 5 tabs (Inicio, Chat, Triaje, Exámenes, Médicos)

## Reglas estrictas
- NUNCA llamar OpenAI directamente desde Flutter
- NUNCA guardar resultados de triaje sin acción explícita del usuario
- NUNCA exponer API keys en el cliente Flutter
- NUNCA crear colección "admins" en Firestore (usar Firebase Custom Claims)
- El texto de la IA NUNCA debe dar diagnósticos, solo orientación informativa
- La app funciona autónomamente, sin integración con staff de la clínica

## Pendiente de implementar
- [ ] Paso 2 del triaje (intensidad de síntomas)
- [ ] Pantalla de perfil de usuario / editar datos
- [ ] Vista de adherencia semanal detallada
- [ ] Pantalla de seguimiento post-triaje (FCM deep link)
- [ ] Configuración de Firebase en el proyecto
- [ ] Cloud Functions (Node.js) para OpenAI
