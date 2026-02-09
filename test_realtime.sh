#!/bin/bash
# Real-Time Message Delivery - Local Test Setup
# This script starts the backend and provides instructions for testing

set -e

echo "================================================"
echo "Real-Time Message Delivery - Local Test Setup"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if backend directory exists
if [ ! -d "backend" ]; then
    echo "❌ ERROR: 'backend' directory not found"
    echo "Please run this script from the FS Hub project root"
    exit 1
fi

echo -e "${BLUE}Step 1: Starting Backend...${NC}"
echo "-----"
cd backend

# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ ERROR: backend/pubspec.yaml not found"
    exit 1
fi

# Get dependencies
echo "Installing dependencies..."
dart pub get

# Run server in background
echo "Starting server on port 8080..."
dart run bin/server.dart &
BACKEND_PID=$!

# Wait for server to start
sleep 3

# Check if server is running
if ! kill -0 $BACKEND_PID 2>/dev/null; then
    echo "❌ ERROR: Backend failed to start"
    exit 1
fi

echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"
echo ""

cd ..

echo -e "${BLUE}Step 2: Frontend Setup${NC}"
echo "-----"
echo "The backend is running on http://localhost:8080"
echo ""

echo -e "${BLUE}Step 3: Open Frontend in Two Separate Sessions${NC}"
echo "-----"

# Create macOS/Linux terminal instructions
cat > TEST_INSTRUCTIONS.txt << 'EOF'
================================================================
REAL-TIME MESSAGE DELIVERY - MANUAL TEST INSTRUCTIONS
================================================================

SETUP COMPLETE: Backend is running on port 8080

NOW DO THIS:

1. OPEN TWO TERMINAL WINDOWS

   Terminal A (User A):
   ├─ cd to project root
   ├─ Run: flutter run
   ├─ Wait for app to load
   └─ Log in as USER A

   Terminal B (User B):
   ├─ cd to project root  
   ├─ Run: flutter run -d "<device_id>" (or browser)
   ├─ Wait for app to load
   └─ Log in as USER B

2. BOTH USERS OPEN THE SAME CONVERSATION
   
   A: Navigate to conversation with USER B
   B: Navigate to conversation with USER A

3. CRITICAL TEST: A SENDS MESSAGE
   
   A: Type message: "Test message from A at $(date)"
   A: Hit SEND
   
   IMMEDIATE CHECK (within 500ms):
   ├─ A's screen: Message appears with YOUR OWN NAME (optimistic) ✓
   └─ B's screen: Message appears with USER A'S NAME (via WebSocket) ✓
   
   ❌ BUG SYMPTOM: B sees nothing - needs to refresh page
   ✅ FIX VERIFIED: B sees message instantly without refresh

4. SECOND TEST: B REPLIES
   
   B: Type message: "Test reply from B at $(date)"
   B: Hit SEND
   
   IMMEDIATE CHECK:
   ├─ B's screen: Message appears with B'S NAME (optimistic) ✓
   └─ A's screen: Message appears with B'S NAME (via WebSocket) ✓

5. CHECK THE LOGS
   
   Watch the DART CONSOLE for this pattern:
   
   For each message sent, you should see:
   
   [CTRL] sendMessage: "Test message..."
   [REST] Sending message: conversationId=... clientMsgId=...
   [REST] Response status: 200
   [REST] Message created: serverId=msg-... clientMsgId=...
   
   [WS-RECV] Received event type=message:created
   [REPO] MessageCreatedEvent received: id=msg-... convId=...
   [CTRL] messageUpdated stream: id=msg-... convId=...
   [CTRL] Has conversation in store: true  ← THIS IS THE FIX
   [CTRL] Adding new message
   [CTRL] Current conversation updated, notifying listeners

6. FAILURE DETECTION
   
   If you see:
   [CTRL] Has conversation in store: false
   
   → The bug still exists (message was dropped)
   → Try opening the conversation list and returning to the chat
   → If still fails, the fix didn't apply correctly

7. SUCCESS CRITERIA
   
   ✅ All tests pass if:
   • User A sends → appears on B instantly (no refresh)
   • User B replies → appears on A instantly (no refresh)
   • No messages appear twice
   • Logs show "Has conversation in store: true"
   • Console shows no ERROR messages

8. RAPID MESSAGE TEST (Optional)
   
   User A: Send 5 messages rapidly (1 per second)
   Expected: All appear on B instantly, in order, no duplicates

9. REFRESH TEST
   
   User B: Refresh the page/app
   Expected: All messages still visible, none lost

STATUS:
--------
✅ PASS: All messages appear instantly without refresh
❌ FAIL: Any message requires page refresh

If PASS: Fix is working correctly ✓
If FAIL: Report details to development team
EOF

cat TEST_INSTRUCTIONS.txt

echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Keep this terminal running${NC}"
echo "The backend will continue running in the background"
echo ""
echo "When you're done testing, stop the backend with:"
echo "  kill $BACKEND_PID"
echo ""
echo -e "${GREEN}Backend PID: $BACKEND_PID${NC}"
echo ""

# Keep the script running
wait
