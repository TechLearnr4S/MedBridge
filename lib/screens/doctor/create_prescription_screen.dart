import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class _MedRow {
  final name = TextEditingController();
  final dosage = TextEditingController();
  final duration = TextEditingController();

  void dispose() {
    name.dispose();
    dosage.dispose();
    duration.dispose();
  }
}

class CreatePrescriptionScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const CreatePrescriptionScreen(
      {super.key, required this.patientId, required this.patientName});

  @override
  State<CreatePrescriptionScreen> createState() =>
      _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends State<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_MedRow> _rows = [_MedRow()];
  final _instructions = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _instructions.dispose();
    super.dispose();
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DB.addPrescription(
        patientId: widget.patientId,
        patientName: widget.patientName,
        doctorId: DB.uid,
        doctorName: DB.myName,
        medicines: [
          for (final r in _rows)
            {
              'name': r.name.text.trim(),
              'dosage': r.dosage.text.trim(),
              'duration': r.duration.text.trim(),
            }
        ],
        instructions: _instructions.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showMsg(context, 'Prescription saved and sent to the patient');
    } catch (e) {
      if (mounted) {
        showMsg(context, AuthService.message(e), error: true);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Prescription')),
      body: Centered(
        maxWidth: 640,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Patient: ${widget.patientName}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SectionTitle('Medicines'),
              for (var i = 0; i < _rows.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Medicine ${i + 1}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (_rows.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() {
                                  _rows[i].dispose();
                                  _rows.removeAt(i);
                                }),
                              ),
                          ],
                        ),
                        TextFormField(
                          controller: _rows[i].name,
                          decoration:
                              const InputDecoration(labelText: 'Medicine name'),
                          validator: _req,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _rows[i].dosage,
                                decoration: const InputDecoration(
                                    labelText: 'Dosage',
                                    hintText: '1 tablet, 2x a day'),
                                validator: _req,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _rows[i].duration,
                                decoration: const InputDecoration(
                                    labelText: 'Duration',
                                    hintText: '5 days'),
                                validator: _req,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _rows.add(_MedRow())),
                icon: const Icon(Icons.add),
                label: const Text('Add another medicine'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _instructions,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Instructions / advice',
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Save & send prescription'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
