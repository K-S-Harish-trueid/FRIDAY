import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'joke_bank.dart';

enum CommandType {
  time,
  date,
  greeting,
  identity,
  battery,
  clear,
  newChat,
  preference,
  joke,
  help,
  camera,
  gallery,
  shutdown,
  unknown,
}

class CommandResult {
  final CommandType type;
  final String? message;
  final bool handled;

  const CommandResult({
    required this.type,
    this.message,
    required this.handled,
  });
}

const _slashHelpText = '''Slash commands:

• /new — Start a new mission (keeps old ones in the log)
• /clear — Wipe this conversation for good
• /preference — Show what's stored about you
• /help — Show this list

Plain commands still work too — try "help".''';

class FridayCommands {
  static final Battery _battery = Battery();
  static final Random _random = Random();

  static Future<CommandResult> handle(String input) async {
    final trimmed = input.trim();
    final lower = trimmed.toLowerCase();

    // ── Slash commands ─────────────────────────────────────────────────────
    if (lower.startsWith('/')) {
      return _handleSlash(lower.substring(1).trim());
    }

    bool hasWord(String word) => RegExp('\\b$word\\b').hasMatch(lower);

    if (lower == 'time' ||
        (hasWord('time') &&
            (lower.contains('what') ||
                lower.contains('current') ||
                lower.contains('now')))) {
      final now = DateTime.now();
      final h = now.hour.toString().padLeft(2, '0');
      final m = now.minute.toString().padLeft(2, '0');
      return CommandResult(
        type: CommandType.time,
        message: "It's $h:$m, boss.",
        handled: true,
      );
    }

    if (lower == 'date' ||
        (hasWord('date') &&
            (lower.contains('what') ||
                lower.contains('today') ||
                lower.contains('current'))) ||
        lower.contains('what day')) {
      final now = DateTime.now();
      const weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final weekday = weekdays[now.weekday - 1];
      final month = months[now.month - 1];
      return CommandResult(
        type: CommandType.date,
        message: "Today is $weekday, ${now.day} $month ${now.year}.",
        handled: true,
      );
    }

    if (_matches(lower, ['hey friday', 'hi friday']) ||
        lower == 'hi' ||
        lower == 'hey' ||
        lower == 'hello') {
      return CommandResult(
        type: CommandType.greeting,
        message: "Systems online. Ready when you are, boss.",
        handled: true,
      );
    }

    if (_matches(lower, ['who are you', 'introduce yourself', 'what are you'])) {
      return CommandResult(
        type: CommandType.identity,
        message:
            "F.R.I.D.A.Y — Female Replacement Intelligent Digital Assistant Youth. Built by Harish. How can I assist?",
        handled: true,
      );
    }

    if (_matches(lower, ['battery status', 'battery level', 'power level']) ||
        lower == 'battery') {
      try {
        final level = await _battery.batteryLevel;
        return CommandResult(
          type: CommandType.battery,
          message: "Device battery at $level%, boss.",
          handled: true,
        );
      } catch (_) {
        return CommandResult(
          type: CommandType.battery,
          message: "Battery sensors offline, boss. Can't get a reading.",
          handled: true,
        );
      }
    }

    if (_matches(lower, ['clear chat', 'clear history', 'reset chat']) ||
        lower == 'clear' ||
        lower == 'reset') {
      return CommandResult(
        type: CommandType.clear,
        message: "Memory wiped. Starting fresh.",
        handled: true,
      );
    }

    if (_matches(lower, ['tell me a joke', 'tell a joke', 'make me laugh']) ||
        lower == 'joke') {
      final joke = ironManJokes[_random.nextInt(ironManJokes.length)];
      return CommandResult(
        type: CommandType.joke,
        message: joke,
        handled: true,
      );
    }

    if (_matches(lower, ['what can you do', 'what do you do', 'show commands']) ||
        lower == 'help' ||
        lower == 'commands') {
      const helpText = '''Available commands:

• time — Current time
• date — Today's date
• battery — Device battery level
• hello / hi — Greeting
• who are you — Introduction
• joke — Random Iron Man joke
• clear / reset — Reset conversation
• camera — Open camera
• gallery — Open photo gallery
• help — Show this list
• shutdown / bye friday — Power down

$_slashHelpText

...and anything else, just ask.''';
      return CommandResult(
        type: CommandType.help,
        message: helpText,
        handled: true,
      );
    }

    if (_matches(lower, ['open camera', 'launch camera']) || lower == 'camera') {
      return CommandResult(
        type: CommandType.camera,
        message: "Launching optical sensors, boss.",
        handled: true,
      );
    }

    if (_matches(lower, ['open gallery', 'photo gallery', 'open photos']) ||
        lower == 'gallery' ||
        lower == 'photos') {
      return CommandResult(
        type: CommandType.gallery,
        message: "Opening media archive, boss.",
        handled: true,
      );
    }

    if (_matches(lower, ['bye friday', 'shut down', 'power off', 'goodbye friday']) ||
        lower == 'shutdown' ||
        lower == 'goodbye' ||
        lower == 'bye') {
      return CommandResult(
        type: CommandType.shutdown,
        message: "Powering down. Until next time, boss.",
        handled: true,
      );
    }

    return const CommandResult(type: CommandType.unknown, handled: false);
  }

  static Future<CommandResult> _handleSlash(String cmd) async {
    switch (cmd) {
      case 'new':
      case 'newchat':
      case 'new chat':
        return const CommandResult(
          type: CommandType.newChat,
          message: 'Starting a new mission, boss.',
          handled: true,
        );

      case 'clear':
      case 'reset':
        return const CommandResult(
          type: CommandType.clear,
          message: 'Memory wiped. Starting fresh.',
          handled: true,
        );

      case 'preference':
      case 'preferences':
      case 'prefs':
        final prefs = await SharedPreferences.getInstance();
        final provider = prefs.getString(providerPrefsKey) ?? defaultProvider;
        final message = '''Here's what I have stored about you, boss:

• Active provider: ${provider.toUpperCase()}

That's everything persisted on this device right now — I don't yet keep long-term memory of facts across conversations. Ask if you want that built.''';
        return CommandResult(
          type: CommandType.preference,
          message: message,
          handled: true,
        );

      case 'help':
        return const CommandResult(
          type: CommandType.help,
          message: _slashHelpText,
          handled: true,
        );

      default:
        return CommandResult(
          type: CommandType.unknown,
          message: 'Unknown command "/$cmd", boss. Try /help for the list.',
          handled: true,
        );
    }
  }

  static bool _matches(String input, List<String> patterns) {
    return patterns.any((p) => input.contains(p));
  }
}
