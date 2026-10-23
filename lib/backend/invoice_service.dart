import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

/// Manages the `invoices` Firestore collection.
///
/// An invoice is automatically generated when an appointment is marked
/// `completed`. It can then be marked `paid` by the patient or admin.
/// The collection schema mirrors the Firestore rules already in place.
class InvoiceService {
  InvoiceService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('invoices');

  // â”€â”€ create â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Generates an invoice document when [appointment] is completed.
  /// Should be called right after [DB.changeStatus(a, 'completed')].
  static Future<Invoice> generateForAppointment(Appointment appointment) async {
    final ref = _col.doc();
    final invoice = Invoice(
      id: ref.id,
      appointmentId: appointment.id,
      patientId: appointment.patientId,
      doctorId: appointment.doctorId,
      patientName: appointment.patientName,
      doctorName: appointment.doctorName,
      specialization: appointment.specialization,
      hospital: appointment.hospital,
      date: appointment.date,
      timeSlot: appointment.timeSlot,
      amount: appointment.fee,
      status: 'unpaid',
    );
    await ref.set({
      ...invoice.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return invoice;
  }

  // â”€â”€ reads / streams â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Stream of all invoices for a patient, newest first.
  static Stream<List<Invoice>> patientInvoices(String patientId) =>
      _col.where('patientId', isEqualTo: patientId).snapshots().map(
            (s) => _sorted(s.docs.map(Invoice.fromDoc).toList()),
          );

  /// Stream of all invoices for a doctor, newest first.
  static Stream<List<Invoice>> doctorInvoices(String doctorId) =>
      _col.where('doctorId', isEqualTo: doctorId).snapshots().map(
            (s) => _sorted(s.docs.map(Invoice.fromDoc).toList()),
          );

  /// Stream of invoices for the currently signed-in user.
  /// Automatically resolves role from Firebase Auth custom claims fallback.
  static Stream<List<Invoice>> myInvoices(String uid, String role) =>
      role == 'doctor' ? doctorInvoices(uid) : patientInvoices(uid);

  /// Returns a single [Invoice] by document ID.
  static Future<Invoice?> getById(String invoiceId) async {
    final snap = await _col.doc(invoiceId).get();
    if (!snap.exists) return null;
    return Invoice.fromDoc(snap);
  }

  // â”€â”€ update â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Marks an invoice as paid and records who confirmed it.
  static Future<void> markPaid(String invoiceId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _col.doc(invoiceId).update({
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'paidConfirmedBy': uid,
    });
  }

  /// Marks an invoice as refunded (e.g. after cancellation).
  static Future<void> markRefunded(String invoiceId) async {
    await _col.doc(invoiceId).update({
      'status': 'refunded',
      'refundedAt': FieldValue.serverTimestamp(),
    });
  }

  // â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static List<Invoice> _sorted(List<Invoice> list) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Returns unpaid invoices count for a patient (useful for badge display).
  static Stream<int> unpaidCount(String patientId) =>
      _col
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'unpaid')
          .snapshots()
          .map((s) => s.docs.length);
}
