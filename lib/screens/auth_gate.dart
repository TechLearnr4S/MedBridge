import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../backend/fcm_service.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import 'doctor/doctor_home.dart';
import 'login_screen.dart';
import 'patient/patient_home.dart';

/// Decides what to show based on auth state:
///
/// 1. Not signed in -> LoginScreen
/// 2. Profile exists -> role-based home (patient / doctor)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }

        final user = snap.data;

        if (user == null) {
          // User just signed out -- remove FCM token
          if (_lastUid != null) {
            FcmService.removeToken(_lastUid!).catchError((_) {});
            _lastUid = null;
          }
          return const LoginScreen();
        }

        // New sign-in -- register FCM token
        if (_lastUid != user.uid) {
          _lastUid = user.uid;
          FcmService.registerToken(user.uid).catchError((_) {});
        }

        return _ProfileRouter(uid: user.uid);
      },
    );
  }
}

/// Routes to the correct home screen based on role.
class _ProfileRouter extends StatelessWidget {
  final String uid;
  const _ProfileRouter({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: DB.userStream(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return _Loading(
              message: AuthService.message(snap.error!), showLogout: true);
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const _Loading(
              message: 'Setting up your account...', showLogout: true);
        }

        final data = snap.data!.data() ?? <String, dynamic>{};
        final role = (data['role'] ?? 'patient').toString();
        final name = (data['name'] ?? '').toString();

        // Check if the user account is disabled.
        if (data['isEnabled'] == false) {
          return const _Loading(
            message:
                'Your account has been disabled. Please contact support.',
            showLogout: true,
          );
        }

        // Route to the correct home screen.
        if (role == 'doctor') {
          return DoctorHome(key: ValueKey(uid), uid: uid, name: name);
        }
        return PatientHome(key: ValueKey(uid), uid: uid, name: name);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  final String? message;
  final bool showLogout;
  const _Loading({this.message, this.showLogout = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(message!, textAlign: TextAlign.center),
              ),
            ],
            if (showLogout)
              TextButton(
                  onPressed: AuthService.logout, child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}
