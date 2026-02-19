# Complete Attachment & Voice Messaging System

This document describes the rebuilt attachment and voice messaging system that follows strict requirements for preview, upload, atomic binding, and real-time delivery.

## 🎯 System Guarantees

Every attachment message follows this exact flow:
```
Select → Preview → Remove(optional) → Upload → Confirm → Message commit → WebSocket broadcast → Receiver render
```

If any stage fails → message is not created.

## 📋 Features Implemented

### ✅ Phase 1: Frontend Pre-send Preview System
- **Attachment Tray**: Persistent preview tray above composer
- **Type-specific Previews**: 
  - Images: Thumbnail preview
  - Videos: Thumbnail + play icon
  - Files: Icon + filename + size
  - Voice: Waveform + duration
- **Remove Functionality**: ❌ Remove button on each tile
- **Upload Progress**: 📊 Progress bars for each attachment
- **State Badges**: ⏳ Uploading / Ready / Failed states
- **Send Button Logic**: Disabled until text OR attachments exist AND all uploads complete

### ✅ Phase 2: File Upload Pipeline
- **Upload Endpoint**: `POST /v1/uploads` (multipart/form-data)
- **Response Format**:
  ```json
  {
    "upload_id": "uuid",
    "original_filename": "image.jpg",
    "stored_filename": "uuid.jpg", 
    "file_path": "/uploads/uuid.jpg",
    "file_size": 1024000,
    "mime_type": "image/jpeg",
    "thumbnail_path": "/uploads/thumbnails/uuid_thumb.jpg"
  }
  ```
- **Backend Behavior**: Saves file → Inserts into `file_uploads` → Returns upload_id
- **Frontend Lifecycle**: `selected → uploading → uploaded → readyToSend → committed`

### ✅ Phase 3: Message Send (Atomic with Attachments)
- **Message Commit Endpoint**: `POST /v1/conversations/{conversationId}/messages`
- **Request Body**:
  ```json
  {
    "content": "Check out this image!",
    "type": "mixed",
    "upload_ids": ["uuid1", "uuid2"],
    "client_message_id": "client-uuid"
  }
  ```
- **Atomic Transaction**: 
  1. Validate upload_ids exist in `file_uploads`
  2. Start DB transaction
  3. Insert message row
  4. Insert into `message_attachments`
  5. Mark uploads as used
  6. Commit transaction
  7. Broadcast via WebSocket
- **Failure Handling**: Any step fails → rollback everything

### ✅ Phase 4: Voice Notes Pipeline
- **Frontend**: Record → Preview waveform → Upload → Ready-to-send → Message commit
- **Backend**: Voice uploads go through `/v1/uploads`, then during commit:
  ```sql
  INSERT INTO voice_messages(message_id, file_path, duration_seconds, waveform_data, transcript, file_size)
  ```

### ✅ Phase 5: Real-time Delivery (No Refresh)
- **WebSocket Broadcast**:
  ```json
  {
    "type": "message.created",
    "payload": {
      "id": "server-uuid",
      "conversation_id": "conv-uuid", 
      "sender_id": "user-uuid",
      "content": "Check out this image!",
      "type": "mixed",
      "attachments": [
        {
          "id": "1",
          "original_filename": "image.jpg",
          "file_path": "/uploads/uuid.jpg",
          "mime_type": "image/jpeg",
          "thumbnail_path": "/uploads/thumbnails/uuid_thumb.jpg",
          "file_size": 1024000
        }
      ],
      "voice": null,
      "created_at": "2024-01-01T00:00:00Z"
    },
    "timestamp": 1704067200000
  }
  ```
- **Frontend**: Renders immediately, never requires REST refresh, never polls

### ✅ Phase 6: Data Integrity Guarantees
- **Upload Cleanup**: Auto-cleanup expired uploads after TTL
- **Message-Attachment Consistency**: Forbidden to have message without attachment rows
- **Voice Message Integrity**: Forbidden to have voice message without row
- **No Duplicates**: Forbidden to duplicate attachments or messages

### ✅ Phase 7: Failure Handling
- **Upload Fails**: Preview tile shows error + retry button
- **User Deletes Attachment**: Upload canceled + removed from UI
- **Network Drop**: Upload resumes when connection restored
- **WS Reconnect**: Fetches missed messages
- **Send Retry**: No duplicate rows due to idempotency

## 🗂️ Database Schema

### file_uploads
```sql
CREATE TABLE file_uploads (
  id TEXT PRIMARY KEY,
  original_filename TEXT NOT NULL,
  stored_filename TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type TEXT NOT NULL,
  uploaded_by TEXT NOT NULL,
  is_public BOOLEAN DEFAULT FALSE,
  download_count INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
```

### message_attachments
```sql
CREATE TABLE message_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id TEXT NOT NULL,
  filename TEXT NOT NULL,
  original_filename TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type TEXT NOT NULL,
  thumbnail_path TEXT,
  metadata TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);
```

### voice_messages
```sql
CREATE TABLE voice_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  waveform_data TEXT,
  transcript TEXT,
  file_size BIGINT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);
```

## 🧪 Testing

