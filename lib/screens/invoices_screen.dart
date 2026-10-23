import 'package:flutter/material.dart';

import '../backend/invoice_service.dart';
import '../constants.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class InvoicesScreen extends StatelessWidget {
  final String uid;
  final String role; // 'patient' or 'doctor'
  const InvoicesScreen({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Invoices')),
      body: Centered(
        child: StreamBuilder<List<Invoice>>(
          stream: InvoiceService.myInvoices(uid, role),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final invoices = snap.data!;
            if (invoices.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No invoices yet.\nThey appear after appointments are completed.',
              );
            }

            // Summary row for doctors
            double total = 0;
            double paid = 0;
            if (role == 'doctor') {
              for (final inv in invoices) {
                total += inv.amount;
                if (inv.status == 'paid') paid += inv.amount;
              }
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (role == 'doctor') ...[
                  _SummaryCard(total: total, paid: paid),
                  const SizedBox(height: 8),
                ],
                ...invoices.map((inv) => _InvoiceCard(
                      invoice: inv,
                      isDoctor: role == 'doctor',
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double total;
  final double paid;
  const _SummaryCard({required this.total, required this.paid});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kPrimary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                  label: 'Total Billed',
                  value: '\u20b9${total.toInt()}',
                  light: true),
            ),
            const VerticalDivider(color: Colors.white38, width: 32),
            Expanded(
              child: _Stat(
                  label: 'Paid',
                  value: '\u20b9${paid.toInt()}',
                  light: true),
            ),
            const VerticalDivider(color: Colors.white38, width: 32),
            Expanded(
              child: _Stat(
                  label: 'Unpaid',
                  value: '\u20b9${(total - paid).toInt()}',
                  light: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool light;
  const _Stat(
      {required this.label, required this.value, this.light = false});

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(fontSize: 12, color: light ? Colors.white70 : Colors.grey)),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final bool isDoctor;
  const _InvoiceCard({required this.invoice, required this.isDoctor});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (invoice.status) {
      'paid' => Colors.green,
      'refunded' => Colors.orange,
      _ => Colors.red,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: kPrimary.withValues(alpha: 0.12),
                  child: const Icon(Icons.receipt_long, color: kPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDoctor
                            ? invoice.patientName
                            : 'Dr. ${invoice.doctorName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(invoice.specialization,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    invoice.status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _InfoRow(Icons.calendar_today, invoice.date)),
                Expanded(
                    child: _InfoRow(Icons.access_time, invoice.timeSlot)),
              ],
            ),
            const SizedBox(height: 4),
            _InfoRow(Icons.local_hospital_outlined, invoice.hospital),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('\u20b9${invoice.amount}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kPrimary)),
                if (invoice.status == 'unpaid' && !isDoctor)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await InvoiceService.markPaid(invoice.id);
                      if (context.mounted)
                        showMsg(context, 'Marked as paid');
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark Paid'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 36)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Flexible(
              child: Text(text,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
        ],
      );
}