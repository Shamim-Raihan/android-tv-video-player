import 'package:flutter_test/flutter_test.dart';
import 'package:android_tv_video_player/main.dart';

void main() {
  testWidgets('TvVideoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TvVideoApp());
    expect(find.byType(TvVideoApp), findsOneWidget);
  });
}