### End-to-End Tests
- **Image Attachment Flow**: Complete flow from selection to delivery
- **Voice Recording Flow**: Record → preview → send → receive
- **Multiple Attachments**: Add, remove, send multiple files
- **Attachment Removal**: Remove before sending, verify UI updates
- **Upload Failures**: Network failures, retry mechanisms

### Running Tests
```bash
# Run integration tests
flutter test integration_test/attachment_pipeline_test.dart

# Run all tests
flutter test
```

## 🚀 Deployment

### Environment Setup
1. **Database**: Run attachment schema migrations
   ```sql
   -- Execute database/attachment_schema.sql
   ```

2. **File Storage**: Ensure uploads directory exists
   ```bash
   mkdir -p uploads
   mkdir -p uploads/thumbnails
   chmod 755 uploads
   ```

3. **Environment Variables**:
   ```env
   UPLOAD_MAX_SIZE=50MB
   UPLOAD_ALLOWED_TYPES=image/*,application/pdf,text/*
   UPLOAD_EXPIRY_HOURS=24
   ```

### Server Startup
```bash
cd backend
dart bin/server.dart
```

### Frontend Setup
```bash
cd frontend
flutter pub get
flutter run
```

## 🔧 Configuration

### Upload Limits
- **Max File Size**: 50MB (configurable)
- **Allowed Types**: Images, PDFs, documents, audio files
- **Expiry**: 24 hours for unused uploads

### Security
- **Authentication**: All endpoints require valid JWT
- **Authorization**: Users can only upload to their own conversations
- **File Validation**: MIME type verification, virus scanning (future)

## 📊 Monitoring

### Data Integrity Service
- **Periodic Cleanup**: Runs every hour
- **Orphaned File Detection**: Removes files without message references
- **Expired Upload Cleanup**: Removes unused expired uploads
- **Statistics**: Tracks upload/attachment metrics

### Health Checks
```bash
# Check system integrity
curl http://localhost:8080/v1/health/integrity

# Get statistics
curl http://localhost:8080/v1/stats/uploads
```

## 🐛 Troubleshooting

### Common Issues

1. **Uploads Stuck at "Uploading"**
   - Check network connectivity
   - Verify server upload endpoint is accessible
   - Check browser console for errors

2. **Attachments Not Showing**
   - Verify database schema is applied
   - Check file permissions on uploads directory
   - Review server logs for errors

3. **Real-time Delivery Not Working**
   - Verify WebSocket connection is established
   - Check message broadcasting in server logs
   - Ensure client is subscribed to conversation

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=debug
dart bin/server.dart
```

## 🔄 Migration from Old System

### Breaking Changes
- **Old Attachment Format**: No longer supported
- **Direct File URLs**: Replaced with upload_id system
- **Optimistic Rendering**: Disabled for attachments (must upload first)

### Migration Steps
1. **Backup**: Backup existing data
2. **Schema Update**: Apply new attachment schema
3. **Data Migration**: Convert existing attachments to new format
4. **Code Update**: Update frontend to use new attachment system
5. **Testing**: Verify all attachment flows work

## 📚 API Reference

### Upload Endpoints

#### POST /v1/uploads
Upload a file with multipart form data.

**Request:**
```
Content-Type: multipart/form-data
file: [binary data]
```

**Response:**
```json
{
  "success": true,
  "upload_id": "uuid",
  "original_filename": "file.jpg",
  "stored_filename": "uuid.jpg",
  "file_path": "/uploads/uuid.jpg",
  "file_size": 1024000,
  "mime_type": "image/jpeg",
  "thumbnail_path": "/uploads/thumbnails/uuid_thumb.jpg"
}
```

#### POST /v1/uploads/signed-url
Get a signed URL for direct upload.

**Request:**
```json
{
  "filename": "file.jpg",
  "mime": "image/jpeg",
  "size": 1024000
}
```

**Response:**
```json
{
  "success": true,
  "upload_id": "uuid",
  "upload_url": "https://storage.example.com/signed-url",
  "expires_at": "2024-01-01T01:00:00Z"
}
```

### Message Endpoints

#### POST /v1/conversations/{id}/messages
Send a message with attachments.

**Request:**
```json
{
  "content": "Message text",
  "type": "mixed",
  "upload_ids": ["uuid1", "uuid2"],
  "client_message_id": "client-uuid"
}
```

**Response:**
```json
{
  "success": true,
  "message": {
    "id": "server-uuid",
    "conversation_id": "conv-uuid",
    "sender_id": "user-uuid",
    "content": "Message text",
    "type": "mixed",
    "attachments": [...],
    "voice": null,
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

## 🎉 Success Criteria

✅ **Complete System Functionality**
- Users can select, preview, and remove attachments before sending
- Upload progress is clearly visible with cancel options
- Send button is disabled until all attachments are ready
- Messages are created atomically with proper attachment binding
- Real-time delivery works without page refresh
- Data integrity is maintained with automatic cleanup

✅ **No Regressions**
- All existing text messaging functionality works
- Performance is not degraded
- Security is maintained
- Error handling is robust

✅ **Quality Assurance**
- All flows are covered by integration tests
- Code follows project standards
- Documentation is complete
- Monitoring and debugging tools are available

This attachment system now provides a complete, reliable, and user-friendly file sharing experience that meets all the specified requirements.
