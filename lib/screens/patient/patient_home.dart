import 'package:flutter/material.dart';

import '../../services/db_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';
import '../chat_inbox_screen.dart';
import '../invoices_screen.dart';
import '../notifications_screen.dart';
import '../profile_tab.dart';
import 'appointments_tab.dart';
import 'dashboard_tab.dart';
import 'records_tab.dart';

class PatientHome extends StatefulWidget {
  final String uid;
  final String name;
  const PatientHome({super.key, required this.uid, required this.name});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  int _index = 0;

  static const _titles = [
    'MedBridge',
    'My Appointments',
    'Medical Records',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.start(widget.uid);
  }

  @override
  void dispose() {
    NotificationService.stop();
    super.dispose();
  }

  void _openScreen(Widget screen) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: _titles[_index],
      index: _index,
      onSelect: (i) => setState(() => _index = i),
      actions: [
        // Chat inbox icon with unread badge
        StreamBuilder<int>(
          stream: DB.chatUnreadCount(widget.uid),
          builder: (context, snap) {
            final unread = snap.data ?? 0;
            return IconButton(
              tooltip: 'Messages',
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              onPressed: () => _openScreen(
                  ChatInboxScreen(uid: widget.uid, name: widget.name)),
            );
          },
        ),
        // Invoices
        IconButton(
          tooltip: 'Invoices',
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () =>
              _openScreen(InvoicesScreen(uid: widget.uid, role: 'patient')),
        ),
        NotificationBell(uid: widget.uid),
      ],
      items: const [
        NavItem(Icons.home_outlined, 'Home'),
        NavItem(Icons.calendar_month_outlined, 'Appointments'),
        NavItem(Icons.folder_outlined, 'Records'),
        NavItem(Icons.person_outline, 'Profile'),
      ],
      pages: [
        PatientDashboard(
          uid: widget.uid,
          name: widget.name,
          onSwitchTab: (i) => setState(() => _index = i),
        ),
        PatientAppointmentsTab(uid: widget.uid),
        RecordsTab(uid: widget.uid, name: widget.name),
        ProfileTab(uid: widget.uid),
      ],
    );
  }
}