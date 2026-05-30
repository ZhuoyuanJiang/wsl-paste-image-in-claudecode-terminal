#!/usr/bin/env bash
# uninstall.sh — stop the daemon, remove the binary, strip the ~/.bashrc autostart snippet.
set -euo pipefail

BIN_DST="$HOME/.local/bin/claude-clip-bridge"

# Stop a running daemon if possible.
if command -v claude-clip-bridge >/dev/null 2>&1; then
    claude-clip-bridge --stop 2>/dev/null || true
fi

# Remove the autostart snippet from ~/.bashrc (with backup).
RC="$HOME/.bashrc"
if grep -qF "# claude-clip-bridge autostart" "$RC" 2>/dev/null; then
    cp "$RC" "${RC}.bak.$(date +%Y%m%d-%H%M%S)"
    # Delete the marker comment line through the snippet's closing 'fi' block.
    python3 - "$RC" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
# Remove the autostart block: from the marker comment to the matching closing 'fi'.
pattern = re.compile(
    r"\n?# claude-clip-bridge autostart.*?\nif \[ -n \"\$WAYLAND_DISPLAY\".*?\n    fi\nfi\n",
    re.DOTALL,
)
s2 = pattern.sub("\n", s)
open(p, "w").write(s2)
print("removed autostart snippet from", p)
PY
else
    echo "No autostart snippet found in $RC."
fi

# Remove the binary.
if [[ -f "$BIN_DST" ]]; then
    rm -f "$BIN_DST"
    echo "Removed $BIN_DST"
fi

# Clean the cache dir.
rm -rf "$HOME/.cache/claude-clip-bridge" 2>/dev/null || true

echo "Uninstalled. (Your ~/.bashrc backups are kept as ~/.bashrc.bak.*)"
