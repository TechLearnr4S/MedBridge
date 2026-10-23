import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

/// Handles Firebase Auth operations and Firestore user profile management.
class AuthService {
  AuthService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Sign in with email and password.
  static Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  /// Creates the Firebase Auth user, sends email verification,
  /// and creates the Firestore profile documents.
  static Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    required String gender,
    required DateTime dob,
    String specialization = '',
    String hospital = '',
    int experienceYears = 0,
    int fee = 0,
    String medicalRegNo = '',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    final user = cred.user!;
    try {
      await user.updateDisplayName(name.trim());

      // Send email verification immediately after registration.
      await user.sendEmailVerification();

      await _db.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': role,
        'gender': gender,
        'dob': dob.toIso8601String(),
        'emailVerified': false,
        'phoneVerified': false,
        'isEnabled': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (role == 'doctor') {
        await _db.collection('doctors').doc(user.uid).set({
          'name': name.trim(),
          'specialization': specialization,
          'hospital': hospital.trim(),
          'experienceYears': experienceYears,
          'fee': fee,
          'rating': 0.0,
          'reviewCount': 0,
          'about':
              '$specialization with $experienceYears years of experience at ${hospital.trim()}.',
          'medicalRegNo': medicalRegNo,
          'isVerified': false,
          'isEnabled': true,
          'availability': {
            'startHour': 9,
            'endHour': 17,
            'slotMinutes': 30,
            'lunchHour': 13,
            'workingDays': [1, 2, 3, 4, 5, 6], // Mon-Sat
          },
        });
      }
    } catch (e) {
      // Roll back so the user can try again with the same email.
      try {
        await user.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Send a password reset email.
  static Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Resend email verification.
  static Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Update user profile fields.
  static Future<void> updateProfile(
      String uid, String role, String name, String phone) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({'name': name.trim(), 'phone': phone.trim()});
    if (role == 'doctor') {
      await _db.collection('doctors').doc(uid).update({'name': name.trim()});
    }
    await _auth.currentUser?.updateDisplayName(name.trim());
  }

  /// Mark email as verified in Firestore.
  static Future<void> markEmailVerified(String uid) async {
    await _db.collection('users').doc(uid).update({'emailVerified': true});
  }

  /// Mark phone as verified in Firestore.
  static Future<void> markPhoneVerified(String uid) async {
    await _db.collection('users').doc(uid).update({'phoneVerified': true});
  }

  /// Change password (requires re-authentication).
  static Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Not signed in');
    final cred = EmailAuthProvider.credential(
        email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  /// Sign out and stop notifications.
  static Future<void> logout() async {
    NotificationService.stop();
    await _auth.signOut();
  }

  /// Converts Firebase errors to short, user-friendly messages.
  static String message(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'user-disabled':
          return 'This account has been disabled by an administrator.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'weak-password':
          return 'Password is too weak. Use at least 8 characters with uppercase, lowercase, digit and special character.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'invalid-verification-code':
          return 'Invalid OTP code. Please check and try again.';
        case 'session-expired':
          return 'OTP session expired. Please request a new code.';
        case 'credential-already-in-use':
          return 'This phone number is already used by another account.';
        case 'invalid-phone-number':
          return 'Invalid phone number format. Use E.164 format (e.g. +919876543210).';
        default:
          return e.message ?? 'Authentication failed (${e.code}).';
      }
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Permission denied. Your email may not be verified, or check Firestore security rules.';
      }
      return e.message ?? 'Something went wrong (${e.code}).';
    }
    return 'Something went wrong. Please try again.';
  }
}
