import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../widgets/common.dart';

class RequestsTab extends StatelessWidget {
  final String uid;
  const RequestsTab({super.key, required this.uid});

  Future<void> _decide(
      BuildContext context, Appointment a, String status) async {
    if (status == 'rejected') {
      final yes = await confirmDialog(context, 'Reject request',
          'Reject ${a.patientName}\'s request for ${prettyDate(a.date)} at ${a.timeSlot}? The patient will be notified.',
          yes: 'Reject');
      if (!yes) return;
    }
    try {
      await DB.changeStatus(a, status);
      if (context.mounted) {
        showMsg(context,
            status == 'accepted' ? 'Appointment accepted' : 'Request rejected');
      }
    } catch (e) {
      if (context.mounted) showMsg(context, AuthService.message(e), error: true);
    }
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
                message: 'Could not load requests.');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pending =
              snap.data!.where((a) => a.status == 'pending').toList();
          if (pending.isEmpty) {
            return const EmptyState(
                icon: Icons.inbox_outlined,
                message: 'No pending requests.\nNew bookings will appear here.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = pending[i];
              return AppointmentCard(
                a: a,
                showPatient: true,
                actions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38)),
                    onPressed: () => _decide(context, a, 'accepted'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        foregroundColor: Colors.red.shade700),
                    onPressed: () => _decide(context, a, 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
