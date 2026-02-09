# Real-Time Message Delivery Contract & Invariants

**Purpose**: Define the hard contract that the system MUST maintain for correct real-time message delivery.

---

## 🔒 SYSTEM INVARIANTS (IMMUTABLE)

### Invariant 1: Single Source of Truth Per Conversation
```
For each conversationId:
  • Repository._messages[conversationId] is authoritative
  • Controller._conversationMessages[conversationId] mirrors it for current conversation
  • UI renders from Controller.currentMessages getter
  
VIOLATION: If message exists in repository but not in controller → MESSAGE LOSS
```

### Invariant 2: Every Message Path Leads to UI
```
When message createdAt database:
  1. Message inserted with ID, conversationId, content, timestamp
  2. Message returned in REST response (if requested)
  3. Message broadcast via WebSocket (if any members online)
  4. Repository._messages[convId][msgId] = message
  5. Repository emits messageUpdated stream
  6. Controller receives and stores in _conversationMessages[convId][msgId]
  7. Controller calls notifyListeners() if current conversation affected
  8. UI rerenders and calls currentMessages getter
  9. Message appears on screen for all online participants

VIOLATION: If any step fails or is skipped → MESSAGE NOT VISIBLE
```

### Invariant 3: Message Deduplication
```
Same message must never appear twice:
  • Same REST response received twice → Idempotency prevents duplicate insert
  • Same WebSocket broadcast received twice → clientMessageId deduplication
  • REST + WebSocket both deliver same message → clientMessageId mapping prevents duplication
  
VIOLATION: If same message appears twice → CONFUSION AND DATA CORRUPTION
```

### Invariant 4: Order Preservation
```
Messages within a conversation must always be sorted by createdAt:
  • Initial REST fetch: sorted DESC (newest first)
  • WebSocket message arrives: inserted and re-sorted
  • Display: reverse sorted (oldest first at bottom)
  
VIOLATION: If out of order → CONVERSATION INCOHERENT
```

### Invariant 5: Real-Time Delivery
```
When message is persisted on server:
  • Sender's REST response includes full message (< 100ms typical)
  • Broadcast to recipients begins immediately after DB commit
  • Recipient receives via WebSocket (< 500ms target)
  • Message appears on recipient's screen (< 1000ms target)
  
VIOLATION: If message doesn't appear in < 5 seconds → FAILURE
```

### Invariant 6: State Consistency Across Sessions
```
If user closes and reopens app for same conversation:
  • Message should still exist in database
  • REST fetch should include all messages
  • No message should be lost
  
VIOLATION: If any message missing after re-login → DATA LOSS
```

### Invariant 7: Race Condition Safety
```
WebSocket messages that arrive BEFORE REST load completes:
  • Must not be dropped
  • Must be merged with REST messages when REST arrives
  • Must appear in correct order
  
CRITICAL SCENARIO:
  t=0:  User opens conversation, REST fetch begins
  t=50ms:  Another user sends message, WebSocket arrives
  t=100ms:  REST response returns OLD messages (doesn't include t=50ms message)
  
  MUST: Handle this by merging, not dropping WebSocket message
```

---

## 📝 CONTRACTS

### Client → Server Contract

**Message Send Request**:
```json
{
  "method": "POST",
  "url": "/v1/conversations/{conversationId}/messages",
  "headers": {
    "Authorization": "Bearer {jwt}",
    "Content-Type": "application/json"
  },
  "body": {
    "senderId": "extracted from JWT",
    "content": "message text",
    "type": "text",
    "clientMessageId": "uuid for idempotency"
  }
}
```

**Expected Response**:
```json
{
  "success": true,
  "message": {
    "id": "server-generated-id",
    "conversationId": "conv-id",
    "senderId": "user-id",
    "content": "message text",
    "type": "text",
    "clientMessageId": "original uuid",
    "createdAt": "2026-02-09T10:30:00Z",
    "state": "sent"
  }
}
```

**Timing**: < 100ms from send to response

---

### Server → WebSocket Broadcast Contract

**Event Format**:
```json
{
  "type": "message:created",
  "payload": {
    "message": {
      "id": "msg-123",
      "conversationId": "conv-456",
      "senderId": "user-789",
      "content": "Hello",
      "type": "text",
      "clientMessageId": "client-uuid",
      "createdAt": "2026-02-09T10:30:00Z"
    }
  },
  "timestamp": 1707559800000
}
```

**Recipients**: All conversation members who are currently connected

**Timing**: Broadcast starts immediately after DB commit (< 50ms)

**Guarantee**: 
- Event sent AT LEAST once (no loss)
- Event may be duplicated (receiver must handle via clientMessageId)
- No guarantee of order for multiple messages (client must sort)

---

### Repository State Machine

```
Message States: DRAFT → SENDING → SENT → DELIVERED → READ

Operations:
  DRAFT:      Can retry, can edit locally
  SENDING:    Cannot edit, waiting for server ACK
  SENT:       Server confirmed, no more retries needed
  DELIVERED:  Receipt received from recipient
  READ:       Recipient marked as read

Transitions:
  DRAFT → SENDING:    Attempting REST POST
  SENDING → SENT:     REST response received
  SENDING → FAILED:   REST failed, eligible for retry
  SENT → DELIVERED:   Delivery receipt from recipient
  DELIVERED → READ:   Read receipt from recipient
```

---

## ✅ VERIFICATION CHECKLIST

Every message delivery must pass these checks:

