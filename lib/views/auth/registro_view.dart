import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/auth_controller.dart';
import '../../models/usuario_model.dart';
import '../../utils/routes.dart';
import '../../utils/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class RegistroView extends StatefulWidget {
  const RegistroView({super.key});

  @override
  State<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<RegistroView> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _controller = AuthController();

  Sexo _sexo = Sexo.prefierNoDecir;
  DateTime? _fechaNacimiento;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(now.year - 18),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5),
      locale: const Locale('es'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.onPrimary,
                surface: AppColors.surface,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaNacimiento = picked);
  }

  Future<void> _registro() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaNacimiento == null) {
      _showError('Selecciona tu fecha de nacimiento.');
      return;
    }
    final ok = await _controller.registro(
      nombre: _nombreCtrl.text,
      correo: _correoCtrl.text,
      contrasena: _passwordCtrl.text,
      sexo: _sexo,
      fechaNacimiento: _fechaNacimiento!,
    );
    if (!mounted) return;
    if (ok) {
      AppRoutes.pushAndRemoveAll(context, AppRoutes.dashboard);
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
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => AppRoutes.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos personales', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    AppInput(
                      controller: _nombreCtrl,
                      label: 'Nombre completo',
                      hint: 'Ej. Ana García',
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Ingresa tu nombre.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppInput(
                      controller: _correoCtrl,
                      label: 'Correo electrónico',
                      hint: 'ejemplo@correo.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: _validateCorreo,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Contraseña', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    AppInput(
                      controller: _passwordCtrl,
                      label: 'Contraseña',
                      hint: 'Mínimo 8 caracteres',
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppInput(
                      controller: _confirmCtrl,
                      label: 'Confirmar contraseña',
                      hint: 'Repite tu contraseña',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(Icons.lock_outline),
                      validator: (v) => v != _passwordCtrl.text
                          ? 'Las contraseñas no coinciden.'
                          : null,
                      onSubmitted: (_) => _registro(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Información adicional', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),

                    // Fecha de nacimiento
                    _FechaNacimientoField(
                      fecha: _fechaNacimiento,
                      onTap: _pickFecha,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Sexo
                    Text(
                      'Sexo',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SexoSelector(
                      selected: _sexo,
                      onChanged: (s) => setState(() => _sexo = s),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Crear cuenta',
                      onPressed: _controller.isLoading ? null : _registro,
                      loading: _controller.isLoading,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed: () => AppRoutes.pop(context),
                        child: Text(
                          '¿Ya tienes cuenta? Inicia sesión',
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
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

class _FechaNacimientoField extends StatelessWidget {
  const _FechaNacimientoField({required this.fecha, required this.onTap});

  final DateTime? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final formatted = fecha != null
        ? DateFormat('dd / MM / yyyy').format(fecha!)
        : 'Seleccionar fecha';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgBr,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha de nacimiento',
          prefixIcon: Icon(Icons.calendar_today_outlined),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          formatted,
          style: textTheme.bodyMedium?.copyWith(
            color: fecha != null ? AppColors.textPrimary : AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}

class _SexoSelector extends StatelessWidget {
  const _SexoSelector({required this.selected, required this.onChanged});

  final Sexo selected;
  final void Function(Sexo) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: Sexo.values.map((s) {
        final isSelected = s == selected;
        return ChoiceChip(
          label: Text(s.label),
          selected: isSelected,
          onSelected: (_) => onChanged(s),
          selectedColor: AppColors.accent,
          backgroundColor: AppColors.surfaceVariant,
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected ? AppColors.onAccent : AppColors.textPrimary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBr),
          side: BorderSide.none,
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
