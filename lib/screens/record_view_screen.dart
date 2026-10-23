import 'dart:convert';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../widgets/common.dart';

class RecordViewScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const RecordViewScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final b64 = data['imageBase64'];
    final byDoctor = data['byDoctor'] == true;
    final by = '${data['addedByName'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: Text('${data['title'] ?? 'Record'}')),
      body: Centered(
        maxWidth: 700,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${data['title'] ?? ''}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
                '${tsText(data)} • Added by ${byDoctor ? drName(by) : by}',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            if ('${data['notes'] ?? ''}'.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${data['notes']}',
                      style: const TextStyle(fontSize: 16, height: 1.4)),
                ),
              ),
            if (b64 is String && b64.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: Image.memory(base64Decode(b64), fit: BoxFit.contain),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
