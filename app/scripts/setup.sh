#!/bin/sh
# One-time setup for building BakeOut.
#
#   sh app/scripts/setup.sh            # from the repo root (or anywhere)
#   sh app/scripts/setup.sh --refresh  # redo both steps, replacing your local files
#
# 1. Firebase config: pulls the iOS, Android and Web app settings from the Firebase
#    project and writes lib/firebase_options.dart from them. Needs the Firebase CLI,
#    logged in (`firebase login`) with an account that's a member of the project.
# 2. Signing (macOS only): writes ios/Flutter/Signing.xcconfig with your own Apple
#    team, found from Xcode > Settings > Accounts. Override with TEAM=XXXXXXXXXX and
#    BUNDLE_ID=com.you.bakeout.
#
# All three files are git-ignored; everyone keeps their own.
set -eu

APP_DIR=$(cd "$(dirname "$0")/.." && pwd)
ROOT_DIR=$(cd "$APP_DIR/.." && pwd)
PLIST="$APP_DIR/ios/Runner/GoogleService-Info.plist"
OPTIONS="$APP_DIR/lib/firebase_options.dart"
SIGNING="$APP_DIR/ios/Flutter/Signing.xcconfig"
DEFAULT_BUNDLE_ID=com.bakeout.bakeout
REFRESH=no
[ "${1:-}" = "--refresh" ] && REFRESH=yes

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
fail() { printf '\n\033[31m%s\033[0m\n' "$1" >&2; exit 1; }

# --- 1. Firebase config -------------------------------------------------------------
say "1/2  Firebase config"
if [ -f "$OPTIONS" ] && [ "$REFRESH" = no ]; then
  echo "Already there (use --refresh to download again)."
else
  command -v firebase >/dev/null || fail "Install the Firebase CLI first: npm install -g firebase-tools, then run: firebase login"
  command -v node >/dev/null || fail "Node.js is needed to read the Firebase config (npm install -g firebase-tools brings it along)."
  PROJECT=$(sed -n 's/.*"default": *"\([^"]*\)".*/\1/p' "$ROOT_DIR/.firebaserc")
  [ -n "$PROJECT" ] || fail "Couldn't read the Firebase project from .firebaserc."

  WORK=$(mktemp -d)
  trap 'rm -rf "$WORK"' EXIT

  firebase apps:list --project "$PROJECT" --json >"$WORK/apps.json" 2>/dev/null ||
    fail "Couldn't list the project's apps. Run 'firebase login' with an account that's a member of $PROJECT (ask a teammate to add you in the Firebase console > Project settings > Users and permissions)."

  app_id() {
    node -e '
      const list = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      const apps = Array.isArray(list) ? list : (list.result || []);
      const app = apps.find(a => a.platform === process.argv[2]);
      process.stdout.write(app ? app.appId : "");
    ' "$WORK/apps.json" "$1"
  }

  IOS_ID=$(app_id IOS)
  [ -n "$IOS_ID" ] || fail "No iOS app found in $PROJECT."
  firebase apps:sdkconfig IOS "$IOS_ID" --project "$PROJECT" -o "$PLIST" >/dev/null
  cp "$PLIST" "$WORK/GoogleService-Info.plist"

  ANDROID_ID=$(app_id ANDROID)
  if [ -n "$ANDROID_ID" ]; then
    firebase apps:sdkconfig ANDROID "$ANDROID_ID" --project "$PROJECT" -o "$WORK/android.json" >/dev/null ||
      echo "Couldn't read the Android app settings; the Android build will need a Firebase Android app."
  fi

  WEB_ID=$(app_id WEB)
  if [ -n "$WEB_ID" ]; then
    firebase apps:sdkconfig WEB "$WEB_ID" --project "$PROJECT" -o "$WORK/web.json" >/dev/null ||
      echo "Couldn't read the Web app settings; the web build will need a Firebase Web app."
  fi

  node "$APP_DIR/scripts/firebase_options.js" "$WORK" "$OPTIONS" "$PROJECT"
  echo "Wrote ios/Runner/GoogleService-Info.plist and lib/firebase_options.dart for $PROJECT."
fi

# --- 2. Signing ---------------------------------------------------------------------
if [ "$(uname -s)" = "Darwin" ]; then
  say "2/2  Apple signing"
  if [ -f "$SIGNING" ] && [ "$REFRESH" = no ]; then
    echo "Already there: ios/Flutter/Signing.xcconfig (use --refresh to redo)."
  else
    find_teams() {
      {
        defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | sed -n 's/.*teamID = \([A-Z0-9]\{10\}\);.*/\1/p'
        security find-certificate -a -c "Apple Development" -p 2>/dev/null |
          openssl x509 -noout -subject 2>/dev/null |
          sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p'
      } | sort -u
    }
    TEAMS=${TEAM:-}
    [ -n "$TEAMS" ] || TEAMS=$(find_teams)
    COUNT=$(printf '%s\n' "$TEAMS" | grep -c . || true)
    if [ "$COUNT" -eq 0 ]; then
      fail "No Apple team found. Open Xcode > Settings > Accounts, sign in with your Apple ID, then run this again (or run with TEAM=YOURTEAMID)."
    elif [ "$COUNT" -gt 1 ]; then
      echo "You have more than one Apple team:"
      printf '  %s\n' $TEAMS
      printf 'Which one should BakeOut use? '
      read -r PICKED
      TEAMS=$PICKED
    fi
    TEAM_ID=$(printf '%s' "$TEAMS" | tr -d '[:space:]')
    # Bundle IDs belong to one Apple team, so each teammate signs their own copy.
    BUNDLE=${BUNDLE_ID:-$DEFAULT_BUNDLE_ID.$(printf '%s' "$TEAM_ID" | tr '[:upper:]' '[:lower:]')}
    cat >"$SIGNING" <<EOF
// Your own Apple signing, written by app/scripts/setup.sh. Git-ignored; each teammate keeps their own.
DEVELOPMENT_TEAM = $TEAM_ID
CODE_SIGN_STYLE = Automatic
BAKEOUT_BUNDLE_ID = $BUNDLE
EOF
    echo "Signing with team $TEAM_ID as $BUNDLE."
  fi
else
  say "2/2  Apple signing"
  echo "Skipped: Apple signing only applies on macOS. Android and web need no signing step."
fi

say "Done. Run:  cd app && flutter run"
