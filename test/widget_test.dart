import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/main.dart';

void main() {
  testWidgets('apresenta a tela de entrada do V.I.T.A.', (tester) async {
    await tester.pumpWidget(const VitaApp());
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo ao V.I.T.A.'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
