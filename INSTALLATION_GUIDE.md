# FS Hub Chat System - Installation Guide

## Overview
Premium enterprise chat system with iOS-style glassmorphism UI, real-time messaging, file sharing, and voice messages.

## Features
- ✅ One-to-one and group conversations
- ✅ Real-time messaging with WebSocket
- ✅ File sharing (images, documents, videos)
- ✅ Voice messages with waveform visualization
- ✅ Message reactions and read receipts
- ✅ Typing indicators and presence
- ✅ Glassmorphism UI design
- ✅ Production-ready backend

## Backend Setup

### 1. Database Schema
```bash
# Run the chat schema SQL
mysql -u root -p fs_hub_db < backend/lib/chat_schema.sql
```

### 2. Install Dependencies
```bash
cd backend
dart pub get
```

### 3. Configure Environment
Create `backend/.env`:
```env
# Database Configuration
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=admin
DB_NAME=fs_hub_db

# SMTP Configuration for Email Service
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-actual-gmail@gmail.com
SMTP_PASSWORD=your-gmail-app-password
SMTP_FROM_EMAIL=your-actual-gmail@gmail.com
SMTP_FROM_NAME=FS Hub Support
EMAIL_ENABLED=true
```

### 4. Start Backend Server
```bash
dart run bin/server.dart
```

## Frontend Setup

### 1. Install Dependencies
```bash
cd fs_hub
flutter pub get
```

### 2. Add Required Packages
Add to `pubspec.yaml`:
```yaml
dependencies:
  web_socket_channel: ^2.4.0
  record: ^5.0.4
  path_provider: ^2.1.1
  file_picker: ^6.1.1
  http: ^1.1.0
  flutter_dotenv: ^5.1.0
```

### 3. Update App Routes
Add to your main router:
```dart
import '../routes/chat_routes.dart';

// In your router setup
onGenerateRoute: ChatRoutes.generateRoute,
```

### 4. Add Navigation
Add chat navigation to your app:
```dart
// Example navigation
Navigator.pushNamed(context, '/chat');
Navigator.pushNamed(context, '/chat/create-group');
```

## Database Tables Created

### Core Tables
- `conversations` - Chat conversations (direct/group)
- `conversation_members` - Conversation membership
- `messages` - Chat messages
- `message_attachments` - File attachments
- `message_reads` - Read receipts
- `message_reactions` - Message reactions
- `typing_events` - Typing indicators
- `file_uploads` - File management
- `voice_messages` - Voice message metadata

### Enhanced User Table
```sql
ALTER TABLE users ADD COLUMN last_seen DATETIME NULL;
ALTER TABLE users ADD COLUMN is_online BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500) NULL;
```

## API Endpoints

### Chat REST API
- `GET /chat/conversations` - List conversations
- `POST /chat/conversations` - Create conversation
- `GET /chat/conversations/{id}/messages` - Get messages
- `POST /chat/conversations/{id}/messages` - Send message
- `POST /chat/messages/{id}/read` - Mark as read
- `POST /chat/messages/{id}/reactions` - Add reaction
- `POST /chat/upload` - Upload file

### WebSocket Events
- `connection_established` - WebSocket connected
- `new_message` - New message received
- `message_read` - Message marked as read
- `typing_indicator` - User typing status
- `presence_update` - User online status
- `message_reaction` - Message reaction added

## UI Components

### Core Widgets
- `GlassMessageBubble` - Premium message display
- `GlassComposeBar` - Message input with voice recording
- `ChatListPage` - Conversation list
- `ChatConversationPage` - Chat thread view
- `CreateGroupPage` - Group creation

### Design System
- Glassmorphism effects with backdrop filters
- Gold accent colors (#D4AF37)
- Compact typography
- Smooth animations
- Executive-grade UX

## File Storage

### Upload Directory Structure
```
backend/
├── uploads/
│   ├── images/
│   ├── documents/
│   ├── audio/
│   └── videos/
```

### File Handling
- MIME type validation
- Size limits (10MB default)
- Secure file access
- Thumbnail generation for images
- Waveform generation for audio

## Voice Messages

### Recording Features
- Press-and-hold recording
- Visual waveform display
- Duration tracking
- Audio compression
- Playback controls

### Audio Format
- WAV format for compatibility
- 44.1kHz sample rate
- 128kbps bitrate
- Automatic upload after recording

## Real-time Features

### WebSocket Connection
```dart
// Connect to chat service
await ChatService.connect(userId);

// Listen for events
ChatService.events.listen((event) {
  switch (event.type) {
    case 'new_message':
      // Handle new message
      break;
    case 'typing_indicator':
      // Handle typing indicator
      break;
  }
});
```

### Typing Indicators
- Automatic typing detection
- 3-second timeout
- Multi-user support
- Real-time broadcast

## Security Features

### Authentication
- JWT token validation
- User authorization checks
- Conversation membership verification
- File access control

### Data Protection
- Message encryption at rest
- Secure file uploads
- Rate limiting
- Input validation

## Performance Optimization

### Database Indexing
- Conversation lookups
- Message pagination
- User presence queries
- File metadata searches

### Caching Strategy
- Conversation list caching
- User presence caching
- File metadata caching
- WebSocket connection pooling

## Testing

### Backend Tests
```bash
cd backend
dart test
```

### Frontend Tests
```bash
cd fs_hub
flutter test
```

## Deployment

### Production Environment Variables
```env
DB_HOST=your-production-db-host
DB_PASSWORD=your-secure-password
SMTP_USERNAME=your-production-email
SMTP_PASSWORD=your-production-app-password
```

### Docker Deployment
```dockerfile
FROM dart:stable
WORKDIR /app
COPY . .
RUN dart pub get
RUN dart run bin/server.dart
EXPOSE 8080
```

## Troubleshooting

### Common Issues

#### WebSocket Connection Failed
- Check backend server is running
- Verify port 8080 is accessible
- Check CORS configuration

#### File Upload Not Working
- Verify uploads directory exists
- Check file permissions
- Validate MIME type configuration

#### Voice Recording Issues
- Check microphone permissions
- Verify record package installation
- Test audio codec support

#### Database Connection Errors
- Verify MySQL is running
- Check database credentials
- Validate schema exists

### Debug Mode
Enable debug logging:
```dart
// In development
ChatService.events.listen((event) {
  print('Chat Event: ${event.type}');
  print('Data: ${event.data}');
});
```

## Support

For issues and questions:
1. Check console logs for errors
2. Verify database schema is applied
3. Test backend endpoints separately
4. Check WebSocket connection status

## Next Steps

### Advanced Features
- End-to-end encryption
- Message threading
- Video calling integration
- Advanced search
- Message scheduling
- Bot integration

### Scaling
- Redis for session management
- Load balancing
- Database sharding
- CDN for file storage
- Microservices architecture
