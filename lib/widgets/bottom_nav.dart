import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Barra de navegación inferior flotante con indicador animado (Material 3).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.xxlBr,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D6B48FF),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.xxlBr,
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onTap,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              indicatorColor: AppColors.primaryLightBg,
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              animationDuration: AppDuration.normal,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.health_and_safety_outlined),
                  selectedIcon: Icon(Icons.health_and_safety_rounded),
                  label: 'Triaje',
                ),
                NavigationDestination(
                  icon: Icon(Icons.science_outlined),
                  selectedIcon: Icon(Icons.science_rounded),
                  label: 'Exámenes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.medical_services_outlined),
                  selectedIcon: Icon(Icons.medical_services_rounded),
                  label: 'Médicos',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
