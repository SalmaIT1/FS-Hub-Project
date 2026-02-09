# Security Rules

1. Authentication: All API and WebSocket endpoints require a valid JWT in `Authorization: Bearer <token>` header or `token` query param on WS connection.

2. Uploads:
   - `POST /v1/uploads/signed-url` validates the user's role and conversation membership before issuing signed URLs.
   - Maximum file size enforced server-side (e.g., 250MB for enterprise tier).
   - Accepted MIME types whitelist; reject unknown types.
   - Virus-scan processing must complete and mark upload record `allowed=true` before `downloadUrl` becomes active.

3. Messages:
   - `POST /v1/messages/send` validates that `senderId` matches the authenticated identity and that sender is a participant.
   - Role-based permissions allow restricting who can send in certain conversations (e.g., read-only channels).
   - No anonymous uploads or messages.

4. Downloads:
   - Access-controlled download URLs using short-lived tokens tied to requesting user ID and upload record.

5. Real-time:
   - WS events are signed with server key and validated on receipt.

6. Data-at-rest:
   - Message DB fields encrypted at rest (AES-256) per-tenant keys.
   - File storage encrypted server-side; metadata stored with access controls.
# Security Rules

1. Authentication mandatory. Use short-lived JWTs.
2. Role-based permissions enforced server-side for send/upload/read/administration.
3. File uploads must be created through signed URL endpoint; server validates MIME and size.
4. Virus scanning must mark uploads `allowed=false` until cleared.
5. Download URLs require one-time expiring tokens; server validates requester has access to conversation.
6. Messages encrypted at rest (AES-256) with per-tenant key rotation.
7. No anonymous uploads: associate each upload with authenticated `userId` and `conversationId`.
8. WebSocket connections must be authorized via token query param and then validated on server handshake. Rate-limit typing events.
