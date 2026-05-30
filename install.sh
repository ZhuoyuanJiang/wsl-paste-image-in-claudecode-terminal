#!/usr/bin/env bash
# install.sh — install claude-clip-bridge to ~/.local/bin, optionally enable autostart.
set -euo pipefail

WITH_AUTOSTART=0
for arg in "$@"; do
    case "$arg" in
        --autostart) WITH_AUTOSTART=1 ;;
        --help|-h)
            cat <<'USAGE'
Usage: ./install.sh [--autostart]

  (no flag)      Copy the claude-clip-bridge daemon to ~/.local/bin and check deps.
  --autostart    Also append a guarded autostart snippet to ~/.bashrc so the
                 bridge runs in the background in every new WSL shell.
                 A timestamped backup of ~/.bashrc is made first. Idempotent.
USAGE
            exit 0 ;;
        *) echo "Unknown arg: $arg (see ./install.sh --help)" >&2; exit 2 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_ROOT/bin/claude-clip-bridge"
BIN_DST="$HOME/.local/bin/claude-clip-bridge"

[[ -f "$BIN_SRC" ]] || { echo "ERROR: $BIN_SRC not found" >&2; exit 1; }

# --- dependency checks (warn, don't hard-fail, so users can install after) ---
echo "Checking dependencies..."
miss=0
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "  ! WAYLAND_DISPLAY is empty — this needs WSL2 with WSLg."; miss=1
else
    echo "  ok  WSLg ($WAYLAND_DISPLAY)"
fi
if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    echo "  ok  wl-clipboard"
else
    echo "  !  wl-clipboard missing — install: sudo apt install wl-clipboard"; miss=1
fi
if command -v python3 >/dev/null 2>&1 && python3 -c 'import PIL' 2>/dev/null; then
    echo "  ok  python3 + Pillow"
else
    echo "  !  python3 + Pillow missing — install: sudo apt install python3-pil  (or: pip install Pillow)"; miss=1
fi

# --- install the binary ---
mkdir -p "$HOME/.local/bin"
install -m 0755 "$BIN_SRC" "$BIN_DST"
echo "Installed: $BIN_DST"

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "  NOTE: ~/.local/bin is not on PATH. Add to ~/.bashrc:"
       echo '        export PATH="$HOME/.local/bin:$PATH"' ;;
esac

# --- optional autostart ---
if [[ $WITH_AUTOSTART -eq 1 ]]; then
    RC="$HOME/.bashrc"
    if grep -qF "# claude-clip-bridge autostart" "$RC" 2>/dev/null; then
        echo "Autostart already present in $RC — no change."
    else
        cp "$RC" "${RC}.bak.$(date +%Y%m%d-%H%M%S)"
        cat >> "$RC" <<'BASHRC'

# claude-clip-bridge autostart
if [ -n "$WAYLAND_DISPLAY" ] && command -v claude-clip-bridge >/dev/null 2>&1; then
    if ! claude-clip-bridge --status 2>/dev/null | grep -q running; then
        nohup claude-clip-bridge >/dev/null 2>&1 & disown
    fi
fi
BASHRC
        echo "Autostart added to $RC (backup made). Active in new shells."
    fi
fi

echo
if [[ $miss -eq 0 ]]; then
    echo "Done. Start now with:  nohup claude-clip-bridge >/dev/null 2>&1 & disown"
    echo "Then: Win+Shift+S to screenshot, Alt+V in Claude Code to paste."
else
    echo "Install the missing dependencies above, then start with:"
    echo "  nohup claude-clip-bridge >/dev/null 2>&1 & disown"
fi
