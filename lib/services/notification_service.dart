import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../firebase_options.dart';
import '../models/recordatorio_model.dart';

const _kAccionConfirmar = 'CONFIRMAR';
const _kAccionOmitir = 'OMITIR';
const _kAccionPosponer = 'POSPONER_30';
const _kCanalId = 'medicacion_v1';
const _kCanalNombre = 'Recordatorios de medicación';
const _kBatteryChannel = MethodChannel('com.example.csjb/battery');

// ── Background handler ────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _backgroundHandler(NotificationResponse response) async {
  final action = response.actionId;
  final payload = response.payload;
  if (action == null || payload == null) return;

  final parts = payload.split('|');
  if (parts.length < 3) return;
  final recId = parts[0];
  final tomaId = parts[1];
  final horaIdx = int.tryParse(parts[2]) ?? 0;

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Ya inicializado en el proceso principal — ignorar
  }

  final db = FirebaseFirestore.instance;

  try {
    switch (action) {
      case _kAccionConfirmar:
        if (tomaId.isNotEmpty) await _marcarToma(db, recId, tomaId, tomado: true);
      case _kAccionOmitir:
        if (tomaId.isNotEmpty) await _marcarToma(db, recId, tomaId, tomado: false);
      case _kAccionPosponer:
        await _posponerBackground(recId, tomaId, horaIdx);
    }
  } catch (e) {
    debugPrint('_backgroundHandler error: $e');
  }
}

Future<void> _marcarToma(FirebaseFirestore db, String recId, String tomaId,
    {required bool tomado}) async {
  try {
    await db
        .collection('recordatorios')
        .doc(recId)
        .collection('historial_tomas')
        .doc(tomaId)
        .update({'tomado': tomado});
  } catch (e) {
    debugPrint('notification_service._marcarToma ERROR: $e');
  }
}

Future<void> _posponerBackground(String recId, String tomaId, int horaIdx) async {
  try {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Lima'));
    final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30));
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.zonedSchedule(
      _tomaId(recId, horaIdx) + 10000,
      'Recordatorio pospuesto',
      'No olvides tomar tu medicamento',
      scheduled,
      _detalles('$recId|$tomaId|$horaIdx'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$recId|$tomaId|$horaIdx',
    );
  } catch (e) {
    debugPrint('notification_service._posponerBackground ERROR: $e');
  }
}

int _tomaId(String recId, int idx) => recId.hashCode.abs() % 9000000 + idx;

NotificationDetails _detalles(String payload) => NotificationDetails(
      android: AndroidNotificationDetails(
        _kCanalId,
        _kCanalNombre,
        importance: Importance.max,
        priority: Priority.max,
        actions: const [
          AndroidNotificationAction(_kAccionConfirmar, 'Confirmar',
              showsUserInterface: false),
          AndroidNotificationAction(_kAccionOmitir, 'Omitir',
              showsUserInterface: false, cancelNotification: true),
          AndroidNotificationAction(_kAccionPosponer, 'Posponer 30 min',
              showsUserInterface: false),
        ],
      ),
      iOS: const DarwinNotificationDetails(),
    );

