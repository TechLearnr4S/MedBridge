import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Used by patients (upload own record) and doctors (add diagnosis / note).
/// Images are stored as small base64 strings inside Firestore, so the app
/// works on the free Spark plan without Firebase Storage.
class AddRecordScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final bool byDoctor;
  const AddRecordScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.byDoctor,
  });

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  Uint8List? _image;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1000, imageQuality: 60);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 600 * 1024) {
        if (mounted) {
          showMsg(context, 'Image is too large. Choose a smaller image.',
              error: true);
        }
        return;
      }
      setState(() => _image = bytes);
    } catch (_) {
      if (mounted) showMsg(context, 'Could not open the image picker.', error: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_notes.text.trim().isEmpty && _image == null) {
      showMsg(context, 'Add notes or attach an image.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await DB.addRecord(
        patientId: widget.patientId,
        title: _title.text,
        notes: _notes.text,
        addedBy: DB.uid,
        addedByName: DB.myName,
        byDoctor: widget.byDoctor,
        imageBase64: _image == null ? null : base64Encode(_image!),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
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
      appBar: AppBar(
          title: Text(widget.byDoctor ? 'Add Diagnosis / Record' : 'Add Medical Record')),
      body: Centered(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.byDoctor)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Patient: ${widget.patientName}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(
                        labelText: widget.byDoctor
                            ? 'Diagnosis / title'
                            : 'Title (e.g. Blood Test Report)'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notes,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        labelText: 'Notes / details',
                        alignLabelWithHint: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.attach_file),
              label: Text(_image == null ? 'Attach image (optional)' : 'Change image'),
            ),
            if (_image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_image!, height: 200, fit: BoxFit.cover),
              ),
              TextButton(
                  onPressed: () => setState(() => _image = null),
                  child: const Text('Remove image')),
            ],
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
                  : const Text('Save record'),
            ),
          ],
        ),
      ),
    );
  }
}
