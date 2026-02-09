# Chat UI Refactor: Production-Grade Architecture

## Overview

This document describes the rebuilt chat UI system, which is:
- **Fully workflow-driven** (state machine-based)
- **Mobile-first** (thumb-reachable, gesture-safe)
- **Offline-safe** (queue, retry, deduplication)
- **Backend-trustful** (no guessing server state)
- **Atomic message lifecycle** (draft → queued → sending → sent → delivered → read)

## Architecture Layers

### 1. Domain Layer (`/lib/chat/domain/`)

**Responsibility:** Defines the application's business rules and invariants.

#### `message_state_machine.dart`
- Explicit message states and transitions
- Rules for valid state flows
- No implicit state guessing
- Used by repository and UI for state visualization

State machine:
```
draft → queued → uploading → sending → sent
                                        ↘ delivered → read
                                        ↘ failed (retry)
```

#### `chat_entities.dart`
- `ChatMessage`: Server-canonical message model (never UI-only IDs)
- `ConversationEntity`: Conversation metadata
- `AttachmentEntity`: File/image metadata
- `VoiceNoteEntity`: Audio metadata
- All entities parse from server JSON; UI renders without transformation

### 2. Data Layer (`/lib/chat/data/`)

**Responsibility:** Communicate with backend; manage persistence and offline state.

#### `chat_rest_client.dart`
- Binds to `/v1` backend contract
- Endpoints: GET conversations, GET messages, POST message, login, refresh
- Clean error handling (no silent failures)
- Adds `clientMessageId` to POST for idempotency

#### `chat_socket_client.dart`
- Real-time WebSocket connection to `/ws/chat/{token}`
- Typed events: `ConnectedEvent`, `MessageCreatedEvent`, `MessageDeliveredEvent`, `MessageReadEvent`, `TypingEvent`, `ErrorEvent`
- Automatic reconnection on disconnect
- Event stream for UI consumption

#### `upload_service.dart`
- Manages attachment upload pipeline
- Request signed URL → upload file → notify complete
- Streaming progress events for UI
- Never uploads without backend approval (signed URL)

#### `chat_repository.dart`
- **Single source of truth** for all chat state
- Merges messages from REST and WebSocket
- Manages offline queue (JSON serializable)
- Enforces state machine transitions
- Deduplication via `clientMessageId → serverMessageId` map
- Emits typed streams: `messageUpdated`, `conversationUpdated`, `queueChanged`, `onlineStatusChanged`

### 3. State Layer (`/lib/chat/state/`)

**Responsibility:** Orchestrate business logic; provide UI-friendly data streams.

#### `chat_controller.dart`
- `ChangeNotifier` wrapping repository
- High-level actions: `sendMessage()`, `retryMessage()`, `loadConversations()`, `setCurrentConversation()`
- Caches UI state (current conversation, message list)
- Subscribes to repository streams
- Error handling and last-error reporting

### 4. UI Layer (`/lib/chat/ui/`)

**Responsibility:** Render state; zero business logic.

#### Core Widgets
- `message_bubble.dart`: Renders single message with delivery state icon, timestamp, retry button
- `upload_progress_indicator.dart`: Shows file upload progress
- `voice_recorder_widget.dart`: (To be created) Press-to-record with waveform
- `attachment_preview.dart`: (To be created) File/image preview before send

#### Screens
- `chat_thread_page.dart`: (To be created) Virtualized message list, composer, scroll preservation
- `conversation_list_page.dart`: (To be created) Conversation list, unread badges, typing indicators, drafts
- `chat_shell.dart`: (Already exists) Stores initialize repository and controller

## Data Flow

### Sending a Message (Online)

```
UI: User types + taps send
  ↓
Controller.sendMessage(content)
  ↓
Repository.sendTextMessage()
  1. Create optimistic local message (state: draft)
  2. Emit to UI immediately (optimistic rendering)
  3. Transition: draft → sending
  4. POST /v1/conversations/{id}/messages with clientMessageId
  5. Server returns canonical message (server ID, timestamp)
  6. Replace optimistic message with canonical
  7. Emit updated message (state: sent)
  ↓
WebSocket: Backend broadcasts message:created to all participants
  ↓
Socket.events stream → Repository → Controller → UI updates
```

