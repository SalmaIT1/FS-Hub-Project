# Chat Module: Production-Grade UI Architecture

## Quick Start

### Import
```dart
import 'package:fs_hub/chat/state/chat_controller.dart';
import 'package:fs_hub/chat/data/chat_rest_client.dart';
import 'package:fs_hub/chat/data/chat_socket_client.dart';
import 'package:fs_hub/chat/data/upload_service.dart';
import 'package:fs_hub/chat/data/chat_repository.dart';
```

### Initialize
```dart
// In main.dart or app initialization
final restClient = ChatRestClient(
  baseUrl: 'http://localhost:8080',
  tokenProvider: () async => getTokenFromSecureStorage(),
);

final socketClient = ChatSocketClient(
  wsUrl: 'ws://localhost:8080/ws',
  tokenProvider: () async => getTokenFromSecureStorage(),
);

final uploadService = UploadService(
  baseUrl: 'http://localhost:8080',
  tokenProvider: () async => getTokenFromSecureStorage(),
);

final repository = ChatRepository(
  rest: restClient,
  socket: socketClient,
  uploads: uploadService,
);

final controller = ChatController(repository: repository);

// Provide to UI
await controller.init();
```

### Use in Widgets
```dart
// In a widget using Provider
final controller = context.watch<ChatController>();

// Load conversations
await controller.loadConversations();

// Set current conversation
await controller.setCurrentConversation('conv-123');

// Send message
await controller.sendMessage('Hello world');

// Access state
final messages = controller.currentMessages;
final isOnline = controller.isOnline;
final offlineQueue = controller.offlineQueue;
```

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│             UI Layer                        │
│  (Screens, Widgets, Zero Business Logic)    │
├─────────────────────────────────────────────┤
│             State Layer                     │
│  (ChatController - ChangeNotifier)          │
├─────────────────────────────────────────────┤
│             Repository                      │
│  (Single Source of Truth)                   │
├─────────────────────────────────────────────┤
│          Data Layer                         │
│  REST    WebSocket    Uploads  Offline Q    │
├─────────────────────────────────────────────┤
│             Domain Layer                    │
│  (Entities, State Machine, Contracts)       │
└─────────────────────────────────────────────┘
                    ↓
            /v1 Backend API
            WebSocket Events
            Signed Upload URLs
```

## Key Features

### ✅ Workflow-Driven
- Explicit message states: `draft → queued → uploading → sending → sent → delivered → read`
- Each transition validates against `MessageStateMachine`
- No implicit state guessing

### ✅ Offline-Safe
- Messages queued automatically when offline
- Retries with exponential backoff on reconnect
- Deduplication via `clientMessageId` (idempotency)
- Queue persists across app restarts

### ✅ Backend-Trustful
- Server-assigned IDs (never client-generated)
- Canonical timestamps
- No UI assumptions about delivery
- Strict membership validation

### ✅ Mobile-First
- Virtualized message list (efficient scrolling)
- Touch-safe tap targets (48pt+)
- Minimal UI clutter
- Predictable gesture response

### ✅ Real-Time
- WebSocket connection for instant delivery receipts
- Typing indicators
- Presence tracking
- Fallback to polling if WS fails

### ✅ Attachment Support
- Upload before commit (file buffer on server)
- Progress streaming
- Retry on failure
- Image preview
- Voice notes with waveform

## File Structure

```
lib/chat/
├── domain/
│   ├── message_state_machine.dart   (finite state machine)
│   └── chat_entities.dart            (domain models)
├── data/
│   ├── chat_rest_client.dart         (REST /v1)
│   ├── chat_socket_client.dart       (WebSocket events)
│   ├── upload_service.dart           (attachment upload)
│   └── chat_repository.dart          (single source of truth)
├── state/
│   └── chat_controller.dart          (state provider)
└── ui/
    ├── message_bubble.dart           (message widget)
    ├── upload_progress_indicator.dart (upload UI)
    ├── chat_thread_page.dart         (TODO)
    ├── conversation_list_page.dart   (TODO)
    ├── composer_bar.dart             (TODO)
    └── voice_recorder_widget.dart    (TODO)

test/chat/
├── domain/
│   └── chat_entities_test.dart       (state machine tests)
├── data/
│   └── (repository, client tests - TODO)
└── ui/
    └── (widget tests - TODO)
