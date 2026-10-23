import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Appointment appointment;
  const BookingConfirmationScreen({super.key, required this.appointment});

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Confirmation')),
      body: Centered(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),
            const Icon(Icons.check_circle, size: 88, color: Colors.green),
            const SizedBox(height: 10),
            const Text('Appointment Booked!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
                'Your request has been sent to ${drName(a.doctorName)}. You will be notified when it is accepted.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Booking ID', a.id),
                    _row('Doctor', drName(a.doctorName)),
                    _row('Speciality', a.specialization),
                    _row('Hospital', a.hospital),
                    _row('Date', prettyDate(a.date)),
                    _row('Time', a.timeSlot),
                    _row('Fee', '₹${a.fee}'),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 110,
                              child: Text('Status',
                                  style:
                                      TextStyle(color: Colors.grey.shade600))),
                          StatusChip(a.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
