import 'package:flutter_test/flutter_test.dart';
import 'package:martverdi_mobile/main.dart';

// Testa se o aplicativo MartVerdi inicia corretamente.
void main() {
  testWidgets('Deve exibir a tela inicial do MartVerdi', (WidgetTester tester) async {
    // Inicializa o aplicativo para realizar o teste.
    await tester.pumpWidget(const MartVerdiApp());

    // Verifica se o nome MartVerdi aparece na tela.
    expect(find.text('MartVerdi'), findsOneWidget);

    // Verifica se o título da tela inicial aparece.
    expect(find.text('MartVerdi Mobile!'), findsOneWidget);
  });
}