import 'package:cloud_firestore/cloud_firestore.dart';

/// All supported doctor specializations.
const List<String> kSpecializations = [
  'General Physician',
  'Cardiologist',
  'Dermatologist',
  'Pediatrician',
  'Orthopedic',
  'Neurologist',
  'Gynecologist',
  'Dentist',
  'ENT Specialist',
  'Ophthalmologist',
  'Psychiatrist',
  'Urologist',
];

/// Record category types.
const List<String> kRecordCategories = [
  'lab_report',
  'diagnosis',
  'note',
  'prescription',
];

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Zero-pads a single-digit integer.
String two(int n) => n.toString().padLeft(2, '0');

/// Returns an ISO-8601 date string yyyy-MM-dd.
String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// Formats an ISO date to a human-readable string like "14 May 2025".
String prettyDate(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  return '${int.parse(p[2])} ${_months[int.parse(p[1]) - 1]} ${p[0]}';
}

/// Short weekday name from a [DateTime].
String weekdayShort(DateTime d) => _days[d.weekday - 1];

/// Short month name from a [DateTime].
String monthShort(DateTime d) => _months[d.month - 1];

/// Prefix a name with "Dr. " unless it already starts with "Dr".
String drName(String n) => n.toLowerCase().startsWith('dr') ? n : 'Dr. $n';

/// Returns the first name or "there" for empty strings.
String firstName(String n) {
  final t = n.trim();
  return t.isEmpty ? 'there' : t.split(' ').first;
}

/// Extract a [DateTime] from a Firestore timestamp map field.
DateTime tsOf(Map<String, dynamic> m, [String key = 'createdAt']) {
  final v = m[key];
  return v is Timestamp ? v.toDate() : DateTime.now();
}

/// Represents a bookable time slot.
class Slot {
  final int hour;
  final int minute;
  Slot(this.hour, this.minute);

  /// 12-hour label, e.g. "09:30 AM".
  String get label {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final ap = hour < 12 ? 'AM' : 'PM';
    return '${two(h12)}:${two(minute)} $ap';
  }

  /// 24-hour time string "HH:mm".
  String get time24 => '${two(hour)}:${two(minute)}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Slot && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => hour * 60 + minute;
}

/// Human-readable timestamp text from a Firestore map.
String tsText(Map<String, dynamic> m, [String key = 'createdAt']) {
  final d = tsOf(m, key);
  return '${prettyDate(isoDate(d))}, ${Slot(d.hour, d.minute).label}';
}

/// Generate default time slots (9 AM – 5 PM, 30 min each, lunch at 1 PM).
List<Slot> buildSlots({
  int startHour = 9,
  int endHour = 17,
  int slotMinutes = 30,
  int lunchHour = 13,
}) {
  final out = <Slot>[];
  for (var h = startHour; h <= endHour; h++) {
    for (var m = 0; m < 60; m += slotMinutes) {
      if (h == lunchHour) continue;
      if (h == endHour && m >= slotMinutes) continue;
      out.add(Slot(h, m));
    }
  }
  return out;
}

