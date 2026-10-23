import 'package:flutter/material.dart';

import '../backend/admin_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Overview'),
            Tab(icon: Icon(Icons.verified_user), text: 'Verify Doctors'),
            Tab(icon: Icon(Icons.people), text: 'All Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OverviewTab(),
          _VerifyDoctorsTab(),
          _AllUsersTab(),
        ],
      ),
    );
  }
}

// Overview

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: AdminService.getStats(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.red)));
        }
        final s = snap.data!;
        return Centered(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle('Platform Stats'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard('Total Patients', s.totalPatients,
                      Icons.person, Colors.blue),
                  _StatCard('Total Doctors', s.totalDoctors,
                      Icons.medical_services, kPrimary),
                  _StatCard('Pending Appointments', s.pendingAppointments,
                      Icons.pending_actions, Colors.orange),
                  _StatCard('Completed', s.completedAppointments,
                      Icons.check_circle, Colors.green),
                ],
              ),
              if (s.unverifiedDoctors > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber,
                        color: Colors.orange),
                    title: Text(
                        '${s.unverifiedDoctors} doctor(s) pending verification'),
                    subtitle: const Text('Go to Verify Doctors tab'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {},
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text('$value',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// Verify Doctors

class _VerifyDoctorsTab extends StatelessWidget {
  const _VerifyDoctorsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AdminService.pendingDoctorsStream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_user,
            message: 'All doctors are verified!',
          );
        }
        return Centered(
          maxWidth: 600,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              return Card(
                child: ListTile(
                  leading: InitialsAvatar('${d['name'] ?? '?'}', radius: 24),
                  title: Text('Dr. ${d['name'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${d['specialization'] ?? ''} - ${d['hospital'] ?? ''}'
                      '\nReg: ${d['medicalRegNo'] ?? 'N/A'}'),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () async {
                      try {
                        await AdminService.setDoctorVerified(id, verified: true);
                        if (context.mounted) {
                          showMsg(context, 'Doctor verified!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showMsg(context, 'Error: $e', error: true);
                        }
                      }
                    },
                    child: const Text('Verify'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// All Users

class _AllUsersTab extends StatefulWidget {
  const _AllUsersTab();

  @override
  State<_AllUsersTab> createState() => _AllUsersTabState();
}

class _AllUsersTabState extends State<_AllUsersTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Centered(
      maxWidth: 600,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: AdminService.allUsersStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data!.docs;
                if (_search.isNotEmpty) {
                  docs = docs
                      .where((d) =>
                          '${d.data()['name']}'.toLowerCase().contains(_search) ||
                          '${d.data()['email']}'.toLowerCase().contains(_search))
                      .toList();
                }
                if (docs.isEmpty) {
                  return const EmptyState(
                      icon: Icons.people_outline,
                      message: 'No users found.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = docs[i].data();
                    final uid = docs[i].id;
                    final enabled = u['isEnabled'] != false;
                    final role = '${u['role'] ?? 'patient'}';
                    return ListTile(
                      leading: InitialsAvatar('${u['name'] ?? '?'}', radius: 20),
                      title: Text('${u['name'] ?? ''}'),
                      subtitle: Text(
                          '${u['email'] ?? ''}  -  $role',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Switch(
                        value: enabled,
                        activeThumbColor: kPrimary,
                        onChanged: (val) async {
                          try {
                            await AdminService.setUserEnabled(uid, enabled: val);
                          } catch (e) {
                            if (context.mounted) {
                              showMsg(context, 'Error: $e', error: true);
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}