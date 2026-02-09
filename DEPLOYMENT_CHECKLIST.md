## Production Deployment & Validation Checklist

### ✅ Pre-Deployment Verification

Before deploying to production or staging, execute these validation steps:

#### 1. Environment Configuration
```bash
# Ensure .env file exists with required variables (should NOT be committed to git)
cat .env

# Verify these variables are set:
# - DB_HOST (not localhost for production)
# - DB_PORT (typically 3306)
# - DB_USER
# - DB_PASSWORD (use strong password)
# - DB_NAME (fs_hub_db or similar)
# - JWT_SECRET (strong random secret, minimum 32 chars)
# - PORT (server port, default 8080)
```

#### 2. Generate Strong JWT Secret
```bash
# Run this to generate a cryptographically secure random secret:
dart -e "import 'dart:convert'; import 'dart:math'; print('JWT_SECRET=' + base64Url.encode(List<int>.generate(32, (i) => Random().nextInt(256))).replaceAll('=', ''));"

# Copy output to .env file
```

#### 3. Database Migration Verification
```bash
# Connect to MySQL and verify schema:
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME

# In MySQL, verify these critical tables exist:
SHOW TABLES LIKE 'users';
SHOW TABLES LIKE 'refresh_tokens';
SHOW TABLES LIKE 'conversations';
SHOW TABLES LIKE 'messages';

# Verify refresh_tokens table structure:
DESCRIBE refresh_tokens;
# Should have: id, user_id, token, revoked, expires_at, created_at
```

#### 4. Backend Server Startup
```bash
# From repo root, start the backend:
cd backend
dart pub get
dart run bin/server.dart

# Expected output:
# ✓ Database configuration loaded
# ✓ Database already initialized; skipping migrations (OR Database migrations completed successfully on first run)
# ✓ Server listening on port 8080
# ✓ Visit: http://localhost:8080
```

#### 5. Authentication Flow Test
```bash
# Test login endpoint (create a test user first via direct DB or provisioning script)
curl -X POST http://localhost:8080/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'

# Expected response:
# {
#   "success": true,
#   "message": "Login successful",
#   "data": {
#     "accessToken": "eyJ...",
#     "refreshToken": "eyJ...",
#     "user": { ... }
#   }
# }

# Test refresh endpoint
curl -X POST http://localhost:8080/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"REFRESH_TOKEN_FROM_LOGIN"}'

# Expected: new accessToken and refreshToken issued
```

#### 6. WebSocket Authentication Test
```bash
# Get an access token (from login above)
TOKEN="<access_token_from_login>"

# Test WebSocket connection with token in path
wscat -c ws://localhost:8080/ws/chat/$TOKEN

# Expected: connection established, receive welcome message:
# {"type":"connected","data":{"userId":"...","connectionId":"..."},"timestamp":...}
```

#### 7. API Versioning Verification
```bash
# Verify all endpoints are accessible at /v1/ prefix:
curl http://localhost:8080/v1/auth/profile \
  -H "Authorization: Bearer $TOKEN"

curl http://localhost:8080/v1/employees/ \
  -H "Authorization: Bearer $TOKEN"

curl http://localhost:8080/v1/conversations/ \
  -H "Authorization: Bearer $TOKEN"

# All should return 200 OK (or 401 if auth fails, not 404)
```

#### 8. Message Delivery Contract Test
```bash
# After WebSocket connection established, send a message:
# (via WebSocket):
{"type":"message","data":{"conversationId":"1","content":"test","type":"text"}}

# Expected response (matching aligned contract):
# {"type":"message:created","payload":{"message":{...}},"timestamp":...}
```

---

### 🔒 Security Validation

- [ ] JWT_SECRET is NOT hardcoded in source (✓ uses environment)
- [ ] Plaintext password removed from schema.sql (✓ removed)
- [ ] Initial admin account NOT in schema (✓ removed)
- [ ] WebSocket requires JWT token (✓ /ws/chat/<token> implemented)
- [ ] All routes protected by authentication (✓ enforced)
- [ ] Refresh tokens persisted in DB (✓ refresh_tokens table)
- [ ] Logout revokes refresh tokens (✓ AuthService.logout implemented)
- [ ] CORS restricted in production (✓ verify in server.dart)

---

### 🔧 Database & Concurrency Validation

- [ ] Single DB connection pooling issue FIXED (✓ per-execute proxy pattern)
- [ ] Migrations are safe and idempotent (✓ guard check added)
- [ ] Concurrent requests don't block (✓ each gets own connection)
- [ ] No stale connections (✓ closed auto in proxy)

---

### 📨 REST ↔ WebSocket Contract Validation

- [ ] API base paths use /v1 (✓ all services updated)
- [ ] Message endpoint: POST /conversations/{id}/messages (✓ aligned)
- [ ] WebSocket event: message:created (✓ correct type)
- [ ] Typing event: includes state: 'typing'|'stopped' (✓ converted)
- [ ] All payloads use 'payload' or 'data' consistently (✓ payload for WS)

---

### 🚀 Deployment Commands

**Development / Testing:**
```bash
# Terminal 1: Backend
cd backend && dart run bin/server.dart

# Terminal 2: Frontend (if applicable)
flutter run -d chrome  # or appropriate device
```

**Production Deploy (Dockerfile):**
```bash
# Build backend image
docker build -f backend/Dockerfile -t fshub-backend:latest backend/

# Run with .env mounted
docker run -p 8080:8080 \
  --env-file .env \
  fshub-backend:latest
```

**Production Deploy (Raw Dart):**
```bash
# Build release
cd backend && dart compile exe bin/server.dart -o bin/server_release

# Run with env
export JWT_SECRET=<strong_secret>
export DB_HOST=<prod_db_host>
...
./bin/server_release
```

---

### 📋 Post-Deployment Smoke Tests

After deployment to production/staging:

1. **Health Check**
   - [ ] Server responds on port 8080
   - [ ] No startup errors in logs

2. **Authentication**
   - [ ] Login with valid credentials succeeds
   - [ ] Login with invalid credentials returns 401
   - [ ] Logout revokes token (refresh fails after logout)
   - [ ] Token refresh extends session

3. **Real-Time Messaging**
   - [ ] WebSocket connects with valid token
   - [ ] Message sent via WS appears in UI
   - [ ] Messages persist in database
   - [ ] Typing indicator broadcasts

4. **Database**
   - [ ] Refresh token stored on login
   - [ ] Refresh token revoked on logout
   - [ ] No connection timeouts under load
   - [ ] Concurrent users can send messages simultaneously

---

### 🐛 Troubleshooting

**"Database not initialized" error**
- Verify DB_HOST, DB_USER, DB_PASSWORD are correct
- Check MySQL is running and accessible
- Verify .env file is loaded

**"Unauthorized" on WebSocket**
- Check token is not expired
- Verify JWT_SECRET matches between frontend and backend
- Check token is passed in path: ws://host:port/ws/chat/<token>

**"404 on /v1/... endpoints"**
- Verify backend routes are mounted with /v1 prefix (✓ already done)
- Check server is on port 8080
- Verify frontend base URL is http://localhost:8080/v1

**"Messages not appearing in UI"**
- Check WebSocket event names match (message:created, not message)
- Verify payload structure: {"type":"message:created","payload":{"message":{...}}}
- Check browser console for JS errors

