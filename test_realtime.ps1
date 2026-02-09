# Real-Time Message Delivery - Local Test Setup (Windows/PowerShell)
# Fixed version - simple direct output

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Real-Time Message Delivery - Local Test Setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if backend directory exists
if (-not (Test-Path "backend")) {
    Write-Host "ERROR: backend directory not found" -ForegroundColor Red
    Write-Host "Please run this script from the FS Hub project root" -ForegroundColor Red
    exit 1
}

Write-Host "Step 1: Starting Backend..." -ForegroundColor Blue
Write-Host "-----" -ForegroundColor Blue

Push-Location backend

# Check if pubspec.yaml exists
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "ERROR: backend/pubspec.yaml not found" -ForegroundColor Red
    exit 1
}

# Get dependencies
Write-Host "Installing dependencies..."
& dart pub get

# Run server in background
Write-Host "Starting server on port 8080..."
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = "dart"
$processInfo.Arguments = "run bin/server.dart"
$processInfo.WorkingDirectory = (Get-Location).Path
$processInfo.UseShellExecute = $true
$processInfo.CreateNoWindow = $false

$backendProcess = [System.Diagnostics.Process]::Start($processInfo)
$backendPID = $backendProcess.Id

# Wait for server to start
Start-Sleep -Seconds 3

Write-Host "Backend started (PID: $backendPID)" -ForegroundColor Green
Write-Host ""

Pop-Location

Write-Host "Step 2: Frontend Setup" -ForegroundColor Blue
Write-Host "-----" -ForegroundColor Blue
Write-Host "The backend is running on http://localhost:8080" -ForegroundColor White
Write-Host ""

Write-Host "Step 3: Test Instructions" -ForegroundColor Blue
Write-Host "=====================================================" -ForegroundColor Blue
Write-Host ""

Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open TWO new PowerShell windows" -ForegroundColor White
Write-Host ""
Write-Host "2. In FIRST window (User A):" -ForegroundColor White
Write-Host "   cd c:\Users\salma\StudioProjects\fs_hub" -ForegroundColor Cyan
Write-Host "   flutter run" -ForegroundColor Cyan
Write-Host "   [Wait for app to load, then log in as USER A]" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. In SECOND window (User B):" -ForegroundColor White
Write-Host "   cd c:\Users\salma\StudioProjects\fs_hub" -ForegroundColor Cyan
Write-Host "   flutter run" -ForegroundColor Cyan
Write-Host "   [Wait for app to load, then log in as USER B]" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. THE CRITICAL TEST:" -ForegroundColor Yellow
Write-Host "   --- Both users open SAME conversation ---" -ForegroundColor White
Write-Host "   --- User A types: 'Test from A' and sends ---" -ForegroundColor White
Write-Host ""
Write-Host "   IMMEDIATE CHECK (within 1 second):" -ForegroundColor Cyan
Write-Host "   Does User B see the message?" -ForegroundColor White
Write-Host "   - If YES without refreshing = FIX WORKS!" -ForegroundColor Green
Write-Host "   - If NO or requires refresh = BUG STILL EXISTS" -ForegroundColor Red
Write-Host ""
Write-Host "5. CHECK THE DEBUG CONSOLE:" -ForegroundColor Yellow
Write-Host "   Look for this log line on User B side:" -ForegroundColor White
Write-Host "   [CTRL] Has conversation in store: true" -ForegroundColor Green
Write-Host ""
Write-Host "   If you see FALSE instead:" -ForegroundColor Red
Write-Host "   [CTRL] Has conversation in store: false" -ForegroundColor Red
Write-Host "   Then the message was dropped (bug exists)" -ForegroundColor Red
Write-Host ""
Write-Host "6. TEST COMPLETE WHEN:" -ForegroundColor Yellow
Write-Host "   Both users can send/receive messages instantly" -ForegroundColor Green
Write-Host "   No refresh needed for new messages to appear" -ForegroundColor Green
Write-Host "   Logs show 'Has conversation in store: true'" -ForegroundColor Green
Write-Host ""

Write-Host "=====================================================" -ForegroundColor Blue
Write-Host ""

Write-Host "Backend Status:" -ForegroundColor Cyan
Write-Host "  Status: RUNNING" -ForegroundColor Green
Write-Host "  URL: http://localhost:8080" -ForegroundColor White
Write-Host "  PID: $backendPID" -ForegroundColor White
Write-Host ""

Write-Host "KEEP THIS WINDOW OPEN - Backend must stay running!" -ForegroundColor Yellow
Write-Host "Close this window or press Ctrl+C when done testing" -ForegroundColor Yellow
Write-Host ""

# Wait for backend to finish
$backendProcess.WaitForExit()

Write-Host "Backend stopped." -ForegroundColor Yellow

   • All visible without refresh

9. OPTIONAL: REFRESH PERSISTENCE TEST
   
   User B: Refresh the page/app (Ctrl+R or reload button)
   Expected Results:
   • All previous messages still visible
   • New messages still there
   • No data loss

FINAL RESULT:
=============

If all tests PASS:
✅ The fix is working correctly
✅ Messages deliver instantly via WebSocket
✅ No race condition race condition
✅ Ready for staging deployment

If any test FAILS:
❌ The bug still exists
❌ Need to investigate further
❌ Check logs for "Has conversation in store: false"
"@ | Out-File -FilePath "TEST_INSTRUCTIONS.txt" -Encoding UTF8

Write-Host (Get-Content "TEST_INSTRUCTIONS.txt") -ForegroundColor White
Write-Host ""

Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "⚠️  KEEP THIS POWERSHELL WINDOW OPEN" -ForegroundColor Yellow
Write-Host "The backend continues running in the background" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Backend PID: $backendPID" -ForegroundColor Green
Write-Host ""
Write-Host "When done testing, stop the backend with:" -ForegroundColor Cyan
Write-Host "  Stop-Process -Id $backendPID" -ForegroundColor White
Write-Host ""

Write-Host "Test instructions saved to: TEST_INSTRUCTIONS.txt" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Open two new terminal/command windows" -ForegroundColor White
Write-Host "2. In each, run: flutter run" -ForegroundColor White
Write-Host "3. Log in as different users (USER A and USER B)" -ForegroundColor White
Write-Host "4. Follow the test instructions" -ForegroundColor White
Write-Host "5. Watch the debug console for the logs" -ForegroundColor White
Write-Host ""

# Wait for user to stop the script
Write-Host "Press Ctrl+C to stop the backend when you're done testing" -ForegroundColor Yellow
Write-Host ""

# Keep the backend running until user terminates
$backendProcess.WaitForExit()
