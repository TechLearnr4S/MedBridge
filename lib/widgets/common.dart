import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import '../theme.dart';

void showMsg(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? Colors.red.shade700 : null,
    behavior: SnackBarBehavior.floating,
  ));
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String yes = 'Yes'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}

/// Centers content with a maximum width so the UI looks good on the web.
class Centered extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const Centered({super.key, required this.child, this.maxWidth = 900});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const InitialsAvatar(this.name, {super.key, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    var initials = '';
    for (final p in parts) {
      if (p.isEmpty || p.toLowerCase() == 'dr.' || p.toLowerCase() == 'dr') {
        continue;
      }
      initials += p[0].toUpperCase();
      if (initials.length == 2) break;
    }
    if (initials.isEmpty) initials = '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: kPrimary.withValues(alpha: 0.12),
      child: Text(initials,
          style: TextStyle(
              color: kPrimary,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.7)),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'accepted':
        c = Colors.green.shade700;
        break;
      case 'completed':
        c = Colors.blue.shade700;
        break;
      case 'rejected':
        c = Colors.red.shade700;
        break;
      case 'cancelled':
        c = Colors.grey.shade700;
        break;
      default:
        c = Colors.orange.shade800;
    }
    final label = status.isEmpty
        ? ''
        : status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Appointment a;
  final bool showPatient;
  final List<Widget> actions;
  final VoidCallback? onTap;
  const AppointmentCard({
    super.key,
    required this.a,
    this.showPatient = false,
    this.actions = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = showPatient ? a.patientName : drName(a.doctorName);
    final subtitle =
        showPatient ? 'Patient' : '${a.specialization} • ${a.hospital}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(title),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(subtitle,
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  StatusChip(a.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: kPrimary),
                  const SizedBox(width: 6),
                  Text(prettyDate(a.date)),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: kPrimary),
                  const SizedBox(width: 6),
                  Text(a.timeSlot),
                  const Spacer(),
                  Text('₹${a.fee}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

/// Bottom navigation bar on phones, side navigation rail on wide screens.
/// Back button returns to the first tab before leaving the app.
class AdaptiveScaffold extends StatelessWidget {
  final String title;
  final int index;
  final ValueChanged<int> onSelect;
  final List<NavItem> items;
  final List<Widget> pages;
  final List<Widget> actions;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.index,
    required this.onSelect,
    required this.items,
    required this.pages,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    final body = IndexedStack(index: index, children: pages);
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onSelect(0);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: onSelect,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final i in items)
                        NavigationRailDestination(
                            icon: Icon(i.icon), label: Text(i.label)),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                destinations: [
                  for (final i in items)
                    NavigationDestination(icon: Icon(i.icon), label: i.label),
                ],
              ),
      ),
    );
  }
}
