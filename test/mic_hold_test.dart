import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:friday_assistant/screens/chat_screen.dart';

const _permissionChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');
const _ttsChannel = MethodChannel('flutter_tts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, (call) async => null);
  });

  testWidgets(
      'holding the mic with a denied permission shows an error and does not '
      'get stuck showing "recording"', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, (call) async {
      if (call.method == 'requestPermissions') {
        final permissions = call.arguments as List;
        return {
          for (final p in permissions) p as int: PermissionStatus.denied.index
        };
      }
      if (call.method == 'checkPermissionStatus') {
        return PermissionStatus.denied.index;
      }
      return null;
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(find.byKey(const Key('chat_mic_button')));
    // Let the permission-request future and the resulting setState/SnackBar
    // resolve.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('permission'), findsOneWidget);
    // The mic icon should be back to its idle (not "mic", not "delete")
    // glyph once the permission failure is handled.
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
  });
}