### Message Delivery Receipt

```
Recipient receives message
  ↓
Backend tracks delivery
  ↓
Backend emits delivery:received via WebSocket
  ↓
Socket.events → Repository.applyDeliveryReceipt()
  ↓
Repository transitions: sent → delivered
  ↓
Repository emits messageUpdated stream
  ↓
Controller caches update
  ↓
UI rebuilds (delivery icon changes to checkmark)
```

### Offline Message Queue

```
Network goes offline
  ↓
All subsequent sends → Repository._offlineQueue (state: queued)
  ↓
Repository emits queueChanged stream
  ↓
UI shows "Offline" badge + queue indicator
  ↓
Network comes back online
  ↓
Socket reconnects → ConnectedEvent
  ↓
Repository.processOfflineQueue()
  1. For each queued message:
     - POST /v1/conversations/{id}/messages (same clientMessageId)
     - On success: replace optimistic with canonical
     - On failure: stay queued (retry on next connection)
  ↓
Queue empties → queueChanged stream emits empty list
  ↓
UI removes offline badge
```

### Attachment Upload (Before Send)

```
UI: User selects file
  ↓
Controller.composer.selectAttachment(file)
  ↓
Composer requests signed URL: UploadService.requestSignedUrl()
  ↓
Backend returns: {uploadId, uploadUrl, expiresAt, meta}
  ↓
Composer streams upload: UploadService.uploadFile()
  ↓
Progress events → Composer.onProgress stream → UI updates progress bar
  ↓
Upload complete → UploadService notifies backend: /v1/uploads/complete
  ↓
Backend stores attachment reference (not yet bound to message)
  ↓
User taps send message (attachments already uploaded)
  ↓
POST /v1/conversations/{id}/messages with meta: {attachments: [...]}
  ↓
Message persisted with attachment references
  ↓
WebSocket broadcasts message:created
```

## Integration with Existing Code

### What Stays

- `lib/chat_shell.dart` (minimal changes: pass controller instead of old services)
- `lib/models/message.dart` (deprecated, not used by new UI)
- `lib/services/rest_fallback_client.dart` (deprecated, not used by new UI)
- `lib/services/message_store.dart` (deprecated, repository replaces this)

### What Changes

1. **Create** `/lib/chat/` directory structure
2. **Update** `lib/main.dart` to initialize `ChatController` via `MultiProvider`
3. **Replace** old chat screens with new ones from `/lib/chat/ui/`
4. **Delete** old implementations after migration complete

### Step-by-Step Migration

#### Step 1: Build New Chat Layer (Complete ✓)
- Domain entities & state machine
- Data clients (REST, WebSocket, Upload)
- Repository (single source of truth)
- Controller (state provider)
- Core UI widgets

#### Step 2: Create New Chat Screens
- `ConversationListPage` (replace old list)
- `ChatThreadPage` (replace old thread)
- `ComposerBar` (replace old composer)

#### Step 3: Update Main & Providers
```dart
// lib/main.dart (sample)
void main() {
  final rest = ChatRestClient(
    baseUrl: 'http://localhost:8080',
    tokenProvider: () async => getTokenFromStorage(),
  );
  final socket = ChatSocketClient(
    wsUrl: 'ws://localhost:8080/ws',
    tokenProvider: () async => getTokenFromStorage(),
  );
  final uploads = UploadService(
    baseUrl: 'http://localhost:8080',
    tokenProvider: () async => getTokenFromStorage(),
  );
  final repository = ChatRepository(rest: rest, socket: socket, uploads: uploads);
  final controller = ChatController(repository: repository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
      ],
      child: MyApp(),
    ),
  );
}
```

#### Step 4: Replace Screens
- Update navigation to point to new screens
- Remove old screen files once verified working

#### Step 5: Cleanup
- Delete deprecated `/lib/services/message_*.dart`
- Delete old chat UI files

## Key Design Principles

### 1. Single Source of Truth
- Repository is the only owner of message/conversation state
- UI derives from repository via controller
- No duplicate arrays, no UI-only state

### 2. Explicit State Transitions
- Message state only changes via `MessageStateMachine.transition()`
- Invalid transitions throw errors
- UI renders state, doesn't guess it

