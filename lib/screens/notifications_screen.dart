import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/db_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

IconData _iconFor(String type) {
  switch (type) {
    case 'booking':
      return Icons.event_available;
    case 'request':
      return Icons.inbox;
    case 'record':
      return Icons.folder_shared;
    case 'prescription':
      return Icons.medication;
    default:
      return Icons.notifications;
  }
}

class NotificationBell extends StatelessWidget {
  final String uid;
  const NotificationBell({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Snap>>(
      stream: DB.notifications(uid),
      builder: (context, snap) {
        final unread =
            (snap.data ?? []).where((d) => d.data()['read'] != true).length;
        return IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsScreen(uid: uid))),
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  final String uid;
  const NotificationsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Snap>>(
      stream: DB.notifications(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              TextButton(
                onPressed: items.isEmpty ? null : () => DB.markAllRead(items),
                child: const Text('Mark all read',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: Centered(
            child: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const EmptyState(
                        icon: Icons.notifications_none,
                        message: 'No notifications yet.')
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final m = items[i].data();
                          final unread = m['read'] != true;
                          return Card(
                            child: ListTile(
                              onTap: () => DB.markRead(items[i].id),
                              leading: CircleAvatar(
                                backgroundColor:
                                    kPrimary.withValues(alpha: 0.12),
                                child: Icon(_iconFor('${m['type']}'),
                                    color: kPrimary),
                              ),
                              title: Text('${m['title'] ?? ''}',
                                  style: TextStyle(
                                      fontWeight: unread
                                          ? FontWeight.w800
                                          : FontWeight.w500)),
                              subtitle:
                                  Text('${m['body'] ?? ''}\n${tsText(m)}'),
                              isThreeLine: true,
                              trailing: unread
                                  ? const Icon(Icons.circle,
                                      size: 10, color: kPrimary)
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}
