import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:friday_assistant/providers/chat_provider.dart';
import 'package:friday_assistant/screens/chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // flutter_tts has no platform implementation in widget tests — without
    // a mock handler, calls to it just hang forever instead of failing
    // fast, which stalls anything that awaits TtsService. Give it a
    // same-as-real-plugin-shaped mock so the rest of the send flow can be
    // exercised normally.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (call) async => null);
  });

  testWidgets('typing a message and tapping send adds it to chat state',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
        find.byKey(const Key('chat_text_field')), 'hello there');
    await tester.pump();

    await tester.tap(find.byKey(const Key('chat_send_button')));
    // Local-command check + state update happen before the (failing, since
    // no real network in test env) backend call — one pump is enough to
    // observe the user message land in state.
    await tester.pump();

    final messages = container.read(chatProvider).messages;
    expect(messages, isNotEmpty);
    expect(messages.first.role, 'user');
    expect(messages.first.content, 'hello there');

    // Flush the one-shot send-pulse-reset timer before the test tears down.
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('send button does nothing while a message is already in flight',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
        find.byKey(const Key('chat_text_field')), 'first message');
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pump();

    // First send should have gone through and set isTyping while it waits
    // on the (failing) network call.
    expect(container.read(chatProvider).messages, isNotEmpty);

    // Text field should now be disabled — entering text is a no-op on a
    // disabled TextField, but tapping send again must not add a duplicate.
    final countBeforeSecondTap = container.read(chatProvider).messages.length;
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pump();
    expect(container.read(chatProvider).messages.length,
        countBeforeSecondTap);

    // Flush the one-shot send-pulse-reset timer before the test tears down.
    await tester.pump(const Duration(milliseconds: 300));
  });
}
