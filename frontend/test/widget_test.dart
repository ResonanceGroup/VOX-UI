import 'package:flutter_test/flutter_test.dart';
import 'package:vox_ui/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const VoxUIApp());
    expect(find.text('VoxUI'), findsOneWidget);
  });
}
