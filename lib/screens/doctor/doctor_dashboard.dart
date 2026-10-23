import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'patient_details_screen.dart';

class DoctorDashboard extends StatelessWidget {
  final String uid;
  final String name;
  final ValueChanged<int> onSwitchTab;
  const DoctorDashboard({
    super.key,
    required this.uid,
    required this.name,
    required this.onSwitchTab,
  });

  Widget _stat(IconData icon, String value, String label, VoidCallback onTap) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: kPrimary),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _complete(BuildContext context, Appointment a) async {
    try {
      await DB.changeStatus(a, 'completed');
      if (context.mounted) showMsg(context, 'Marked as completed');
    } catch (e) {
      if (context.mounted) showMsg(context, AuthService.message(e), error: true);
    }
  }

  void _openPatient(BuildContext context, Appointment a) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PatientDetailsScreen(
            patientId: a.patientId, patientName: a.patientName)));
  }

  @override
  Widget build(BuildContext context) {
    return Centered(
      child: StreamBuilder<List<Appointment>>(
        stream: DB.doctorAppointments(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(
                icon: Icons.error_outline,
                message: 'Could not load appointments.');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final today = isoDate(DateTime.now());
          final pending = all.where((a) => a.status == 'pending').toList();
          final accepted = all.where((a) => a.status == 'accepted').toList();
          final todays = accepted.where((a) => a.date.compareTo(today) <= 0).toList();
          final upcoming = accepted.where((a) => a.date.compareTo(today) > 0).toList();
          final patients = all.map((a) => a.patientId).toSet().length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Hello, ${drName(name)} 👋',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Here is your day at a glance.',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _stat(Icons.inbox, '${pending.length}', 'Pending\nrequests',
                      () => onSwitchTab(1)),
                  const SizedBox(width: 10),
                  _stat(Icons.today, '${todays.length}', "Today's\nappointments",
                      () {}),
                  const SizedBox(width: 10),
                  _stat(Icons.people, '$patients', 'Patients', () => onSwitchTab(2)),
                ],
              ),
              const SectionTitle("Today's Appointments"),
              if (todays.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No accepted appointments due today.'),
                  ),
                ),
              for (final a in todays)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppointmentCard(
                    a: a,
                    showPatient: true,
                    onTap: () => _openPatient(context, a),
                    actions: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 38)),
                        onPressed: () => _complete(context, a),
                        icon: const Icon(Icons.done, size: 18),
                        label: const Text('Mark completed'),
                      ),
                      OutlinedButton.icon(
                        style:
                            OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                        onPressed: () => _openPatient(context, a),
                        icon: const Icon(Icons.person, size: 18),
                        label: const Text('Patient details'),
                      ),
                    ],
                  ),
                ),
              if (upcoming.isNotEmpty) ...[
                const SectionTitle('Upcoming (accepted)'),
                for (final a in upcoming.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppointmentCard(
                      a: a,
                      showPatient: true,
                      onTap: () => _openPatient(context, a),
                      actions: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 38)),
                          onPressed: () => _complete(context, a),
                          icon: const Icon(Icons.done, size: 18),
                          label: const Text('Mark completed'),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
