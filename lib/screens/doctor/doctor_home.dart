import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/db_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';
import '../chat_inbox_screen.dart';
import '../invoices_screen.dart';
import '../notifications_screen.dart';
import '../profile_tab.dart';
import 'availability_editor_screen.dart';
import 'doctor_dashboard.dart';
import 'patients_tab.dart';
import 'requests_tab.dart';

class DoctorHome extends StatefulWidget {
  final String uid;
  final String name;
  const DoctorHome({super.key, required this.uid, required this.name});

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  int _index = 0;

  static const _titles = [
    'Doctor Dashboard',
    'Appointment Requests',
    'My Patients',
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

  Future<void> _openAvailability() async {
    final snap = await DB.col('doctors').doc(widget.uid).get();
    if (!mounted) return;
    if (!snap.exists) {
      showMsg(context, 'Doctor profile not found', error: true);
      return;
    }
    final doctor = Doctor.fromDoc(snap);
    _openScreen(AvailabilityEditorScreen(doctor: doctor));
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: _titles[_index],
      index: _index,
      onSelect: (i) => setState(() => _index = i),
      actions: [
        // Chat inbox
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
        // Availability editor
        IconButton(
          tooltip: 'Set Availability',
          icon: const Icon(Icons.schedule_outlined),
          onPressed: _openAvailability,
        ),
        // Invoices
        IconButton(
          tooltip: 'Invoices',
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () =>
              _openScreen(InvoicesScreen(uid: widget.uid, role: 'doctor')),
        ),
        NotificationBell(uid: widget.uid),
      ],
      items: const [
        NavItem(Icons.dashboard_outlined, 'Dashboard'),
        NavItem(Icons.inbox_outlined, 'Requests'),
        NavItem(Icons.people_outline, 'Patients'),
        NavItem(Icons.person_outline, 'Profile'),
      ],
      pages: [
        DoctorDashboard(
          uid: widget.uid,
          name: widget.name,
          onSwitchTab: (i) => setState(() => _index = i),
        ),
        RequestsTab(uid: widget.uid),
        PatientsTab(uid: widget.uid),
        ProfileTab(uid: widget.uid),
      ],
    );
  }
}