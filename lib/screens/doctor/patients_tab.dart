import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/db_service.dart';
import '../../widgets/common.dart';
import 'patient_details_screen.dart';

class PatientsTab extends StatelessWidget {
  final String uid;
  const PatientsTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Centered(
      child: StreamBuilder<List<Appointment>>(
        stream: DB.doctorAppointments(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(
                icon: Icons.error_outline, message: 'Could not load patients.');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // One entry per patient with the number of visits.
          final names = <String, String>{};
          final counts = <String, int>{};
          for (final a in snap.data!) {
            if (a.status == 'rejected' || a.status == 'cancelled') continue;
            names[a.patientId] = a.patientName;
            counts[a.patientId] = (counts[a.patientId] ?? 0) + 1;
          }
          final ids = names.keys.toList()
            ..sort((x, y) => names[x]!.compareTo(names[y]!));
          if (ids.isEmpty) {
            return const EmptyState(
                icon: Icons.people_outline,
                message: 'No patients yet.\nPatients appear after they book with you.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final id = ids[i];
              return Card(
                child: ListTile(
                  leading: InitialsAvatar(names[id]!),
                  title: Text(names[id]!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${counts[id]} appointment(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PatientDetailsScreen(
                          patientId: id, patientName: names[id]!))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
