#!/bin/bash
set -e

# Ralph AFK - fully autonomous loop (zero human-in-the-loop)
# Implements frontend (SwiftUI) AND backend (Go) as needed
# Usage: ./afk-ralph.sh <iterations>

PROJECT_DIR="/Users/jperrama/Developer/iOS_Swift_Applications/Focus"
BACKEND_DIR="/Users/jperrama/Developer/iOS_Swift_Applications/Focus_backend/firelevel-backend"
SCHEME="Focus"
SIMULATOR="iPhone 16 Pro"
SCREENSHOT_DIR="/tmp/ralph-screenshots"

mkdir -p "$SCREENSHOT_DIR"

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

# Ensure simulator is booted
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
echo "Simulator '$SIMULATOR' ready."

for ((i=1; i<=$1; i++)); do
  echo "=== Ralph iteration $i/$1 ==="

  result=$(claude --permission-mode acceptEdits -p "@PRD.md @progress.txt \
  You are Ralph, a fully autonomous coding agent. Zero human-in-the-loop. \
  You implement frontend (SwiftUI) AND backend (Go) as needed. \
  \
  WORKFLOW: \
  1. Read the PRD and progress.txt. Find the next incomplete task. \
  2. Read the corresponding design screenshot from design/ folder (PNG files). \
  3. Implement it in SwiftUI to match the design exactly (colors, spacing, fonts, layout). \
  4. If the frontend feature needs a backend endpoint that does not exist yet: \
     a. Navigate to $BACKEND_DIR \
     b. Create or update the handler in internal/<module>/handler.go \
     c. Follow the existing pattern: Handler struct + NewHandler(db *pgxpool.Pool) \
     d. Register the route in cmd/api/main.go \
     e. If a new table is needed, add the migration to migrations_v2.sql (with RLS policy) \
     f. Build and verify: cd $BACKEND_DIR && go build ./cmd/api/ \
     g. If build fails, fix and rebuild until it compiles \
     h. Commit backend changes separately: cd $BACKEND_DIR && git add -A && git commit -m 'feat: <description>' \
     i. Push backend: cd $BACKEND_DIR && git push \
     j. Return to $PROJECT_DIR and continue frontend implementation \
  5. Build frontend: xcodebuild -project Focus.xcodeproj -scheme $SCHEME -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$SIMULATOR' build 2>&1 | tail -20 \
  6. If build fails, fix and rebuild until it compiles. \
  6b. After successful build, install and launch the app on the simulator: \
      xcrun simctl install booted \$(find ~/Library/Developer/Xcode/DerivedData -name 'Focus.app' -path '*/Debug-iphonesimulator/*' | head -1) \
      xcrun simctl launch booted com.jep.volta \
      Sleep 2 seconds to let the app start. \
  7. Open the deep link for this screen: xcrun simctl openurl booted <deep_link> \
  8. Wait 3 seconds, then screenshot: xcrun simctl io booted screenshot $SCREENSHOT_DIR/review.png \
  9. Read $SCREENSHOT_DIR/review.png and compare with the design from design/. \
  10. If the implementation does not match the design, fix and repeat from step 5. Max 3 retries. \
  11. Commit frontend changes: cd $PROJECT_DIR && git add -A && git commit -m 'feat: <description>' \
  12. Update progress.txt with what you did (task name, status, any backend work done). \
  \
  BACKEND PATTERNS (Go + Chi Router + pgx): \
  - Handler struct: type Handler struct { db *pgxpool.Pool } \
  - Constructor: func NewHandler(db *pgxpool.Pool) *Handler { return &Handler{db: db} } \
  - Auth: userID := r.Context().Value(auth.UserContextKey).(string) \
  - JSON response: w.Header().Set(\"Content-Type\", \"application/json\"); json.NewEncoder(w).Encode(data) \
  - Upsert: INSERT ... ON CONFLICT ... DO UPDATE SET ... RETURNING ... \
  - Logging: fmt.Printf with emoji prefixes \
  - All tables need RLS: ALTER TABLE ... ENABLE ROW LEVEL SECURITY; CREATE POLICY ... \
  \
  RULES: \
  - ONLY WORK ON A SINGLE TASK per iteration. \
  - Always commit backend and frontend separately. \
  - Never break existing endpoints or views. \
  - If a task is blocked, skip it and move to the next one. Note the blocker in progress.txt. \
  - NEVER mark a task as DONE without doing the full build + install + launch + screenshot + visual comparison loop. \
  - NEVER trust progress.txt status alone. You MUST visually verify every screen yourself. \
  - If progress.txt says NEEDS REWORK, you MUST fix and visually verify before marking DONE. \
  \
  Deep links available: \
    focus://login - Landing/login page \
    focus://onboarding - Onboarding flow \
    focus://chat - Main chat screen \
    focus://settings - Settings page \
    focus://settings/notifications - Notification settings \
    focus://settings/appblocker - App blocker settings \
    focus://firemode - FireMode session \
    focus://endofday - Evening review \
    focus://calendar - Calendar \
    focus://weekly-goals - Weekly goals \
    focus://paywall - Paywall / subscription screen \
  If the PRD is complete, output <promise>COMPLETE</promise>.")

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "PRD complete after $i iterations."
    exit 0
  fi
done

echo "Completed $1 iterations. PRD may not be fully complete."