### 3. Backend Trust
- All messages come from server (never generated client-side)
- Server IDs are canonical
- Client IDs are for idempotency/deduplication only

### 4. Atomic Offline Safety
- Every message gets a `clientMessageId` (UUID)
- On reconnect, retry with same `clientMessageId`
- Server deduplicates via idempotency table
- UI replaces optimistic message with canonical server message

### 5. Mobile-First

Design principles:
- Touch targets ≥ 48pt
- Gestures over buttons where possible
- Minimal visual noise
- Predictable scrolling (virtualized list)
- Keyboard-safe layout

## Testing

### Unit Tests (State Machine)
```dart
test('message transitions from draft to queued when offline', () {
  expect(MessageStateMachine.canTransition(MessageState.draft, MessageState.queued), true);
  expect(MessageStateMachine.canTransition(MessageState.read, MessageState.draft), false);
});
```

### Widget Tests (Message Bubble)
```dart
testWidgets('delivery icon shows checkmark when sent', (tester) async {
  final msg = ChatMessage(...state: MessageState.sent);
  await tester.pumpWidget(MessageBubble(message: msg));
  expect(find.byIcon(Icons.done_all), findsOneWidget);
});
```

### Integration Tests
- Send message online
- Send message offline, verify queued
- Go online, verify queue flushes
- Verify deduplication with same clientMessageId
- Verify WebSocket delivery receipt transitions state
- Verify scroll position preservation across navigation

## Files Created

### Domain
- `lib/chat/domain/message_state_machine.dart` (102 lines)
- `lib/chat/domain/chat_entities.dart` (421 lines)

### Data
- `lib/chat/data/upload_service.dart` (197 lines)
- `lib/chat/data/chat_rest_client.dart` (193 lines)
- `lib/chat/data/chat_socket_client.dart` (259 lines)
- `lib/chat/data/chat_repository.dart` (364 lines)

### State
- `lib/chat/state/chat_controller.dart` (162 lines)

### UI (Partial)
- `lib/chat/ui/message_bubble.dart` (204 lines)
- `lib/chat/ui/upload_progress_indicator.dart` (81 lines)

### Pending
- `lib/chat/ui/chat_thread_page.dart` (virtualized list)
- `lib/chat/ui/conversation_list_page.dart` (list with all metadata)
- `lib/chat/ui/composer_bar.dart` (text, file, voice input)
- `lib/chat/ui/voice_recorder_widget.dart` (press-to-record)
- `lib/chat/ui/attachment_preview.dart` (preview before send)
- `test/chat/` (state machine, widget, integration tests)

## Performance Characteristics

- **Message List:** O(1) lookup, virtualized rendering (max 50 on-screen)
- **Offline Queue:** O(n) retry on reconnect (typically <10 items)
- **Deduplication:** O(1) map lookup via clientMessageId
- **WebSocket:** Singleton connection, typed event stream (no parsing overhead)
- **Upload:** Streaming progress (no memory spike for large files)

## Security

- JWT tokens managed externally (not in chat layer)
- All requests include Authorization header
- No server secrets in client code
- Upload URLs are single-use (server-signed with expiry)
- Message sender ID validated by backend (never trusted from client)
- Membership validation: backend rejects messages to conversations without membership

## Next Steps

1. **Implement screens** (`ChatThreadPage`, `ConversationListPage`)
2. **Implement composer** (text input, file/image picker, voice recorder)
3. **Add tests** (state machine, offline, WebSocket, deduplication)
4. **Run integration test** against backend
5. **Migrate navigation** to new chat screens
6. **Remove old implementations** (deprecated services)
7. **Deploy & monitor** (observe message delivery times, queue performance)

---

## Summary

This refactor replaces ad-hoc UI logic with a clean, workflow-driven architecture:

- **Domain layer** defines business rules (state machine)
- **Data layer** syncs with backend (REST + WebSocket + offline queue)
- **State layer** orchestrates UI interactions (controller)
- **UI layer** renders state (zero business logic)

Result: A production-grade chat UI that is:
- Predictable (finite state machine)
- Reliable (offline-safe, atomic retries)
- Fast (O(1) lookups, virtualized rendering)
- Maintainable (clear separation of concerns)
- Testable (all layers independently unit-testable)
