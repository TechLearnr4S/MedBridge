import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AvailabilityEditorScreen extends StatefulWidget {
  final Doctor doctor;
  const AvailabilityEditorScreen({super.key, required this.doctor});

  @override
  State<AvailabilityEditorScreen> createState() =>
      _AvailabilityEditorScreenState();
}

class _AvailabilityEditorScreenState extends State<AvailabilityEditorScreen> {
  late int _startHour;
  late int _endHour;
  late int _lunchStart;
  late int _lunchEnd;
  late int _slotMinutes;
  late Set<String> _workDays;
  bool _saving = false;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _slotOptions = [15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    final av = widget.doctor.availability;
    _startHour    = (av['startHour']   as num?)?.toInt() ?? 9;
    _endHour      = (av['endHour']     as num?)?.toInt() ?? 17;
    _lunchStart   = (av['lunchStart']  as num?)?.toInt() ?? 13;
    _lunchEnd     = (av['lunchEnd']    as num?)?.toInt() ?? 14;
    _slotMinutes  = (av['slotMinutes'] as num?)?.toInt() ?? 30;
    final rawDays = av['workDays'];
    _workDays = rawDays is List
        ? Set<String>.from(rawDays.map((e) => e.toString()))
        : {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  }

  List<String> get _preview {
    final slots = <String>[];
    var hour = _startHour;
    var minute = 0;
    while (true) {
      final totalMins = hour * 60 + minute;
      if (totalMins + _slotMinutes > _endHour * 60) break;
      // skip lunch
      final lunchStartMins = _lunchStart * 60;
      final lunchEndMins   = _lunchEnd   * 60;
      if (totalMins >= lunchStartMins && totalMins < lunchEndMins) {
        hour   = _lunchEnd;
        minute = 0;
        continue;
      }
      final h = hour % 12 == 0 ? 12 : hour % 12;
      final m = minute.toString().padLeft(2, '0');
      final ap = hour < 12 ? 'AM' : 'PM';
      slots.add('$h:$m $ap');
      minute += _slotMinutes;
      hour   += minute ~/ 60;
      minute  = minute % 60;
    }
    return slots;
  }

  Future<void> _save() async {
    if (_workDays.isEmpty) {
      showMsg(context, 'Select at least one working day', error: true);
      return;
    }
    if (_startHour >= _endHour) {
      showMsg(context, 'End hour must be after start hour', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await DB.updateAvailability(widget.doctor.id, {
        'startHour':   _startHour,
        'endHour':     _endHour,
        'lunchStart':  _lunchStart,
        'lunchEnd':    _lunchEnd,
        'slotMinutes': _slotMinutes,
        'workDays':    _workDays.toList(),
      });
      if (mounted) {
        showMsg(context, 'Availability saved!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showMsg(context, 'Error: $e', error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final slots = _preview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Availability'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Centered(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Working days
            _Section(
              title: 'Working Days',
              child: Wrap(
                spacing: 8,
                children: _days.map((d) {
                  final on = _workDays.contains(d);
                  return FilterChip(
                    label: Text(d),
                    selected: on,
                    onSelected: (_) => setState(() =>
                        on ? _workDays.remove(d) : _workDays.add(d)),
                    selectedColor: kPrimary,
                    labelStyle: TextStyle(
                        color: on ? Colors.white : null,
                        fontWeight: on ? FontWeight.w600 : null),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Hours
            _Section(
              title: 'Clinic Hours',
              child: Column(
                children: [
                  _HourPicker(
                    label: 'Start time',
                    value: _startHour,
                    onChanged: (v) => setState(() => _startHour = v),
                  ),
                  const SizedBox(height: 8),
                  _HourPicker(
                    label: 'End time',
                    value: _endHour,
                    onChanged: (v) => setState(() => _endHour = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lunch break
            _Section(
              title: 'Lunch Break',
              child: Column(
                children: [
                  _HourPicker(
                    label: 'Lunch start',
                    value: _lunchStart,
                    onChanged: (v) => setState(() => _lunchStart = v),
                  ),
                  const SizedBox(height: 8),
                  _HourPicker(
                    label: 'Lunch end',
                    value: _lunchEnd,
                    onChanged: (v) => setState(() => _lunchEnd = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Slot duration
            _Section(
              title: 'Appointment Duration',
              child: DropdownButtonFormField<int>(
                value: _slotMinutes,
                decoration:
                    const InputDecoration(labelText: 'Minutes per slot'),
                items: _slotOptions
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text('$m minutes')))
                    .toList(),
                onChanged: (v) => setState(() => _slotMinutes = v!),
              ),
            ),
            const SizedBox(height: 16),

            // Preview
            _Section(
              title: 'Preview (${slots.length} slots)',
              child: slots.isEmpty
                  ? const Text('No slots — check your settings.',
                      style: TextStyle(color: Colors.red))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: slots
                          .map((s) => Chip(
                                label: Text(s,
                                    style: const TextStyle(fontSize: 12)),
                                backgroundColor:
                                    kPrimary.withValues(alpha: 0.08),
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          child,
        ],
      );
}

class _HourPicker extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _HourPicker(
      {required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hours =
        List.generate(24, (i) => i); // 0-23
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: hours.map((h) {
        final disp = h == 0
            ? '12:00 AM'
            : h < 12
                ? '$h:00 AM'
                : h == 12
                    ? '12:00 PM'
                    : '${h - 12}:00 PM';
        return DropdownMenuItem(value: h, child: Text(disp));
      }).toList(),
      onChanged: (v) => onChanged(v!),
    );
  }
}