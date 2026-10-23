import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'book_appointment_screen.dart';
import 'doctor_profile_screen.dart';

class SearchDoctorsScreen extends StatefulWidget {
  const SearchDoctorsScreen({super.key});

  @override
  State<SearchDoctorsScreen> createState() => _SearchDoctorsScreenState();
}

class _SearchDoctorsScreenState extends State<SearchDoctorsScreen> {
  String _query = '';
  String _spec = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Doctors')),
      body: Centered(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search doctors, specialities, hospitals...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final s in ['All', ...kSpecializations])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _spec == s,
                        onSelected: (_) => setState(() => _spec = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Doctor>>(
                stream: DB.doctors(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const EmptyState(
                        icon: Icons.error_outline,
                        message: 'Could not load doctors.');
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data!.where((d) {
                    if (_spec != 'All' && d.specialization != _spec) {
                      return false;
                    }
                    if (_query.isEmpty) return true;
                    return d.name.toLowerCase().contains(_query) ||
                        d.specialization.toLowerCase().contains(_query) ||
                        d.hospital.toLowerCase().contains(_query);
                  }).toList();
                  if (list.isEmpty) {
                    return const EmptyState(
                        icon: Icons.search_off,
                        message: 'No doctors found.\nDoctors appear here after they register.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = list[i];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      DoctorProfileScreen(doctor: d))),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    InitialsAvatar(d.name, radius: 28),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(drName(d.name),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16)),
                                          Text(d.specialization,
                                              style: TextStyle(
                                                  color: Colors.grey.shade700)),
                                          Text(
                                              '${d.hospital} • ${d.experienceYears}+ yrs',
                                              style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12)),
                                          Row(
                                            children: [
                                              const Icon(Icons.star,
                                                  size: 15,
                                                  color: Colors.amber),
                                              Text(
                                                  ' ${d.rating} (${d.reviewCount} reviews)',
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text('₹${d.fee}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: kPrimary,
                                            fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(40)),
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              BookAppointmentScreen(
                                                  doctor: d))),
                                  child: const Text('Book Appointment'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