- [ ] **ID Check**: Message has non-empty ID before storing
- [ ] **Conversation Check**: Message has valid conversationId
- [ ] **Sender Check**: Message has valid senderId
- [ ] **Timestamp Check**: Message has createdAt timestamp
- [ ] **Duplication Check**: No message ID appears twice in conversation
- [ ] **Store Check**: Message exists in repository._messages[convId][id]
- [ ] **Controller Check**: For current conversation, message in controller.currentMessages
- [ ] **UI Check**: Message visible on screen in correct position
- [ ] **Sort Check**: Messages sorted by createdAt in correct order
- [ ] **Persistence Check**: Message still in DB and visible after refresh

---

## 🚨 ERROR SCENARIOS & RECOVERY

### Scenario 1: WebSocket Broadcast Missing

**Detection**: 
```
REST response contains message ID
But message doesn't appear on recipient after 5 seconds
```

**Recovery**:
```
1. Check if recipient has conversation loaded
2. If yes, fetch message directly via REST GET /messages
3. Merge into current list
4. Notify UI
```

**Code Location**: [lib/chat/data/chat_repository.dart](lib/chat/data/chat_repository.dart)

---

### Scenario 2: REST Response Lost

**Detection**:
```
Message stays in SENDING state for > 2 seconds
```

**Recovery**:
```
1. Client retries REST POST with same clientMessageId
2. Server returns idempotent result (existing message)
3. Client uses returned ID
4. Message transitions to SENT
```

**Code Location**: [lib/chat/state/chat_controller.dart](lib/chat/state/chat_controller.dart#L133)

---

### Scenario 3: WebSocket Arrives Before REST Load Complete

**Detection** (CRITICAL):
```
Controller._conversationMessages doesn't have conversation yet
But WebSocket message arrives for that conversation
```

**Recovery**:
```
1. Controller ALWAYS uses putIfAbsent() to ensure store exists ✓ FIXED
2. Message added even if conversation not pre-loaded
3. Later when REST load completes, it merges (doesn't replace) ✓ FIXED
```

**Code Location**: [lib/chat/state/chat_controller.dart](lib/chat/state/chat_controller.dart#L163)

---

### Scenario 4: Offline Message Queue

**Detection**:
```
Network status: offline
Message sent while offline
```

**Recovery**:
```
1. Message queued locally with state: QUEUED
2. When online again, processOfflineQueue() called
3. Each queued message retried with original clientMessageId
4. Server returns canonical message
5. Idempotency prevents duplicates
```

**Code Location**: [lib/chat/data/chat_repository.dart](lib/chat/data/chat_repository.dart#L285)

---

## 📊 MONITORING & ALERTING

### Metrics to Track

```
Message Pipeline Metrics:
  ✓ Time from send to REST response (target: < 100ms)
  ✓ Time from REST response to WebSocket receipt (target: < 50ms)
  ✓ Time from WebSocket receipt to UI render (target: < 100ms)
  ✓ Total time from send to receiver's UI (target: < 500ms)
  
Error Metrics:
  ✓ Messages dropped due to race conditions (target: 0)
  ✓ Duplicate messages (target: 0)
  ✓ Messages with empty IDs (target: 0)
  ✓ Messages missing from receiver (target: 0)
  
Recovery Metrics:
  ✓ Offline queue length
  ✓ Retry success rate
  ✓ WebSocket reconnections
  ✓ REST timeout count
```

### Alert Thresholds

```
CRITICAL (Page):
  • Any INVARIANT VIOLATION (empty ID, duplicate, etc.)
  • Message loss rate > 0.5%
  • WebSocket broadcast failure rate > 5%

WARNING (Investigate):
  • Message delivery > 5 seconds
  • REST response > 500ms
  • Offline queue length > 10
  • WebSocket reconnections > 5 per minute
```

---

## 🧪 TEST CASES FOR EACH INVARIANT

### Test: Invariant 1 - Single Source of Truth
```dart
test('Repository message updates propagate to controller', () {
  final repo = ChatRepository(...);
  final controller = ChatController(repository: repo);
  
  final msg = ChatMessage(...);
  repo.messageUpdated.add(msg);  // Simulate WS event
  
  expect(repo._messages[msg.conversationId][msg.id], equals(msg));
  expect(controller.currentMessages, contains(msg));
});
```

### Test: Invariant 2 - Every Message Path to UI
```dart
test('Message follows complete pipeline', () {
  // 1. Send message ✓
  // 2. REST response ✓
  // 3. Repository store ✓
  // 4. Controller store ✓
  // 5. UI renders ✓
  expect(find.text(messageContent), findsOneWidget);
});
```

### Test: Invariant 3 - No Duplicates
```dart
test('Same message via REST and WebSocket appears once', () {
  final msg = ChatMessage(id: 'msg-123', ...);
  
  // REST arrives first
  controller.sendMessage(...);
  expect(controller.currentMessages.where((m) => m.id == 'msg-123').length, 1);
  
  // WebSocket arrives second
  repo.messageUpdated.add(msg);
  expect(controller.currentMessages.where((m) => m.id == 'msg-123').length, 1);
});
```

---

## 🎯 CONCLUSION

This contract ensures that:

1. **No message is silently dropped** (Invariant 1-2)
2. **No message appears twice** (Invariant 3)
3. **Messages appear in correct order** (Invariant 4)
4. **Real-time delivery is achieved** (Invariant 5)
5. **Data persists across sessions** (Invariant 6)
6. **Race conditions are handled** (Invariant 7)

Any violation of these invariants must:
- Be detected (via instrumentation)
- Be logged (with context)
- Be escalated (to user or support)
- Be fixed (with corrective action)

**The system is only correct if ALL invariants hold at ALL times.**
