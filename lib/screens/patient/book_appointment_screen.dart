import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'booking_confirmation_screen.dart';

class BookAppointmentScreen extends StatefulWidget {
  final Doctor doctor;
  const BookAppointmentScreen({super.key, required this.doctor});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  late final List<DateTime> _dates;
  late DateTime _date;
  late final List<Slot> _slots;
  Slot? _slot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final av = widget.doctor.availability;
    _slots = buildSlotsFromAvailability(av);
    _dates = List.generate(14, (i) => today.add(Duration(days: i)))
        .where((d) => isWorkingDay(d.weekday, av))
        .toList();
    _date = _dates.isNotEmpty ? _dates.first : today;
  }

  bool _isPast(Slot s) {
    final now = DateTime.now();
    final dt = DateTime(_date.year, _date.month, _date.day, s.hour, s.minute);
    return dt.isBefore(now);
  }

  Future<void> _confirm() async {
    if (_slot == null) return;
    setState(() => _busy = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final appt = await DB.book(
        doctor: widget.doctor,
        patientId: user.uid,
        patientName: user.displayName ?? 'Patient',
        date: isoDate(_date),
        slot: _slot!,
      );
      if (!mounted) return;
      // Show confirmation immediately and clear the booking screens from the
      // back stack, so Back returns to the home screen.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(appointment: appt)),
        (r) => r.isFirst,
      );
    } on SlotTakenException {
      if (mounted) {
        setState(() {
          _busy = false;
          _slot = null;
        });
        showMsg(context, 'Sorry, that slot was just booked. Please pick another.',
            error: true);
      }
    } on DoctorUnavailableException {
      if (mounted) {
        setState(() {
          _busy = false;
          _slot = null;
        });
        showMsg(context,
            'The doctor is not available at that time. Please pick another.',
            error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, AuthService.message(e), error: true);
      }
    }
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kPrimary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: Centered(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    InitialsAvatar(d.name, radius: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(drName(d.name),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17)),
                          Text('${d.specialization} • ${d.hospital}',
                              style: TextStyle(color: Colors.grey.shade700)),
                          Text('${d.experienceYears}+ yrs experience',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text('₹${d.fee}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: kPrimary)),
                        Text('Consultation Fee',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Select Date'),
            if (_dates.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('This doctor has no working days set.'),
                ),
              )
            else
              SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final dt = _dates[i];
                  final sel = isoDate(dt) == isoDate(_date);
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      _date = dt;
                      _slot = null;
                    }),
                    child: Container(
                      width: 62,
                      decoration: BoxDecoration(
                        color: sel ? kPrimary : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: sel ? kPrimary : Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(weekdayShort(dt),
                              style: TextStyle(
                                  color: sel ? Colors.white : Colors.grey.shade700,
                                  fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('${dt.day}',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: sel ? Colors.white : Colors.black87)),
                          Text(monthShort(dt),
                              style: TextStyle(
                                  color: sel ? Colors.white : Colors.grey.shade700,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SectionTitle('Available Time Slots'),
            if (_dates.isNotEmpty)
            StreamBuilder<Set<String>>(
              stream: DB.bookedSlotKeys(d.id, isoDate(_date)),
              builder: (context, snap) {
                final booked = snap.data ?? <String>{};
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _slots)
                      Builder(builder: (context) {
                        final taken =
                            booked.contains(makeSlotKey(d.id, isoDate(_date), s));
                        final disabled = taken || _isPast(s);
                        return ChoiceChip(
                          label: Text(s.label),
                          selected: _slot == s,
                          onSelected: disabled
                              ? null
                              : (_) => setState(() => _slot = s),
                          tooltip: taken ? 'Already booked' : null,
                        );
                      }),
                  ],
                );
              },
            ),
            const SectionTitle('Appointment Summary'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _summaryRow(Icons.calendar_today, 'Date', prettyDate(isoDate(_date))),
                    _summaryRow(Icons.access_time, 'Time', _slot?.label ?? 'Select a slot'),
                    _summaryRow(Icons.person, 'Doctor', drName(d.name)),
                    _summaryRow(Icons.payments_outlined, 'Consultation Fee', '₹${d.fee}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_slot == null || _busy) ? null : _confirm,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Confirm Appointment'),
            ),
          ],
        ),
      ),
    );
  }
}
