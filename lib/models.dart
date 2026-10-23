import 'package:cloud_firestore/cloud_firestore.dart';

// ── Primitive helpers ────────────────────────────────────────────────────────
String _s(Map<String, dynamic> m, String k) => (m[k] ?? '').toString();
int    _i(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt()    ?? 0;
double _d(Map<String, dynamic> m, String k) => (m[k] as num?)?.toDouble() ?? 0;
bool   _b(Map<String, dynamic> m, String k) => m[k] == true;

// ── Doctor ───────────────────────────────────────────────────────────────────

/// Represents a doctor's public profile.
class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String hospital;
  final String about;
  final int experienceYears;
  final int fee;
  final int reviewCount;
  final double rating;
  final bool isVerified;
  final bool isEnabled;
  final String medicalRegNo;
  final Map<String, dynamic> availability;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.hospital,
    required this.about,
    required this.experienceYears,
    required this.fee,
    required this.reviewCount,
    required this.rating,
    this.isVerified = false,
    this.isEnabled = true,
    this.medicalRegNo = '',
    this.availability = const {},
  });

  factory Doctor.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return Doctor(
      id: d.id,
      name: _s(m, 'name'),
      specialization: _s(m, 'specialization'),
      hospital: _s(m, 'hospital'),
      about: _s(m, 'about'),
      experienceYears: _i(m, 'experienceYears'),
      fee: _i(m, 'fee'),
      reviewCount: _i(m, 'reviewCount'),
      rating: _d(m, 'rating'),
      isVerified: _b(m, 'isVerified'),
      isEnabled: m['isEnabled'] != false,
      medicalRegNo: _s(m, 'medicalRegNo'),
      availability: (m['availability'] as Map<String, dynamic>?) ?? {},
    );
  }

  Doctor copyWith({double? rating, int? reviewCount}) => Doctor(
        id: id,
        name: name,
        specialization: specialization,
        hospital: hospital,
        about: about,
        experienceYears: experienceYears,
        fee: fee,
        reviewCount: reviewCount ?? this.reviewCount,
        rating: rating ?? this.rating,
        isVerified: isVerified,
        isEnabled: isEnabled,
        medicalRegNo: medicalRegNo,
        availability: availability,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'specialization': specialization,
        'hospital': hospital,
        'about': about,
        'experienceYears': experienceYears,
        'fee': fee,
        'reviewCount': reviewCount,
        'rating': rating,
        'isVerified': isVerified,
        'isEnabled': isEnabled,
        'medicalRegNo': medicalRegNo,
        'availability': availability,
      };
}

// ── DoctorSlot ───────────────────────────────────────────────────────────────

/// A single bookable time slot within a doctor's schedule.
class DoctorSlot {
  final String label;   // e.g. "09:00 AM"
  final String slotKey; // e.g. "2024-06-01_09:00 AM_doctorId"

  const DoctorSlot({required this.label, required this.slotKey});
}

// ── Appointment ──────────────────────────────────────────────────────────────

/// Represents a patient-doctor appointment.
class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String specialization;
  final String hospital;
  final String date;
  final String timeSlot;
  final String sortKey;
  final String slotKey;
  final int fee;
  final String status;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.hospital,
    required this.date,
    required this.timeSlot,
    required this.sortKey,
    required this.slotKey,
    required this.fee,
    required this.status,
  });

  /// True if appointment is still active (pending or accepted).
  bool get isActive => status == 'pending' || status == 'accepted';

  /// True if the appointment was cancelled or rejected.
  bool get isCancelledOrRejected =>
      status == 'cancelled' || status == 'rejected';

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return Appointment(
      id: d.id,
      patientId: _s(m, 'patientId'),
      patientName: _s(m, 'patientName'),
      doctorId: _s(m, 'doctorId'),
      doctorName: _s(m, 'doctorName'),
      specialization: _s(m, 'specialization'),
      hospital: _s(m, 'hospital'),
      date: _s(m, 'date'),
      timeSlot: _s(m, 'timeSlot'),
      sortKey: _s(m, 'sortKey'),
      slotKey: _s(m, 'slotKey'),
      fee: _i(m, 'fee'),
      status: _s(m, 'status'),
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'specialization': specialization,
        'hospital': hospital,
        'date': date,
        'timeSlot': timeSlot,
        'sortKey': sortKey,
        'slotKey': slotKey,
        'fee': fee,
        'status': status,
      };
}

// ── ChatMessage ──────────────────────────────────────────────────────────────

/// A single message inside `chats/{chatId}/messages/{msgId}`.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageBase64;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageBase64,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: d.id,
      senderId: _s(m, 'senderId'),
      senderName: _s(m, 'senderName'),
      text: _s(m, 'text'),
      imageBase64: m['imageBase64'] as String?,
      timestamp: m['timestamp'] is Timestamp
          ? (m['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: _b(m, 'isRead'),
    );
  }
}

// ── ChatThread ───────────────────────────────────────────────────────────────

/// Top-level `chats/{chatId}` document — used for the chat inbox list.
class ChatThread {
  final String id;
  final String lastMessage;
  final DateTime lastTimestamp;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String patientId;
  final String doctorId;

