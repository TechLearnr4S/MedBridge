import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/db_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PrescriptionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const PrescriptionCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final meds = (data['medicines'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, color: kPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(drName('${data['doctorName'] ?? ''}'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Text(tsText(data),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const Divider(height: 20),
            for (final m in meds)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(
                      child: Text(
                          '${(m as Map)['name']}  —  ${m['dosage']}  (${m['duration']})'),
                    ),
                  ],
                ),
              ),
            if ('${data['instructions'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Instructions: ${data['instructions']}',
                  style: TextStyle(color: Colors.grey.shade800)),
            ],
          ],
        ),
      ),
    );
  }
}

class PrescriptionsScreen extends StatelessWidget {
  final String patientId;
  const PrescriptionsScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Prescriptions')),
      body: Centered(
        child: StreamBuilder<List<Snap>>(
          stream: DB.prescriptions(patientId),
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  icon: Icons.error_outline,
                  message: 'Could not load prescriptions.');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return const EmptyState(
                  icon: Icons.medication_outlined,
                  message: 'No prescriptions yet.\nYour doctor will add them after a visit.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => PrescriptionCard(data: items[i].data()),
            );
          },
        ),
      ),
    );
  }
}
