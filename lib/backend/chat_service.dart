import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';

enum ChatErrorKind { auth, permission, network, invalidIdentity, unexpected }

/// Failure raised by [ChatService] with a user-presentable [message].
class ChatException implements Exception {
  final ChatErrorKind kind;
  final String message;
  const ChatException(this.kind, this.message);

  @override
  String toString() => message;
}

/// All chat operations for MedBridge patient-doctor messaging.
///
/// Firestore layout:
///   chats/{chatId}               - parent thread document
///   chats/{chatId}/messages/{id} - individual messages
///
/// chatId = "{smallerUid}_{largerUid}" built from the two Firebase Auth UIDs.
/// The parent document MUST exist (see [ensureChatExists]) before any
/// listener or message write touches the conversation, because the security
/// rules authorize message access by reading the parent's `participants`.
class ChatService {
  ChatService._();

  static const int maxTextLength = 2000;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _authUid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  // -- canonical conversation id --------------------------------------------

  /// The one and only conversation-id function. Both sides get the same id.
  static String chatId(String uidA, String uidB) {
    final a = uidA.trim();
    final b = uidB.trim();
    if (a.isEmpty || b.isEmpty) {
      throw const ChatException(
          ChatErrorKind.invalidIdentity, 'Missing chat participant.');
    }
    if (a == b) {
      throw const ChatException(
          ChatErrorKind.invalidIdentity, 'You cannot chat with yourself.');
    }
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Validates a message body. Returns the trimmed text.
  static String validateMessage(String text, {String? imageBase64}) {
    final trimmed = text.trim();
    final hasImage = imageBase64 != null && imageBase64.isNotEmpty;
    if (trimmed.isEmpty && !hasImage) {
      throw const ChatException(
          ChatErrorKind.unexpected, 'Message cannot be empty.');
    }
    if (trimmed.length > maxTextLength) {
      throw const ChatException(
          ChatErrorKind.unexpected, 'Message is too long.');
    }
    return trimmed;
  }

  /// Maps any thrown error to a [ChatException]. Never logs message content.
  static ChatException _wrap(String op, String path, Object e) {
    if (e is ChatException) return e;
    debugPrint('[Chat] $op failed at $path: '
        '${e is FirebaseException ? e.code : e.runtimeType}');
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return const ChatException(ChatErrorKind.permission,
              'You do not have permission to use this conversation.');
        case 'unavailable':
        case 'deadline-exceeded':
          return const ChatException(ChatErrorKind.network,
              'Network problem. Check your connection and retry.');
        case 'unauthenticated':
          return const ChatException(
              ChatErrorKind.auth, 'Please sign in again.');
      }
    }
    return const ChatException(
        ChatErrorKind.unexpected, 'Something went wrong. Please retry.');
  }

  // -- initialization -------------------------------------------------------

  /// Creates `chats/{chatId}` if missing (idempotent, race-safe via a
  /// transaction) or validates the existing participants. Never overwrites
  /// messages, counters or timestamps of an existing thread.
  ///
  /// Returns the canonical chat id.
  static Future<String> ensureChatExists({
    required String myId,
    required String myName,
    required String otherId,
    required String otherName,
    required bool otherIsDoctor,
  }) async {
    final uid = _authUid;
    if (uid == null) {
      throw const ChatException(ChatErrorKind.auth, 'Please sign in again.');
    }
    if (uid != myId) {
      throw const ChatException(
          ChatErrorKind.invalidIdentity, 'Signed-in user mismatch.');
    }
    final id = chatId(myId, otherId);
    final ref = _chats.doc(id);
    final patientId = otherIsDoctor ? myId : otherId;
    final doctorId = otherIsDoctor ? otherId : myId;
    final participants = [myId, otherId]..sort();

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          final existing =
              List<String>.from(snap.data()?['participants'] ?? const []);
          if (existing.length != 2 ||
              !existing.contains(myId) ||
              !existing.contains(otherId)) {
            throw const ChatException(ChatErrorKind.invalidIdentity,
                'This conversation has mismatched participants.');
          }
          return;
        }
        tx.set(ref, {
          'participants': participants,
          'patientId': patientId,
          'doctorId': doctorId,
          'participantNames': {myId: myName, otherId: otherName},
          'lastMessage': '',
          'lastSenderId': '',
          'lastTimestamp': FieldValue.serverTimestamp(),
          'unreadCounts': {myId: 0, otherId: 0},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      debugPrint('[Chat] ensureChatExists ok chats/$id');
      return id;
    } catch (e) {
      throw _wrap('ensureChatExists', 'chats/$id', e);
    }
  }

  // -- inbox / thread list --------------------------------------------------

  /// Conversations of the signed-in user that contain at least one message,
  /// newest first.
  static Stream<List<ChatThread>> myThreads() {
    final uid = _authUid;
    if (uid == null) return Stream.value(const []);
    return _chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs
            .map(ChatThread.fromDoc)
            .where((t) => t.lastMessage.isNotEmpty)
            .toList()
          ..sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp)));
  }

  static Stream<int> totalUnreadCount() {
    final uid = _authUid;
    return myThreads().map((threads) => uid == null
        ? 0
        : threads.fold(0, (acc, t) => acc + t.unreadCountFor(uid)));
  }

  // -- messages -------------------------------------------------------------

  static Stream<List<ChatMessage>> messages(String chatDocId) => _chats
      .doc(chatDocId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  /// Sends a message. The parent chat must already exist
  /// ([ensureChatExists]). The message and the thread metadata (preview,
  /// timestamp, recipient unread counter) are committed atomically.
  static Future<void> sendMessage({
    required String chatDocId,
    required String senderName,
    required String recipientId,
    required String text,
    String? imageBase64,
  }) async {
    final uid = _authUid;
    if (uid == null) {
      throw const ChatException(ChatErrorKind.auth, 'Please sign in again.');
    }
    if (chatId(uid, recipientId) != chatDocId) {
      throw const ChatException(
          ChatErrorKind.invalidIdentity, 'Conversation does not match.');
    }
    final trimmed = validateMessage(text, imageBase64: imageBase64);
    final hasImage = imageBase64 != null && imageBase64.isNotEmpty;

    final chatRef = _chats.doc(chatDocId);
    final msgRef = chatRef.collection('messages').doc();
    try {
      final batch = _db.batch();
      batch.set(msgRef, {
        'senderId': uid,
        'senderName': senderName,
        'recipientId': recipientId,
        'text': trimmed,
        if (hasImage) 'imageBase64': imageBase64,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      batch.update(chatRef, {
        'lastMessage': hasImage && trimmed.isEmpty ? 'Image' : trimmed,
        'lastSenderId': uid,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'participantNames.$uid': senderName,
        'unreadCounts.$recipientId': FieldValue.increment(1),
      });
      await batch.commit();
    } catch (e) {
      throw _wrap('sendMessage', 'chats/$chatDocId/messages', e);
    }
  }

  // -- read state -----------------------------------------------------------

  /// Marks messages sent by the other party as read and resets only this
  /// user's unread counter. Safe to call repeatedly; no-op when nothing is
  /// unread.
  static Future<void> markConversationRead(String chatDocId) async {
    final uid = _authUid;
    if (uid == null) return;
    try {
      final snap = await _chats
          .doc(chatDocId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();
      final unread =
          snap.docs.where((d) => d.data()['senderId'] != uid).toList();
      if (unread.isEmpty) return;

      final batch = _db.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {'isRead': true});
      }
      batch.update(_chats.doc(chatDocId), {'unreadCounts.$uid': 0});
      await batch.commit();
    } catch (e) {
      // Read receipts are best effort; never break the chat for them.
      debugPrint('[Chat] markConversationRead failed at chats/$chatDocId: '
          '${e is FirebaseException ? e.code : e.runtimeType}');
    }
  }

  static Future<void> markMessageRead(String chatDocId, String messageId) =>
      _chats
          .doc(chatDocId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
}