```

## Testing

### Run state machine tests
```bash
flutter test test/chat/domain/chat_entities_test.dart
```

Expected output:
```
✓ Message state machine transitions work correctly
✓ Invalid transitions are rejected
✓ Chat entities parse from server JSON
✓ Message equality based on ID
```

### Run all chat tests
```bash
flutter test test/chat/
```

## Common Patterns

### Send a Text Message
```dart
try {
  await controller.sendMessage('Hello!');
  // Message added to UI immediately (optimistic)
  // On server response, replaces optimistic with canonical server message
} catch (e) {
  print('Error: $e');
}
```

### Listen to Online/Offline Status
```dart
context.watch<ChatController>().isOnline
  ? CircleAvatar(backgroundColor: Colors.green)
  : CircleAvatar(backgroundColor: Colors.grey)
```

### Show Offline Badge
```dart
if (!context.watch<ChatController>().isOnline) {
  Chip(
    label: Text('Offline'),
    avatar: Icon(Icons.cloud_off),
  )
}
```

### Show Delivery State Icon
```dart
final msg = message;
switch (msg.state) {
  case MessageState.draft:
  case MessageState.queued:
    return Icon(Icons.schedule, color: Colors.orange);
  case MessageState.sending:
    return CircularProgressIndicator();
  case MessageState.sent:
    return Icon(Icons.done, color: Colors.grey);
  case MessageState.delivered:
    return Icon(Icons.done_all, color: Colors.blue);
  case MessageState.read:
    return Icon(Icons.done_all, color: Colors.blueAccent);
  case MessageState.failed:
    return Icon(Icons.error, color: Colors.red);
}
```

### Retry Failed Message
```dart
if (message.state == MessageState.failed) {
  GestureDetector(
    onTap: () => controller.retryMessage(message.id),
    child: Icon(Icons.refresh),
  )
}
```

### Handle Upload Progress
```dart
// In composer/attachment picker
uploadService.progress.listen((progress) {
  print('Upload: ${(progress.progress * 100).toStringAsFixed(0)}%');
  setState(() {
    _uploadProgress = progress.progress;
  });
});
```

## Backend Contract

### REST Endpoints
```
GET    /v1/conversations                           (list)
GET    /v1/conversations/{id}                      (detail)
GET    /v1/conversations/{id}/messages             (history)
POST   /v1/conversations/{id}/messages             (send)
POST   /v1/auth/login                              (auth)
POST   /v1/auth/refresh                            (token)
POST   /v1/uploads/signed-url                      (get upload slot)
POST   /v1/uploads/complete                        (mark uploaded)
```

### WebSocket Events (from server)
```
{type: 'connected', data: {userId, connectionId}}
{type: 'message:created', payload: {message: {...}}}
{type: 'delivered', payload: {messageId, recipientId, deliveredAt}}
{type: 'read', payload: {messageId, readByUserId, readAt}}
{type: 'typing', payload: {conversationId, userId, state}}
{type: 'error', message: 'error desc'}
```

## Performance Notes

- **Message lookup:** O(1) via ID map
- **Message list:** Virtualized (max 50 on-screen widgets)
- **Offline queue:** O(n) retry on reconnect (typically <10)
- **Deduplication:** O(1) map lookup
- **WebSocket:** Single connection per app instance
- **Upload streaming:** No memory spike for large files

## Security Notes

- JWT tokens managed externally (not in chat layer)
- All requests include `Authorization: Bearer {token}`
- Upload URLs are single-use (signed by server)
- Message sender ID validated by backend
- Membership enforced by backend (client can't send to unauthorized convos)
- No sensitive data in logs

## Troubleshooting

### Messages not appearing
1. Check `ChatController.lastError`
2. Verify WebSocket connected: `ChatController.isOnline`
3. Check message state: is it in `sent`, `delivered`, or `read` state?
4. Verify conversation ID matches

### Offline queue not flushing
1. Check network connectivity
2. Verify JWT is still valid
3. Check `ChatRepository._offlineQueue` size
4. Retry count exceeds max → stays failed

### Upload fails
1. Check file size (backend may have limits)
2. Verify signed URL not expired
3. Check network latency
4. Retry with exponential backoff

## Next Steps

1. **Implement chat screens** using `ChatController`
2. **Add integration tests** against backend
3. **Monitor in production** (message delivery times, queue depth)
4. **Expand to groups** (already supports, add UI for group creation)
5. **Add attachments UI** (file picker, image viewer, voice recorder)

## Support

For questions or issues, refer to:
- [Chat Architecture Guide](./CHAT_ARCHITECTURE.md)
- Backend contracts in `/backend/ws_schema.json` and API docs
- Domain model tests in `test/chat/domain/`
