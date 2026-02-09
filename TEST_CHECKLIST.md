# Quick Test Checklist - Real-Time Message Delivery

**Date**: ___________  
**Tester**: ___________  
**Status**: [ ] PASS  [ ] FAIL

---

## Pre-Test Setup

- [ ] Backend running on port 8080
- [ ] User A logged in on Device/Browser A
- [ ] User B logged in on Device/Browser B
- [ ] Both opened same conversation
- [ ] Debug console visible in VS Code / Android Studio

---

## Test 1: User A Sends Message

**Action**: User A types "Test message from A" and taps SEND

**Expected Results (Immediate)**:
- [ ] Message appears on A's screen instantly
- [ ] Message shows "sending" state briefly
- [ ] Message updates to "sent" state

**Expected Results (< 1 second)**:
- [ ] Message appears on B's screen
- [ ] Message shows sender's name (User A)
- [ ] B did NOT need to refresh page

**Console Checks**:
- [ ] See `[CTRL] sendMessage:` in console
- [ ] See `[REST] Response status: 200`
- [ ] See `[WS-RECV] Received event type=message:created`
- [ ] See `[CTRL] Has conversation in store: true` ✅ **CRITICAL**

**Result**: [ ] PASS  [ ] FAIL  

**Notes**: _________________________________________________

---

## Test 2: User B Replies

**Action**: User B types "Reply from B" and taps SEND

**Expected Results (Immediate)**:
- [ ] Message appears on B's screen instantly
- [ ] Message shows sender's name (User B)

**Expected Results (< 1 second)**:
- [ ] Message appears on A's screen
- [ ] A did NOT need to refresh page

**Console Checks**:
- [ ] See `[CTRL] sendMessage:` in console
- [ ] See `[REST] Response status: 200`
- [ ] See `[CTRL] Has conversation in store: true` ✅ **CRITICAL**

**Result**: [ ] PASS  [ ] FAIL

**Notes**: _________________________________________________

---

## Test 3: Rapid Messages (Optional)

**Action**: User A sends 5 messages in 5 seconds

**Expected Results**:
- [ ] All 5 appear on B instantly
- [ ] All in correct order (1, 2, 3, 4, 5)
- [ ] No duplicates
- [ ] No missing messages

**Result**: [ ] PASS  [ ] FAIL

**Notes**: _________________________________________________

---

## Test 4: Refresh Persistence (Optional)

**Action**: User B refreshes page, returns to conversation

**Expected Results**:
- [ ] All messages still visible
- [ ] Message count unchanged
- [ ] No messages lost

**Result**: [ ] PASS  [ ] FAIL

**Notes**: _________________________________________________

---

## Critical Log Pattern to Verify

Look for this exact pattern in the debug console:

```
[CTRL] sendMessage: "Test message..."
[REST] Sending message: conversationId=... clientMsgId=...
[REST] Response status: 200
[REST] Message created: serverId=...

[WS-RECV] Received event type=message:created
[REPO] MessageCreatedEvent received: id=...
[CTRL] messageUpdated stream: id=...
[CTRL] Has conversation in store: true     ← CHECK THIS!
[CTRL] Adding new message
[CTRL] Current conversation updated
```

If you see:
```
[CTRL] Has conversation in store: false    ← BUG DETECTED!
```

Then the message was dropped and the bug still exists.

---

## Overall Result

| Test | Result | Notes |
|------|--------|-------|
| Test 1: A sends | ☐ PASS ☐ FAIL | |
| Test 2: B replies | ☐ PASS ☐ FAIL | |
| Test 3: Rapid (opt) | ☐ PASS ☐ FAIL | |
| Test 4: Refresh (opt) | ☐ PASS ☐ FAIL | |

---

## Final Assessment

**All Tests Passed?**
- [ ] YES → Fix is working ✅
- [ ] NO → Bug still exists ❌

**Immediate Feedback**:
- Did you see messages appear instantly on receiver?
- Did you see "Has conversation in store: true" in logs?
- Did you need to manually refresh to see messages?

**Issues Encountered**:
_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

---

**Signature**: ___________________  
**Date/Time**: ___________________  
**Next Steps**: [ ] Deploy to staging  [ ] Investigate further
