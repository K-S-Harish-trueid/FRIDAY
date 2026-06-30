import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/chat_provider.dart';
import '../config.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0a1a),
        elevation: 0,
        title: Text(
          'SETTINGS',
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00d4ff),
            fontSize: 17,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00d4ff)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFF00d4ff).withValues(alpha: 0.2),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel('AI PROVIDER'),
          const SizedBox(height: 10),
          _providerToggle(ref, chatState.activeProvider),
          const SizedBox(height: 28),
          _sectionLabel('API KEY STATUS'),
          const SizedBox(height: 10),
          _keyStatus('GROQ', groqApiKey),
          const SizedBox(height: 8),
          _keyStatus('GEMINI', geminiApiKey),
          const SizedBox(height: 28),
          _sectionLabel('ACTIONS'),
          const SizedBox(height: 10),
          _actionTile(
            label: 'CLEAR CHAT HISTORY',
            icon: Icons.delete_sweep_outlined,
            color: const Color(0xFFff6b35),
            onTap: () {
              ref.read(chatProvider.notifier).clearChat();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Memory wiped, boss.',
                      style: GoogleFonts.rajdhani(color: Colors.white)),
                  backgroundColor: const Color(0xFF0f2035),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.orbitron(
          color: const Color(0xFF00d4ff).withValues(alpha: 0.6),
          fontSize: 10,
          letterSpacing: 3,
        ),
      );

  Widget _providerToggle(WidgetRef ref, String active) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0f2035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00d4ff).withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _providerChip(ref, 'groq', 'GROQ', active),
          _providerChip(ref, 'gemini', 'GEMINI', active),
        ],
      ),
    );
  }

  Widget _providerChip(
      WidgetRef ref, String value, String label, String active) {
    final on = active == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(chatProvider.notifier).changeProvider(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: on
                ? const Color(0xFF00d4ff).withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: on
                ? Border.all(color: const Color(0xFF00d4ff), width: 1.2)
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              color: on
                  ? const Color(0xFF00d4ff)
                  : Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyStatus(String provider, String key) {
    final configured = key.isNotEmpty &&
        key != 'YOUR_GROQ_API_KEY' &&
        key != 'YOUR_GEMINI_API_KEY';
    final display = configured
        ? '${key.substring(0, min(6, key.length))}••••••••${key.length > 4 ? key.substring(key.length - 4) : ''}'
        : 'Not configured';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0f2035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: configured
              ? const Color(0xFF00ff88).withValues(alpha: 0.28)
              : const Color(0xFFff6b35).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            configured ? Icons.check_circle_outline : Icons.error_outline,
            color: configured
                ? const Color(0xFF00ff88)
                : const Color(0xFFff6b35),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider,
                    style: GoogleFonts.orbitron(
                        color: const Color(0xFF00d4ff),
                        fontSize: 11,
                        letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(display,
                    style: GoogleFonts.rajdhani(
                        color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.orbitron(
                    color: color, fontSize: 12, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;
}
