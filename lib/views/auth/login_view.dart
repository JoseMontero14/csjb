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
      AppRoutes.pushAndRemoveAll(context, AppRoutes.dashboard);
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

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    _Logo(),
                    const SizedBox(height: AppSpacing.xl),
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
                    const SizedBox(height: AppSpacing.lg),
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
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xlBr,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_hospital_rounded,
        color: AppColors.onPrimary,
        size: 44,
      ),
    );
  }
}
