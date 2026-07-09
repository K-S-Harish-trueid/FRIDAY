import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../providers/chat_provider.dart';
import '../config.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _sectionLabel('BACKEND'),
          const SizedBox(height: 10),
          _backendStatus(),
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

  // All LLM calls (Groq primary, Gemini fallback) happen server-side —
  // this card just reports whether the backend is reachable.
  Widget _backendStatus() {
    return FutureBuilder<bool>(
      future: _pingBackend(),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final ok = snap.data == true;
        final color = loading
            ? const Color(0xFF00d4ff)
            : ok
                ? const Color(0xFF00ff88)
                : const Color(0xFFff6b35);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0f2035),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(
                      ok ? Icons.check_circle_outline : Icons.error_outline,
                      color: color,
                      size: 18,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FASTAPI BACKEND',
                        style: GoogleFonts.orbitron(
                            color: const Color(0xFF00d4ff),
                            fontSize: 11,
                            letterSpacing: 2)),
                    const SizedBox(height: 2),
                    Text(backendBaseUrl,
                        style: GoogleFonts.rajdhani(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      loading
                          ? 'Checking…'
                          : ok
                              ? 'Connected'
                              : 'Unreachable',
                      style: GoogleFonts.rajdhani(
                          color: color.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _pingBackend() async {
    try {
      final response = await http
          .get(Uri.parse('$backendBaseUrl/health'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['status'] == 'ok';
    } catch (_) {
      return false;
    }
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
}
