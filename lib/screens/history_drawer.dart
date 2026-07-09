import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import '../services/backend_service.dart';

class HistoryDrawer extends ConsumerStatefulWidget {
  const HistoryDrawer({super.key});

  @override
  ConsumerState<HistoryDrawer> createState() => HistoryDrawerState();
}

// Public state class so ChatScreen can call refresh() via GlobalKey.
class HistoryDrawerState extends ConsumerState<HistoryDrawer> {
  Future<List<ConversationSummary>>? _future;
  bool _bulkDeleting = false;

  @override
  void initState() {
    super.initState();
    _future = BackendService.listConversations();
  }

  void refresh() {
    setState(() {
      _future = BackendService.listConversations();
    });
  }

  Future<void> _openConversation(ConversationSummary conv) async {
    try {
      final messages = await BackendService.getMessages(conv.id);
      if (!mounted) return;
      ref.read(chatProvider.notifier).loadConversation(conv.id, messages);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load mission, boss.',
              style: GoogleFonts.rajdhani(color: Colors.white)),
          backgroundColor: const Color(0xFF0f2035),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteConversation(String id) async {
    try {
      await BackendService.deleteConversation(id);
    } catch (_) {
      // Deletion already removed from UI via Dismissible; swallow errors.
    }
    // If we just deleted the conversation currently open in the chat view,
    // reset it — otherwise the next message would 404 against a dead id.
    if (ref.read(chatProvider).conversationId == id) {
      ref.read(chatProvider.notifier).newChat();
    }
    refresh();
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0f2035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFff6b35).withValues(alpha: 0.4)),
        ),
        title: Text(
          'DELETE ALL MISSIONS',
          style: GoogleFonts.orbitron(
            color: const Color(0xFFff6b35),
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
        content: Text(
          'This permanently deletes every conversation. This cannot be undone, boss.',
          style: GoogleFonts.rajdhani(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL',
                style: GoogleFonts.orbitron(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE ALL',
                style: GoogleFonts.orbitron(
                    color: const Color(0xFFff6b35), fontSize: 11)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _bulkDeleting = true);
    try {
      await BackendService.deleteAllConversations();
    } catch (_) {
      // best-effort; refresh() below shows whatever's left
    }
    // Every conversation is gone, including whichever one was active.
    ref.read(chatProvider.notifier).newChat();
    if (!mounted) return;
    setState(() => _bulkDeleting = false);
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0a0a1a),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0a0a1a),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF00d4ff).withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF00d4ff), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MISSION LOG',
                    style: GoogleFonts.orbitron(
                      color: const Color(0xFF00d4ff),
                      fontSize: 13,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _bulkDeleting ? null : _confirmDeleteAll,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _bulkDeleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFff6b35),
                            ),
                          )
                        : Icon(
                            Icons.delete_forever_outlined,
                            color: const Color(0xFFff6b35).withValues(alpha: 0.7),
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                ref.read(chatProvider.notifier).newChat();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF00d4ff).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF00d4ff).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: Color(0xFF00d4ff), size: 17),
                    const SizedBox(width: 7),
                    Text(
                      'NEW MISSION',
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF00d4ff),
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<ConversationSummary>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00d4ff),
              strokeWidth: 2,
            ),
          );
        }

        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_outlined,
                    color: Color(0xFFff6b35), size: 28),
                const SizedBox(height: 10),
                Text(
                  'Comms error, boss.',
                  style: GoogleFonts.rajdhani(
                    color: const Color(0xFFff6b35),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: refresh,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color:
                              const Color(0xFF00d4ff).withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'RETRY',
                      style: GoogleFonts.orbitron(
                          color: const Color(0xFF00d4ff),
                          fontSize: 10,
                          letterSpacing: 2),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final conversations = snap.data ?? [];

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    color: const Color(0xFF00d4ff).withValues(alpha: 0.25),
                    size: 32),
                const SizedBox(height: 12),
                Text(
                  'No missions logged yet.',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => refresh(),
          color: const Color(0xFF00d4ff),
          backgroundColor: const Color(0xFF0f2035),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            itemCount: conversations.length,
            itemBuilder: (_, i) {
              final conv = conversations[i];
              return _ConvTile(
                conv: conv,
                onTap: () => _openConversation(conv),
                onDelete: () => _deleteConversation(conv.id),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Conversation tile with swipe-to-delete + explicit delete icon ────────────

class _ConvTile extends StatelessWidget {
  final ConversationSummary conv;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConvTile({
    required this.conv,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        color: const Color(0xFFff6b35).withValues(alpha: 0.12),
        child: const Icon(Icons.delete_outline,
            color: Color(0xFFff6b35), size: 20),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFF00d4ff).withValues(alpha: 0.07),
        highlightColor: const Color(0xFF00d4ff).withValues(alpha: 0.04),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF00d4ff).withValues(alpha: 0.07),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: const Color(0xFF00d4ff).withValues(alpha: 0.45),
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.title,
                      style: GoogleFonts.rajdhani(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(conv.updatedAt),
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFF00d4ff).withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline,
                    color: const Color(0xFFff6b35).withValues(alpha: 0.55),
                    size: 17,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inHours < 24 && now.day == dt.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }
    if (diff.inDays == 1 ||
        (diff.inHours < 48 && now.day != dt.day)) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