// ── Singleton ──────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // ── Init ─────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_ready) return;

    // PUNTO 1: timezone — debe inicializarse antes de cualquier zonedSchedule
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Lima'));
    debugPrint('>>> [NOTIF-1] timezone inicializado: local=${tz.local.name}');

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: _onForegroundResponse,
      // No registrar background handler: evita que ScheduledNotificationReceiver
      // intente levantar un Flutter AOT engine desde cero al disparar la alarma,
      // lo cual crasheaba el proceso en release con la app en segundo plano.
    );
    debugPrint('>>> [NOTIF-2] plugin inicializado');

    // PUNTO 3: canal de notificación (Android 8+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kCanalId,
          _kCanalNombre,
          description: 'Recordatorios programados de medicación',
          importance: Importance.max,
        ));
    debugPrint('>>> [NOTIF-3] canal "$_kCanalId" creado con importancia MAX');

    // PUNTO 2a: permiso POST_NOTIFICATIONS (Android 13+)
    final permNotif = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    debugPrint('>>> [NOTIF-2a] permiso notificaciones concedido: $permNotif');

    // PUNTO 2b: permiso alarmas exactas (Android 12+)
    final permAlarm = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    debugPrint('>>> [NOTIF-2b] permiso alarmas exactas concedido: $permAlarm');

    // PUNTO 6: exención optimización de batería (crítico en Samsung)
    await _requestBatteryOptimizationExemption();

    _ready = true;
    debugPrint('>>> [NOTIF-OK] NotificationService listo');
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      final isIgnoring = await _kBatteryChannel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          true;
      debugPrint('>>> [NOTIF-6] isIgnoringBatteryOptimizations=$isIgnoring');
      if (!isIgnoring) {
        debugPrint(
            '>>> [NOTIF-6] *** ABRIENDO DIÁLOGO DE EXENCIÓN DE BATERÍA ***');
        await _kBatteryChannel
            .invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } on PlatformException catch (e) {
      debugPrint('>>> [NOTIF-6] error batería: $e');
    }
  }

  // ── Programar ────────────────────────────────────────────────────────────────

  Future<void> programarRecordatorios(RecordatorioModel rec, String recId) async {
    if (!rec.frecuencia.conRecordatorio) {
      debugPrint('>>> [SCHED] "${rec.nombreCompleto}" no requiere recordatorio, omitido');
      return;
    }
    debugPrint(
        '>>> [SCHED] Programando "${rec.nombreCompleto}" — ${rec.horarios.length} hora(s): ${rec.horarios}');
    for (var i = 0; i < rec.horarios.length; i++) {
      await _programarHora(rec: rec, recId: recId, horaStr: rec.horarios[i], idx: i);
    }
    // PUNTO 5: verificar que quedó en la cola
    await _logPendingNotifications();
  }

  Future<void> _programarHora({
    required RecordatorioModel rec,
    required String recId,
    required String horaStr,
    required int idx,
  }) async {
    final parts = horaStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
        .subtract(const Duration(minutes: 5));
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      debugPrint(
          '>>> [SCHED] hora $horaStr ya pasó hoy (con -5min), movido a mañana');
    }

    final notifId = _tomaId(recId, idx);
    final payload = '$recId||$idx';

    debugPrint(
      '>>> [SCHED] id=$notifId  hora_config=$horaStr  '
      'disparo=${scheduled.hour}:${scheduled.minute.toString().padLeft(2, "0")}  '
      'ISO=${scheduled.toIso8601String()}',
    );

    // PUNTO 5: verificar permiso de alarma exacta antes de programar
    final canExact = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.canScheduleExactNotifications();
    debugPrint('>>> [SCHED] canScheduleExactNotifications=$canExact');

    try {
      // PUNTO 4: usar alarmClock — el modo más confiable en Samsung para wakeup exacto
      await _plugin.zonedSchedule(
        notifId,
        'Recordatorio de medicamento',
        'En 5 minutos toca tu dosis de ${rec.nombreCompleto}',
        scheduled,
        _detalles(payload),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('>>> [SCHED] ✓ zonedSchedule OK para id=$notifId');
    } catch (e) {
      debugPrint('>>> [SCHED] ✗ ERROR en zonedSchedule id=$notifId: $e');
    }
  }

  // PUNTO 5: listar notificaciones pendientes
  Future<void> _logPendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('>>> [PENDING] ${pending.length} notificación(es) en cola:');
    for (final n in pending) {
      debugPrint('>>>   id=${n.id} title="${n.title}" body="${n.body}"');
    }
  }

  // ── Cancelar ─────────────────────────────────────────────────────────────────

  Future<void> cancelarRecordatorios(String recId) async {
    for (var i = 0; i < 3; i++) {
      await _plugin.cancel(_tomaId(recId, i));
      await _plugin.cancel(_tomaId(recId, i) + 10000);
    }
    debugPrint('>>> [CANCEL] cancelados recordatorios de recId=$recId');
  }

  // ── Posponer desde UI ────────────────────────────────────────────────────────

  Future<void> posponerDesdeUI({
    required String recId,
    required String tomaId,
    required int horaIdx,
  }) async {
    final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30));
    await _plugin.zonedSchedule(
      _tomaId(recId, horaIdx) + 10000,
      'Recordatorio pospuesto',
      'No olvides tomar tu medicamento',
      scheduled,
      _detalles('$recId|$tomaId|$horaIdx'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$recId|$tomaId|$horaIdx',
    );
  }

  // ── Prueba INMEDIATA (debug only) — usa show(), NO zonedSchedule ─────────────

  /// Notificación inmediata vía show() — sin AlarmManager, sin permisos de alarma.
  /// Si esta aparece → el canal y los permisos básicos están bien.
  /// Si esta NO aparece → el problema es más básico (canal/permiso).
  Future<void> probarInmediata() async {
    debugPrint('>>> [INMEDIATA] ============ INICIO show() INMEDIATO ============');

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Canales registrados
    final channels = await androidPlugin?.getNotificationChannels();
    debugPrint('>>> [INMEDIATA] canales registrados: ${channels?.length ?? 0}');
    for (final ch in channels ?? []) {
      debugPrint('>>>   canal id="${ch.id}" name="${ch.name}" importance=${ch.importance}');
    }

    // areNotificationsEnabled
    final enabled = await androidPlugin?.areNotificationsEnabled();
    debugPrint('>>> [INMEDIATA] areNotificationsEnabled=$enabled');

    // canScheduleExactNotifications
    final canExact = await androidPlugin?.canScheduleExactNotifications();
    debugPrint('>>> [INMEDIATA] canScheduleExactNotifications=$canExact');

    try {
      await _plugin.show(
        888888,
        'Notificación inmediata',
        'Prueba show() — sin programación',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kCanalId,
            _kCanalNombre,
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
      debugPrint('>>> [INMEDIATA] ✓ show() llamado sin excepción — revisa la barra ahora');
    } catch (e, st) {
      debugPrint('>>> [INMEDIATA] ✗ EXCEPCIÓN en show(): $e');
      debugPrint('>>> [INMEDIATA] stacktrace: $st');
    }
    debugPrint('>>> [INMEDIATA] ============ FIN show() INMEDIATO ============');
  }

  // ── Prueba PROGRAMADA (debug only) ───────────────────────────────────────────

  Future<void> probarNotificacion() async {
    debugPrint('>>> [TEST] ======== INICIO DIAGNÓSTICO zonedSchedule ========');

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // PUNTO 1: zona horaria
    debugPrint('>>> [TEST-1] tz.local.name   = ${tz.local.name}');
    debugPrint('>>> [TEST-1] DateTime.now()  = ${DateTime.now()}');
    debugPrint('>>> [TEST-1] TZDateTime.now()= ${tz.TZDateTime.now(tz.local)}');

    // PUNTO 3a: areNotificationsEnabled
    final notifEnabled = await androidPlugin?.areNotificationsEnabled();
    debugPrint('>>> [TEST-3a] areNotificationsEnabled = $notifEnabled');

    // PUNTO 3b: isIgnoringBatteryOptimizations (vía MethodChannel nativo)
    try {
      final ignoringBattery = await _kBatteryChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      debugPrint('>>> [TEST-3b] isIgnoringBatteryOptimizations = $ignoringBattery');
      if (!ignoringBattery) {
        debugPrint('>>> [TEST-3b] *** BATERÍA NO EXENTA — Samsung puede matar la alarma ***');
        debugPrint('>>> [TEST-3b]     Abriendo diálogo de exención...');
        await _kBatteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } on PlatformException catch (e) {
      debugPrint('>>> [TEST-3b] error MethodChannel batería: $e');
    }

    // PUNTO 5: canScheduleExactNotifications
    final canExact = await androidPlugin?.canScheduleExactNotifications();
    debugPrint('>>> [TEST-5] canScheduleExactNotifications = $canExact');
    // Nota: alarmClock NO requiere este permiso — pero lo registramos igual para diagnóstico

    // PUNTO 2: calcular fecha de disparo (1 minuto en el futuro)
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = now.add(const Duration(minutes: 1));
    debugPrint(
      '>>> [TEST-2] now       = '
      '${now.hour.toString().padLeft(2,"0")}:${now.minute.toString().padLeft(2,"0")}:${now.second.toString().padLeft(2,"0")}',
    );
    debugPrint(
      '>>> [TEST-2] scheduled = '
      '${scheduled.year}-${scheduled.month.toString().padLeft(2,"0")}-${scheduled.day.toString().padLeft(2,"0")} '
      '${scheduled.hour.toString().padLeft(2,"0")}:${scheduled.minute.toString().padLeft(2,"0")}:${scheduled.second.toString().padLeft(2,"0")} '
      '[${scheduled.toIso8601String()}]',
    );

    // PUNTO 2 diff: comparar contra TZDateTime.now() ACTUAL (no el calculado antes)
    final diffSec = scheduled.difference(tz.TZDateTime.now(tz.local)).inSeconds;
    debugPrint(
      '>>> [TEST-2] diff now→scheduled = $diffSec s '
      '${diffSec <= 0 ? "*** PASADO — NO DISPARARÁ ***" : "(OK, es futuro)"}',
    );

    // PUNTO 6: manifest
    debugPrint('>>> [TEST-6] permisos en manifest: SCHEDULE_EXACT_ALARM ✓  USE_EXACT_ALARM ✓  REQUEST_IGNORE_BATTERY_OPTIMIZATIONS ✓');
    debugPrint('>>> [TEST-4] androidScheduleMode = alarmClock (sin matchDateTimeComponents)');

    try {
      // SIN matchDateTimeComponents para la prueba — una sola vez, sin recurrencia
      await _plugin.zonedSchedule(
        999999,
        'Prueba alarmClock',
        'zonedSchedule disparó ✓ — ${now.hour}:${now.minute.toString().padLeft(2,"0")}',
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kCanalId,
            _kCanalNombre,
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('>>> [TEST] ✓ zonedSchedule llamado sin excepción');
    } catch (e, st) {
      debugPrint('>>> [TEST] ✗ EXCEPCIÓN en zonedSchedule: $e');
      debugPrint('>>> [TEST] stacktrace: $st');
    }

    // PUNTO 4: verificar lista de pendientes — debe mostrar al menos id=999999
    await _logPendingNotifications();
    debugPrint('>>> [TEST] ======== FIN DIAGNÓSTICO — espera 1 min ========');
  }

  // ── Foreground handler ───────────────────────────────────────────────────────

  void _onForegroundResponse(NotificationResponse response) {
    debugPrint(
      '>>> [FOREGROUND] notificación recibida: '
      'action=${response.actionId} payload=${response.payload}',
    );
  }
}
