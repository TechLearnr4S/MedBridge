import 'package:flutter/material.dart';

import '../backend/chat_service.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends StatelessWidget {
  final String uid;
  final String name;
  const ChatInboxScreen({super.key, required this.uid, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Centered(
        child: StreamBuilder<List<ChatThread>>(
          stream: ChatService.myThreads(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load conversations.\n${snap.error}',
                      textAlign: TextAlign.center),
                ),
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final threads = snap.data ?? [];
            if (threads.isEmpty) {
              return const EmptyState(
                icon: Icons.chat_bubble_outline,
                message: 'No conversations yet.\nStart a chat from a doctor or patient profile.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final thread = threads[i];
                final otherId =
                    thread.participants.firstWhere((p) => p != uid, orElse: () => '');
                final otherName =
                    thread.participantNames[otherId] ?? 'Unknown';
                final unread = thread.unreadCountFor(uid);
                final time = _timeLabel(thread.lastTimestamp);

                return ListTile(
                  leading: Stack(
                    children: [
                      InitialsAvatar(otherName, radius: 24),
                      if (unread > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                                color: kPrimary, shape: BoxShape.circle),
                            child: Center(
                              child: Text('$unread',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(otherName,
                      style: TextStyle(
                          fontWeight: unread > 0
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  subtitle: Text(
                    thread.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight:
                            unread > 0 ? FontWeight.w600 : FontWeight.normal,
                        color: unread > 0 ? null : Colors.grey),
                  ),
                  trailing: Text(time,
                      style: TextStyle(
                          fontSize: 12,
                          color: unread > 0 ? kPrimary : Colors.grey)),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        otherId: otherId,
                        otherIsDoctor: thread.doctorId == otherId,
                        otherName: otherName,
                        myId: uid,
                        myName: name,
                      ),
                    ));
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}