/// Build slots from a doctor's availability settings (same algorithm as the
/// preview in the availability editor).
List<Slot> buildSlotsFromAvailability(Map<String, dynamic>? availability) {
  if (availability == null || availability.isEmpty) {
    return buildSlots();
  }
  final startHour = (availability['startHour'] as num?)?.toInt() ?? 9;
  final endHour = (availability['endHour'] as num?)?.toInt() ?? 17;
  final slotMinutes = (availability['slotMinutes'] as num?)?.toInt() ?? 30;
  final legacyLunch = (availability['lunchHour'] as num?)?.toInt();
  final lunchStart = (availability['lunchStart'] as num?)?.toInt() ??
      legacyLunch ??
      13;
  final lunchEnd = (availability['lunchEnd'] as num?)?.toInt() ??
      (legacyLunch != null ? legacyLunch + 1 : 14);
  if (slotMinutes <= 0) return buildSlots();

  final out = <Slot>[];
  for (var t = startHour * 60; t + slotMinutes <= endHour * 60; t += slotMinutes) {
    if (t >= lunchStart * 60 && t < lunchEnd * 60) {
      t = lunchEnd * 60 - slotMinutes; // jump to lunch end
      continue;
    }
    out.add(Slot(t ~/ 60, t % 60));
  }
  return out;
}

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Check if a given weekday (1 = Mon .. 7 = Sun) is a working day.
/// The availability editor saves `workDays` as names ("Mon"); registration
/// saves `workingDays` as numbers. Both are understood.
bool isWorkingDay(int weekday, Map<String, dynamic>? availability) {
  final names = availability?['workDays'];
  if (names is List) {
    return names.map((e) => e.toString()).contains(_dayNames[weekday - 1]);
  }
  final nums = availability?['workingDays'];
  if (nums is List && nums.isNotEmpty) {
    return nums.map((e) => (e as num).toInt()).contains(weekday);
  }
  return weekday >= 1 && weekday <= 6; // default Mon-Sat
}

/// Unique key for a slot for a given doctor and date.
String makeSlotKey(String doctorId, String date, Slot s) =>
    '${doctorId}_${date}_${two(s.hour)}${two(s.minute)}';

/// Lightweight i18n string map.
const Map<String, Map<String, String>> kStrings = {
  'en': {
    'home': 'Home',
    'appointments': 'Appointments',
    'records': 'Records',
    'profile': 'Profile',
    'dashboard': 'Dashboard',
    'requests': 'Requests',
    'patients': 'Patients',
    'settings': 'Settings',
    'logout': 'Logout',
    'login': 'Login',
    'signup': 'Sign Up',
    'search': 'Search Doctors, Symptoms...',
    'book': 'Book Appointment',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'save': 'Save',
    'dark_mode': 'Dark Mode',
    'language': 'Language',
    'notifications': 'Notifications',
    'welcome': 'Welcome',
  },
  'hi': {
    'home': 'होम',
    'appointments': 'अपॉइंटमेंट्स',
    'records': 'रिकॉर्ड्स',
    'profile': 'प्रोफ़ाइल',
    'dashboard': 'डैशबोर्ड',
    'requests': 'अनुरोध',
    'patients': 'मरीज़',
    'settings': 'सेटिंग्स',
    'logout': 'लॉगआउट',
    'login': 'लॉगिन',
    'signup': 'साइन अप',
    'search': 'डॉक्टर, लक्षण खोजें...',
    'book': 'अपॉइंटमेंट बुक करें',
    'cancel': 'रद्द करें',
    'confirm': 'पुष्टि करें',
    'save': 'सहेजें',
    'dark_mode': 'डार्क मोड',
    'language': 'भाषा',
    'notifications': 'सूचनाएँ',
    'welcome': 'स्वागत है',
  },
  'ta': {
    'home': 'முகப்பு',
    'appointments': 'சந்திப்புகள்',
    'records': 'பதிவுகள்',
    'profile': 'சுயவிவரம்',
    'dashboard': 'டாஷ்போர்டு',
    'requests': 'கோரிக்கைகள்',
    'patients': 'நோயாளிகள்',
    'settings': 'அமைப்புகள்',
    'logout': 'வெளியேறு',
    'login': 'உள்நுழை',
    'signup': 'பதிவு செய்',
    'search': 'மருத்துவர்கள், அறிகுறிகளை தேடு...',
    'book': 'சந்திப்பை பதிவு செய்',
    'cancel': 'ரத்து',
    'confirm': 'உறுதி செய்',
    'save': 'சேமி',
    'dark_mode': 'இருண்ட பயன்முறை',
    'language': 'மொழி',
    'notifications': 'அறிவிப்புகள்',
    'welcome': 'வரவேற்பு',
  },
};

/// Get a localized string by key and language code.
String tr(String key, [String? lang]) {
  final code = lang ?? 'en';
  return kStrings[code]?[key] ?? kStrings['en']?[key] ?? key;
}
