import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _controller = AuthController();

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _controller.login(
      correo: _correoCtrl.text,
      contrasena: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      final tienePreferencias =
          _controller.usuario?.preferenciasSalud != null;
      AppRoutes.pushAndRemoveAll(
        context,
        tienePreferencias ? AppRoutes.dashboard : AppRoutes.onboarding,
      );
    } else {
      _showError(_controller.errorMessage!);
    }
  }

  Future<void> _resetPassword() async {
    final correo = _correoCtrl.text.trim();
    if (correo.isEmpty) {
      _showError('Ingresa tu correo primero para recuperar la contraseña.');
      return;
    }
    await _controller.enviarResetPassword(correo);
    if (!mounted) return;
    if (_controller.status == AuthStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo de recuperación enviado. Revisa tu bandeja.'),
        ),
      );
    } else {
      _showError(_controller.errorMessage!);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                bottomPadding + AppSpacing.lg,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.04),
                    _Logo(),
                    SizedBox(height: screenHeight * 0.04),
                    Text(
                      'Bienvenido',
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Ingresa con tu cuenta para continuar',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppInput(
                      controller: _correoCtrl,
                      label: 'Correo electrónico',
                      hint: 'ejemplo@correo.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: _validateCorreo,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppInput(
                      controller: _passwordCtrl,
                      label: 'Contraseña',
                      hint: 'Mínimo 8 caracteres',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: _validatePassword,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            _controller.isLoading ? null : _resetPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    AppButton(
                      label: 'Ingresar',
                      onPressed: _controller.isLoading ? null : _login,
                      loading: _controller.isLoading,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.outlined(
                      label: 'Crear cuenta',
                      onPressed: _controller.isLoading
                          ? null
                          : () => AppRoutes.push(context, AppRoutes.registro),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validateCorreo(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo.';
    final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(v.trim())) return 'Correo no válido.';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu contraseña.';
    if (v.length < 8) return 'Mínimo 8 caracteres.';
    return null;
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logoSize = (MediaQuery.of(context).size.height * 0.13).clamp(72.0, 100.0);
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(40),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/logo_csjb.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Clínica San Juan Bautista',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Red San Pablo',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
