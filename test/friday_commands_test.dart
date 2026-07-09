import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:friday_assistant/commands/friday_commands.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('loose date/time phrasing', () {
    test('"whats todays date" is recognized (no apostrophe, no exact phrase)',
        () async {
      final result = await FridayCommands.handle('whats todays date');
      expect(result.handled, isTrue);
      expect(result.type, CommandType.date);
    });

    test('"whats the time" is recognized', () async {
      final result = await FridayCommands.handle('whats the time');
      expect(result.handled, isTrue);
      expect(result.type, CommandType.time);
    });

    test('unrelated text containing "date" as a substring is not misfired',
        () async {
      final result = await FridayCommands.handle('update the app please');
      expect(result.type, isNot(CommandType.date));
    });
  });

  group('slash commands', () {
    test('/new starts a new chat', () async {
      final result = await FridayCommands.handle('/new');
      expect(result.handled, isTrue);
      expect(result.type, CommandType.newChat);
    });

    test('/clear maps to the clear command', () async {
      final result = await FridayCommands.handle('/clear');
      expect(result.handled, isTrue);
      expect(result.type, CommandType.clear);
    });

    test('/preference reports the stored provider', () async {
      SharedPreferences.setMockInitialValues({'active_provider': 'own'});
      final result = await FridayCommands.handle('/preference');
      expect(result.handled, isTrue);
      expect(result.type, CommandType.preference);
      expect(result.message, contains('OWN'));
    });

    test('/help returns the slash command list', () async {
      final result = await FridayCommands.handle('/help');
      expect(result.handled, isTrue);
      expect(result.message, contains('/preference'));
    });

    test('unknown slash command is handled locally with a hint, not sent on',
        () async {
      final result = await FridayCommands.handle('/frobnicate');
      expect(result.handled, isTrue);
      expect(result.type, CommandType.unknown);
      expect(result.message, contains('/help'));
    });
  });
}
