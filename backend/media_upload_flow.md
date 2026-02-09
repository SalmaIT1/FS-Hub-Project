# Media Upload Flow

1. Client requests signed URL: POST /v1/uploads/signed-url with {filename, mime, size}
2. Server validates size, mime, permissions, returns `uploadUrl`, `downloadUrl`, and `fields` for multipart if needed
3. Client uploads directly to storage provider using signed URL or multipart
4. Client calls POST /v1/uploads/complete with {uploadId, conversationId, messageTempId, meta}
5. Server performs virus scan hook and persists file record; server then persist message in DB and emits `message:created` over WebSocket
6. Client only renders server-confirmed message (no optimistic render without rollback support); clients may show an upload progress UI tied to upload lifecycle

Security:
- Signed URL TTL short (60s)
- Validate MIME and size on server
- Virus-scan callback before downloadUrl activation
- Access-controlled download URLs: require expiring token for each download
