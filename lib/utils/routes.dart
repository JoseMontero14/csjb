import 'package:flutter/material.dart';
import '../views/auth/login_view.dart';
import '../views/auth/registro_view.dart';
import '../views/dashboard/dashboard_view.dart';
import '../views/chat/chat_lista_view.dart';
import '../views/chat/chat_detalle_view.dart';
import '../views/triaje/triaje_sintomas_view.dart';
import '../views/triaje/triaje_intensidad_view.dart';
import '../views/triaje/triaje_resultado_view.dart';
import '../views/triaje/triaje_historial_view.dart';
import '../views/examenes/examenes_view.dart';
import '../views/medicos/medicos_view.dart';
import '../views/medicos/medico_detalle_view.dart';
import '../views/medicacion/medicacion_view.dart';
import '../views/tips/tips_view.dart';
import '../views/perfil/perfil_view.dart';
import '../views/perfil/reporte_view.dart';
import '../views/onboarding/onboarding_view.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const registro = '/registro';
  static const dashboard = '/dashboard';
  static const chatLista = '/chat-lista';
  static const chatDetalle = '/chat-detalle';
  static const triajeSintomas = '/triaje-sintomas';
  static const triajeIntensidad = '/triaje-intensidad';
  static const triajeResultado = '/triaje-resultado';
  static const triajeHistorial = '/triaje-historial';
  static const examenes = '/examenes';
  static const medicos = '/medicos';
  static const medicoDetalle = '/medico-detalle';
  static const medicacion = '/medicacion';
  static const tips = '/tips';
  static const perfil = '/perfil';
  static const reporte = '/reporte';
  static const onboarding = '/onboarding';

  static const initial = login;

  static Map<String, WidgetBuilder> get all => {
        login: (_) => const LoginView(),
        registro: (_) => const RegistroView(),
        dashboard: (_) => const DashboardView(),
        chatLista: (_) => const ChatListaView(),
        chatDetalle: (_) => const ChatDetalleView(),
        triajeSintomas: (_) => const TriajeSintomasView(),
        triajeIntensidad: (_) => const TriajeIntensidadView(),
        triajeResultado: (_) => const TriajeResultadoView(),
        triajeHistorial: (_) => const TriajeHistorialView(),
        examenes: (_) => const ExamenesView(),
        medicos: (_) => const MedicosView(),
        medicoDetalle: (_) => const MedicoDetalleView(),
        medicacion: (_) => const MedicacionView(),
        tips: (_) => const TipsView(),
        perfil: (_) => const PerfilView(),
        reporte: (_) => const ReporteView(),
        onboarding: (_) => const OnboardingView(),
      };

  // Navegación con argumento tipado — evita casteos en las vistas
  static Future<T?> push<T>(BuildContext context, String route,
          {Object? args}) =>
      Navigator.pushNamed<T>(context, route, arguments: args);

  static Future<T?> pushReplacement<T>(BuildContext context, String route,
          {Object? args}) =>
      Navigator.pushReplacementNamed<T, dynamic>(context, route,
          arguments: args);

  static Future<T?> pushAndRemoveAll<T>(BuildContext context, String route,
          {Object? args}) =>
      Navigator.pushNamedAndRemoveUntil<T>(
        context,
        route,
        (_) => false,
        arguments: args,
      );

  static void pop<T>(BuildContext context, [T? result]) =>
      Navigator.pop<T>(context, result);
}
