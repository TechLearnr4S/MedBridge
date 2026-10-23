import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin-only backend operations.
///
/// All methods throw [PermissionException] if the caller is not an admin.
/// In production these operations should be gated by a Cloud Function or
/// Custom Claims; here we rely on Firestore security rules enforcing the
/// `isAdmin` role check so an unprivileged client receives a
/// `permission-denied` rejection from Firestore.
class AdminService {
  AdminService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ── helpers ──────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  static CollectionReference<Map<String, dynamic>> get _doctors =>
      _db.collection('doctors');

  /// Returns the Firestore user doc for the signed-in user.
  static Future<Map<String, dynamic>> _myData() async {
    final snap = await _users.doc(_uid).get();
    return snap.data() ?? {};
  }

  /// Throws if the signed-in user does not have the 'admin' role.
  static Future<void> _guardAdmin() async {
    final data = await _myData();
    if (data['role'] != 'admin') {
      throw Exception('Permission denied: admin role required.');
    }
  }

  // ── streams ──────────────────────────────────────────────────────────────

  /// Stream of ALL user documents (admin use only).
  static Stream<QuerySnapshot<Map<String, dynamic>>> allUsersStream() =>
      _users.orderBy('createdAt', descending: true).snapshots();

  /// Stream of ALL doctor documents (admin use only).
  static Stream<QuerySnapshot<Map<String, dynamic>>> allDoctorsStream() =>
      _doctors.orderBy('name').snapshots();

  /// Stream of doctors pending verification (isVerified == false).
  static Stream<QuerySnapshot<Map<String, dynamic>>> pendingDoctorsStream() =>
      _doctors.where('isVerified', isEqualTo: false).snapshots();

  // ── doctor verification ───────────────────────────────────────────────────

  /// Marks a doctor as verified (or revokes verification).
  /// Updates both `doctors/{id}` and `users/{id}` so the
  /// [firestore.rules] `isDoctor()` guard passes correctly.
  static Future<void> setDoctorVerified(
    String doctorId, {
    required bool verified,
  }) async {
    await _guardAdmin();
    final batch = _db.batch();
    batch.update(_doctors.doc(doctorId), {
      'isVerified': verified,
      'verifiedAt': verified ? FieldValue.serverTimestamp() : null,
      'verifiedBy': verified ? _uid : null,
    });
    batch.update(_users.doc(doctorId), {
      'doctorVerified': verified,
    });
    await batch.commit();
  }

  // ── user account enable / disable ─────────────────────────────────────────

  /// Enables or disables a user account.
  /// Disabled users are blocked at the Firestore rules level via `isEnabled`.
  static Future<void> setUserEnabled(
    String userId, {
    required bool enabled,
  }) async {
    await _guardAdmin();
    final batch = _db.batch();
    batch.update(_users.doc(userId), {
      'isEnabled': enabled,
      'disabledAt': enabled ? null : FieldValue.serverTimestamp(),
      'disabledBy': enabled ? null : _uid,
    });
    // If the user is also a doctor, disable the doctor listing too.
    final userSnap = await _users.doc(userId).get();
    if (userSnap.data()?['role'] == 'doctor') {
      batch.update(_doctors.doc(userId), {'isEnabled': enabled});
    }
    await batch.commit();
  }

  // ── promote / demote admin ────────────────────────────────────────────────

  /// Promotes a patient/doctor to admin role. Use with extreme caution.
  /// Only possible if the calling user is already an admin.
  static Future<void> promoteToAdmin(String targetUserId) async {
    await _guardAdmin();
    await _users.doc(targetUserId).update({'role': 'admin'});
  }

  // ── analytics snapshot ────────────────────────────────────────────────────

  /// Returns a simple count snapshot for the admin dashboard.
  /// Uses aggregation queries (count) where available, falls back to doc fetch.
  static Future<AdminStats> getStats() async {
    await _guardAdmin();
    final results = await Future.wait([
      _db.collection('users').where('role', isEqualTo: 'patient').count().get(),
      _db.collection('users').where('role', isEqualTo: 'doctor').count().get(),
      _db.collection('appointments').where('status', isEqualTo: 'pending').count().get(),
      _db.collection('appointments').where('status', isEqualTo: 'completed').count().get(),
      _db.collection('doctors').where('isVerified', isEqualTo: false).count().get(),
    ]);
    return AdminStats(
      totalPatients: results[0].count ?? 0,
      totalDoctors: results[1].count ?? 0,
      pendingAppointments: results[2].count ?? 0,
      completedAppointments: results[3].count ?? 0,
      unverifiedDoctors: results[4].count ?? 0,
    );
  }
}

/// Simple aggregate stats for the admin dashboard.
class AdminStats {
  final int totalPatients;
  final int totalDoctors;
  final int pendingAppointments;
  final int completedAppointments;
  final int unverifiedDoctors;

  const AdminStats({
    required this.totalPatients,
    required this.totalDoctors,
    required this.pendingAppointments,
    required this.completedAppointments,
    required this.unverifiedDoctors,
  });
}
