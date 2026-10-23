import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class PatientAppointmentsTab extends StatefulWidget {
  final String uid;
  const PatientAppointmentsTab({super.key, required this.uid});

  @override
  State<PatientAppointmentsTab> createState() => _PatientAppointmentsTabState();
}

class _PatientAppointmentsTabState extends State<PatientAppointmentsTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Future<void> _cancel(BuildContext context, Appointment a) async {
    final yes = await confirmDialog(context, 'Cancel appointment',
        'Cancel your appointment with ${drName(a.doctorName)} on ${prettyDate(a.date)} at ${a.timeSlot}?',
        yes: 'Cancel it');
    if (!yes) return;
    try {
      await DB.changeStatus(a, 'cancelled');
      if (context.mounted) showMsg(context, 'Appointment cancelled');
    } catch (e) {
      if (context.mounted) {
        showMsg(context, AuthService.message(e), error: true);
      }
    }
  }

  Widget _appointmentList(
      List<Appointment> items, String emptyMsg, bool cancellable) {
    if (items.isEmpty) {
      return EmptyState(icon: Icons.event_busy, message: emptyMsg);
    }
    return Centered(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final a = items[i];
          return AppointmentCard(
            a: a,
            actions: cancellable
                ? [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          foregroundColor: Colors.red.shade700),
                      onPressed: () => _cancel(context, a),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                    ),
                  ]
                : const [],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: kPrimary,
            indicatorColor: kPrimary,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Appointment>>(
              stream: DB.patientAppointments(widget.uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const EmptyState(
                      icon: Icons.error_outline,
                      message: 'Could not load appointments.');
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;

                // Build event map for the calendar (active appointments).
                final events = <DateTime, List<Appointment>>{};
                for (final a in all) {
                  final parts = a.date.split('-');
                  if (parts.length == 3) {
                    final dt = DateTime(int.parse(parts[0]),
                        int.parse(parts[1]), int.parse(parts[2]));
                    events.putIfAbsent(dt, () => []).add(a);
                  }
                }

                List<Appointment> getEventsForDay(DateTime day) {
                  return events[DateTime(day.year, day.month, day.day)] ?? [];
                }

                // Filter appointments for the selected day
                final selectedDayAppointments = _selectedDay != null
                    ? getEventsForDay(_selectedDay!)
                        .where((a) => a.isActive)
                        .toList()
                    : <Appointment>[];

                return TabBarView(
                  children: [
                    // Upcoming tab with calendar
                    Column(
                      children: [
                        // Calendar
                        TableCalendar<Appointment>(
                          firstDay: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDay:
                              DateTime.now().add(const Duration(days: 365)),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() => _calendarFormat = format);
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          eventLoader: getEventsForDay,
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: kPrimary,
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            markerSize: 6,
                            markersMaxCount: 3,
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonShowsNext: false,
                            titleCentered: true,
                          ),
                        ),
                        // Selected day appointments
                        if (_selectedDay != null &&
                            selectedDayAppointments.isNotEmpty)
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: selectedDayAppointments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final a = selectedDayAppointments[i];
                                return AppointmentCard(
                                  a: a,
                                  actions: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 38),
                                          foregroundColor:
                                              Colors.red.shade700),
                                      onPressed: () => _cancel(context, a),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Cancel'),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        else if (_selectedDay != null)
                          Expanded(
                            child: Center(
                              child: Text(
                                'No appointments on ${prettyDate(isoDate(_selectedDay!))}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: _appointmentList(
                              all
                                  .where((a) => a.isActive)
                                  .toList(),
                              'No upcoming appointments.\nGo to Home and book one.',
                              true,
                            ),
                          ),
                      ],
                    ),
                    _appointmentList(
                        all
                            .where((a) => a.status == 'completed')
                            .toList(),
                        'No completed appointments yet.',
                        false),
                    _appointmentList(
                        all
                            .where((a) => a.isCancelledOrRejected)
                            .toList(),
                        'No cancelled appointments.',
                        false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
