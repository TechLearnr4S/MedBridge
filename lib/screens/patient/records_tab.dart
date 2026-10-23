import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../add_record_screen.dart';
import '../prescriptions_screen.dart';
import '../record_view_screen.dart';

class RecordsTab extends StatelessWidget {
  final String uid;
  final String name;
  const RecordsTab({super.key, required this.uid, required this.name});

  Future<void> _delete(BuildContext context, String id) async {
    final yes = await confirmDialog(
        context, 'Delete record', 'This record will be permanently deleted.',
        yes: 'Delete');
    if (!yes) return;
    try {
      await DB.deleteRecord(id);
      if (context.mounted) showMsg(context, 'Record deleted');
    } catch (e) {
      if (context.mounted) showMsg(context, AuthService.message(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AddRecordScreen(
                patientId: uid, patientName: name, byDoctor: false))),
        icon: const Icon(Icons.add),
        label: const Text('Add record'),
      ),
      body: Centered(
        child: StreamBuilder<List<Snap>>(
          stream: DB.records(uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  icon: Icons.error_outline,
                  message: 'Could not load records.');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.medication, color: kPrimary),
                    title: const Text('Digital Prescriptions',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Prescriptions issued by your doctors'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PrescriptionsScreen(patientId: uid))),
                  ),
                ),
                const SectionTitle('My Records'),
                if (items.isEmpty)
                  const EmptyState(
                      icon: Icons.folder_open,
                      message:
                          'No records yet.\nTap "Add record" to upload a report or note.'),
                for (final r in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kPrimary.withValues(alpha: 0.12),
                          child: Icon(
                              r.data()['type'] == 'image'
                                  ? Icons.image
                                  : Icons.description,
                              color: kPrimary),
                        ),
                        title: Text('${r.data()['title']}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${tsText(r.data())}\nAdded by ${r.data()['byDoctor'] == true ? drName('${r.data()['addedByName']}') : 'you'}'),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    RecordViewScreen(data: r.data()))),
                        trailing: r.data()['addedBy'] == uid
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(context, r.id),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
