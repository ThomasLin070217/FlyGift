#!/bin/sh
# ============================================================
#  FlyGift — one-line installer
#
#      curl -fsSL https://thomaslin070217.github.io/FlyGift/install.sh | zsh
#
#  Why there is no Gatekeeper popup: com.apple.quarantine is stamped
#  by the downloading *application* (Safari, Chrome, Edge). curl does
#  not do that, so neither this script nor the .app it fetches ever
#  carries the flag — Gatekeeper never gets involved.
# ============================================================
set -eu

ZIP_URL="https://github.com/ThomasLin070217/FlyGift/releases/latest/download/FlyGift-macOS-arm64.zip"
APP="FlyGift"

say() { printf '%s\n' "$*"; }
die() { say ""; say "✗ $*"; exit 1; }

# ---- 1. sanity checks ----
[ "$(uname -s)" = "Darwin" ] || die "This installer only runs on macOS."
[ "$(uname -m)" = "arm64" ] || die "$APP needs an Apple Silicon (M-series) Mac; this one is not."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 15 ] || die "$APP needs macOS 15 or later (this Mac runs $(sw_vers -productVersion))."

# ---- 2. download ----
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

say "↓ Downloading $APP… (~52 MB)"
curl -fL --progress-bar -o "$TMP/f.zip" "$ZIP_URL" < /dev/null \
  || die "Download failed. Check your connection and try again."

# ---- 3. unpack ----
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

# ---- 5. belt and braces: curl never quarantines, but be explicit ----
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# ---- 6. launch ----
say ""
say "✓ Installed. Launching $APP…"
open "$DEST"
say "  Look for the 🎁 in your menu bar."
