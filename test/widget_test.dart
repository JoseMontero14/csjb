import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:csjb/main.dart';

void main() {
  testWidgets('App arranca y muestra LoginView', (tester) async {
    await tester.pumpWidget(const CsjbApp());
    await tester.pumpAndSettle();

    // La ruta inicial es /login → el stub muestra su AppBar
    expect(find.text('LoginView'), findsOneWidget);
  });

  testWidgets('Theme usa Material 3 con color primary correcto', (tester) async {
    await tester.pumpWidget(const CsjbApp());
    await tester.pumpAndSettle();

    // Se lee el tema desde el Scaffold de la ruta, no desde MaterialApp,
    // porque M3 procesa colores en el subtree del navigator.
    final context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, const Color(0xFF5B2D8E));
    expect(theme.colorScheme.secondary, const Color(0xFFF47920));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAF8));
  });
}