  /// Unread message counts keyed by user UID.
  final Map<String, int> unreadCounts;

  const ChatThread({
    required this.id,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.participants,
    required this.participantNames,
    required this.unreadCounts,
    this.patientId = '',
    this.doctorId = '',
  });

  int unreadCountFor(String uid) => unreadCounts[uid] ?? 0;

  factory ChatThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    final rawCounts = m['unreadCounts'];
    final counts = rawCounts is Map
        ? rawCounts
            .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
        : <String, int>{};
    final names =
        (m['participantNames'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            <String, String>{};
    return ChatThread(
      id: d.id,
      lastMessage: _s(m, 'lastMessage'),
      lastTimestamp: m['lastTimestamp'] is Timestamp
          ? (m['lastTimestamp'] as Timestamp).toDate()
          : DateTime.now(),
      participants: List<String>.from(m['participants'] ?? []),
      participantNames: names,
      unreadCounts: counts,
      patientId: _s(m, 'patientId'),
      doctorId: _s(m, 'doctorId'),
    );
  }
}

// ── Invoice ──────────────────────────────────────────────────────────────────

/// Invoice for a completed appointment — mirrors the `invoices` collection.
class Invoice {
  final String id;
  final String appointmentId;
  final String patientId;
  final String doctorId;
  final String patientName;
  final String doctorName;
  final String specialization;
  final String hospital;
  final String date;
  final String timeSlot;

  /// Amount in whole currency units (e.g. INR).
  final int amount;

  /// `unpaid` | `paid` | `refunded`
  final String status;

  final DateTime createdAt;

  Invoice({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.patientName,
    required this.doctorName,
    required this.specialization,
    required this.hospital,
    required this.date,
    required this.timeSlot,
    required this.amount,
    required this.status,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Invoice.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return Invoice(
      id: d.id,
      appointmentId: _s(m, 'appointmentId'),
      patientId: _s(m, 'patientId'),
      doctorId: _s(m, 'doctorId'),
      patientName: _s(m, 'patientName'),
      doctorName: _s(m, 'doctorName'),
      specialization: _s(m, 'specialization'),
      hospital: _s(m, 'hospital'),
      date: _s(m, 'date'),
      timeSlot: _s(m, 'timeSlot'),
      amount: _i(m, 'amount'),
      status: _s(m, 'status').isEmpty ? 'unpaid' : _s(m, 'status'),
      createdAt: m['createdAt'] is Timestamp
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'appointmentId': appointmentId,
        'patientId': patientId,
        'doctorId': doctorId,
        'patientName': patientName,
        'doctorName': doctorName,
        'specialization': specialization,
        'hospital': hospital,
        'date': date,
        'timeSlot': timeSlot,
        'amount': amount,
        'status': status,
      };

  Invoice copyWith({String? status}) => Invoice(
        id: id,
        appointmentId: appointmentId,
        patientId: patientId,
        doctorId: doctorId,
        patientName: patientName,
        doctorName: doctorName,
        specialization: specialization,
        hospital: hospital,
        date: date,
        timeSlot: timeSlot,
        amount: amount,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

// ── HealthMetric ─────────────────────────────────────────────────────────────

/// A single health metric reading — mirrors the `healthMetrics` collection.
class HealthMetric {
  final String id;
  final String patientId;

  /// One of: `bp` | `hr` | `sugar` | `spo2` | `weight`
  final String type;

  /// Primary value (systolic for BP, otherwise the sole value).
  final double value;

  /// Diastolic value for BP readings; null for all other types.
  final double? secondaryValue;

  final String unit;

  /// Optional patient note e.g. "after exercise", "fasting".
  final String note;

  final DateTime recordedAt;

  const HealthMetric({
    required this.id,
    required this.patientId,
    required this.type,
    required this.value,
    this.secondaryValue,
    required this.unit,
    this.note = '',
    required this.recordedAt,
  });

  factory HealthMetric.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return HealthMetric(
      id: d.id,
      patientId: _s(m, 'patientId'),
      type: _s(m, 'type'),
      value: _d(m, 'value'),
      secondaryValue: (m['secondaryValue'] as num?)?.toDouble(),
      unit: _s(m, 'unit'),
      note: _s(m, 'note'),
      recordedAt: m['recordedAt'] is Timestamp
          ? (m['recordedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'type': type,
        'value': value,
        if (secondaryValue != null) 'secondaryValue': secondaryValue,
        'unit': unit,
        'note': note,
      };

  /// Display string e.g. "120/80 mmHg" (BP) or "72 bpm" (HR).
  String get displayValue {
    if (type == 'bp' && secondaryValue != null) {
      return '${value.toStringAsFixed(0)}/${secondaryValue!.toStringAsFixed(0)} $unit';
    }
    return '${value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} $unit';
  }

  /// Human-readable metric name.
  String get label => const {
        'bp': 'Blood Pressure',
        'hr': 'Heart Rate',
        'sugar': 'Blood Sugar',
        'spo2': 'SpO\u2082',
        'weight': 'Weight',
      }[type]!;
}