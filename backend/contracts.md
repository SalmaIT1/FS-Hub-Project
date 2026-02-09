# Chat Backend API Contracts

## Authentication
- All endpoints require `Authorization: Bearer <JWT>` header.

## REST Endpoints

POST /v1/messages/send
- Body: {
  id: string (client-generated temp id),
  conversationId: string,
  senderId: string,
  type: 'text'|'image'|'file'|'audio'|'system',
  content: string,
  timestamp: integer (ms),
  meta: object (optional)
}
- Response 201: canonical message object persisted (server id)

GET /v1/conversations
- paginated list of conversations

GET /v1/conversations/:id/messages?cursor=&limit=
- paginated messages (cursor-based)

POST /v1/uploads/signed-url
- Request: {filename, mime, size}
- Response: {uploadUrl, downloadUrl, fields?}

POST /v1/uploads/complete
- Notify server upload finished; server performs virus scan and persists metadata

## WebSocket
- Connect to `wss://HOST/v1/ws?token=<jwt>`
- Events are JSON objects per ws_schema.json
