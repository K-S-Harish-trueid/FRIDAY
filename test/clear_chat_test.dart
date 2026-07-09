import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:friday_assistant/commands/friday_commands.dart';
import 'package:friday_assistant/providers/chat_provider.dart';
import 'package:friday_assistant/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('FridayCommands recognizes "clear" as a clear command', () async {
    final result = await FridayCommands.handle('clear');
    expect(result.handled, isTrue);
    expect(result.type, CommandType.clear);
  });

  test('ChatNotifier.sendMessage("clear") empties messages and resets conversationId',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(chatProvider.notifier).sendMessage('hello');
    expect(container.read(chatProvider).messages, isNotEmpty);

    await container.read(chatProvider.notifier).sendMessage('clear');
    final state = container.read(chatProvider);
    expect(state.messages, hasLength(1));
    expect(state.messages.first.isCommand, isTrue);
    expect(state.conversationId, isNull);
  });

  testWidgets(
      'Settings "CLEAR CHAT HISTORY" button clears state and does not throw '
      '(Settings pushed on top of another screen, matching real app nav stack)',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(chatProvider.notifier).sendMessage('hello');
    expect(container.read(chatProvider).messages, isNotEmpty);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(find.text('CLEAR CHAT HISTORY'), findsOneWidget);
    await tester.tap(find.text('CLEAR CHAT HISTORY'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(chatProvider).messages, isEmpty);
  });
}
