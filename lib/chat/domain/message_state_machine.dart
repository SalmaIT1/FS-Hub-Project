/// Message lifecycle state machine
/// 
/// Server-driven state transitions:
/// draft → queued → [uploading] → sending → sent
///                                           ↘ delivered → read
///                                           ↘ failed (retry via queue)

enum MessageState {
  /// Local draft, not yet queued
  draft,

  /// In local offline queue, waiting for network or send
  queued,

  /// Attachments are uploading (if any)
  uploading,

  /// Message posted to server (waiting for ACK via WebSocket or REST response)
  sending,

  /// Server received and persisted message
  sent,

  /// Recipient delivered (receipt received via WebSocket)
  delivered,

  /// Recipient read (receipt received via WebSocket)
  read,

  /// Failed to send; eligible for retry
  failed,
}

/// Attachment lifecycle within message composition
enum AttachmentState {
  /// File selected or recording started
  selected,

  /// Uploading to server
  uploading,

  /// Upload succeeded, server-assigned URI stored
  uploaded,

  /// Upload failed; retry available
  failed,
}

/// Models the valid state transitions and guard conditions
class MessageStateTransition {
  final MessageState from;
  final MessageState to;
  final String reason; // REST success, WS delivery event, timeout, error, etc.

  MessageStateTransition({
    required this.from,
    required this.to,
    required this.reason,
  });

  /// Frontend-safe debug output
  @override
  String toString() => '$from → $to ($reason)';
}

/// Finite state machine for message lifecycle
/// 
/// Rules:
/// - Transitions are explicit; no implicit state guessing
/// - Each transition requires a triggering event (REST, WS, error)
/// - Failed messages can retry; retries restart from queued state
/// - UI renders current state; no state guessing
class MessageStateMachine {
  static const Map<MessageState, Set<MessageState>> allowedTransitions = {
    MessageState.draft: {MessageState.queued},
    MessageState.queued: {MessageState.uploading, MessageState.sending, MessageState.failed},
    MessageState.uploading: {MessageState.sending, MessageState.failed},
    MessageState.sending: {MessageState.sent, MessageState.failed},
    MessageState.sent: {MessageState.delivered, MessageState.read, MessageState.failed},
    MessageState.delivered: {MessageState.read},
    MessageState.read: {},
    MessageState.failed: {MessageState.queued}, // Retry
  };

  /// Validates if a transition is allowed
  static bool canTransition(MessageState from, MessageState to) {
    return allowedTransitions[from]?.contains(to) ?? false;
  }

  /// Enforces transition; throws if invalid
  static MessageState transition(MessageState from, MessageState to, String reason) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid transition: $from → $to');
    }
    return to;
  }

  /// Helper: Is message in a "sent" state (awaiting receipts)?
  static bool isSent(MessageState state) => 
      state == MessageState.sent || 
      state == MessageState.delivered || 
      state == MessageState.read;

  /// Helper: Is message in a terminal success state?
  static bool isTerminalSuccess(MessageState state) => state == MessageState.read;

  /// Helper: Can retry?
  static bool canRetry(MessageState state) => state == MessageState.failed;
}

/// Delivery metadata for a message (per recipient)
class MessageDeliveryStatus {
  final String recipientId;
  final DateTime deliveredAt;
  final DateTime? readAt;

  MessageDeliveryStatus({
    required this.recipientId,
    required this.deliveredAt,
    this.readAt,
  });

  Map<String, dynamic> toJson() => {
    'recipientId': recipientId,
    'deliveredAt': deliveredAt.toIso8601String(),
    'readAt': readAt?.toIso8601String(),
  };

  factory MessageDeliveryStatus.fromJson(Map<String, dynamic> j) => MessageDeliveryStatus(
    recipientId: j['recipientId'],
    deliveredAt: DateTime.parse(j['deliveredAt']),
    readAt: j['readAt'] != null ? DateTime.parse(j['readAt']) : null,
  );
}
