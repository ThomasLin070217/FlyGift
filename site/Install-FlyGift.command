#!/bin/zsh
# ============================================================
#  FlyGift — double-click installer
#
#  The first time you open this file macOS asks
#  "…is a script app downloaded from the Internet. Are you sure
#   you want to open it?"  — click Open. It only asks once.
#
#  Everything this script downloads comes through curl, so the .app
#  it installs never carries com.apple.quarantine and never trips
#  Gatekeeper.
# ============================================================
set -u

ZIP_URL="https://github.com/ThomasLin070217/FlyGift/releases/latest/download/FlyGift-macOS-arm64.zip"
APP="FlyGift"

say() { printf '%s\n' "$*"; }
die() {
  say ""
  say "✗ $*"
  say ""
  say "Press Return to close this window…"
  read -r _
  exit 1
}

clear 2>/dev/null || true
say "🎁  FlyGift installer"
say "────────────────────"
say ""

# ---- 1. sanity checks ----
[ "$(uname -m)" = "arm64" ] || die "$APP needs an Apple Silicon (M-series) Mac; this one is not."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 15 ] || die "$APP needs macOS 15 or later (this Mac runs $(sw_vers -productVersion))."

# ---- 2. download ----
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

say "↓ Downloading FlyGift… (~52 MB)"
curl -fL --progress-bar -o "$TMP/f.zip" "$ZIP_URL" < /dev/null \
  || die "Download failed. Check your connection and try again."

# ---- 3. unpack ----
say ""
say "→ Unpacking…"
ditto -x -k "$TMP/f.zip" "$TMP/out" || die "Could not unpack the archive; the download may be corrupt."
SRC="$TMP/out/$APP.app"
[ -d "$SRC" ] || die "The archive did not contain $APP.app."

# ---- 4. install ----
if [ -w /Applications ]; then
  DEST="/Applications/$APP.app"
else
  DEST="$HOME/Applications/$APP.app"
fi
say "→ Installing to $DEST…"
mkdir -p "$(dirname "$DEST")"
pkill -x "$APP" 2>/dev/null || true
rm -rf "$DEST"
ditto "$SRC" "$DEST"

# ---- 5. belt and braces ----
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# ---- 6. launch ----
say ""
say "✓ Installed. Launching FlyGift…"
open "$DEST"
say "  Look for the 🎁 in your menu bar."
say ""
sleep 2
