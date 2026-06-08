#!/usr/bin/env bash
# browser-detect.sh — find the primary / available Chromium browsers for Claude in Chrome.
#
# The Claude for Chrome extension can live in ANY Chromium browser — Chrome, Dia, Arc, Brave,
# Edge, Vivaldi, Chromium — not just Google Chrome. This helper tells the skill which are
# installed, which are running, and which is the system default, and can launch/focus one so
# an instance exists for the extension to connect through.
#
#   browser-detect.sh                 # list known Chromium browsers + the system default
#   browser-detect.sh ensure          # launch/focus the primary (default, else running, else installed)
#   browser-detect.sh ensure "Dia"    # launch/focus a specific browser by app name
set -eo pipefail

# name | bundle id | process name   (priority order: default check first, then this order)
BROWSERS=(
  "Google Chrome|com.google.Chrome|Google Chrome"
  "Dia|company.thebrowser.dia|Dia"
  "Arc|company.thebrowser.Browser|Arc"
  "Brave Browser|com.brave.Browser|Brave Browser"
  "Microsoft Edge|com.microsoft.edgemac|Microsoft Edge"
  "Vivaldi|com.vivaldi.Vivaldi|Vivaldi"
  "Chromium|org.chromium.Chromium|Chromium"
)

default_browser() {
  plutil -convert json -o - \
    "$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist" 2>/dev/null \
  | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    h=[x for x in d.get('LSHandlers',[]) if x.get('LSHandlerURLScheme')=='https']
    print(h[0].get('LSHandlerRoleAll','') if h else '')
except Exception:
    print('')" 2>/dev/null || true
}

is_installed() { mdfind "kMDItemCFBundleIdentifier == '$1'" 2>/dev/null | head -1; }     # echoes path or empty
is_running()   { pgrep -x "$1" >/dev/null 2>&1 && echo yes || echo no; }

cmd_list() {
  local def; def=$(default_browser)
  echo "default browser: ${def:-unknown}"
  printf "%-16s %-28s %-10s %-8s %s\n" NAME BUNDLE INSTALLED RUNNING DEFAULT
  local row name bundle proc path inst run d
  for row in "${BROWSERS[@]}"; do
    IFS='|' read -r name bundle proc <<<"$row"
    path=$(is_installed "$bundle"); inst="no"; [[ -n "$path" ]] && inst="yes"
    run=$(is_running "$proc")
    d=""; [[ -n "$def" && "$bundle" == "$def" ]] && d="<- default"
    printf "%-16s %-28s %-10s %-8s %s\n" "$name" "$bundle" "$inst" "$run" "$d"
  done
}

cmd_ensure() {
  local target="$1" row name bundle proc def
  if [[ -n "$target" ]]; then
    open -a "$target" 2>/dev/null && { echo "ensured: $target (launched/focused)"; return; }
    echo "ERROR: could not open '$target'" >&2; exit 1
  fi
  def=$(default_browser)
  # 1) default browser, if it is a known Chromium
  for row in "${BROWSERS[@]}"; do
    IFS='|' read -r name bundle proc <<<"$row"
    if [[ -n "$def" && "$bundle" == "$def" ]]; then
      open -a "$name" 2>/dev/null && { echo "ensured: $name (system default, focused)"; return; }
    fi
  done
  # 2) first known Chromium already running
  for row in "${BROWSERS[@]}"; do
    IFS='|' read -r name bundle proc <<<"$row"
    if [[ "$(is_running "$proc")" == "yes" ]]; then
      open -a "$name" 2>/dev/null || true; echo "ensured: $name (already running, focused)"; return
    fi
  done
  # 3) first known Chromium installed
  for row in "${BROWSERS[@]}"; do
    IFS='|' read -r name bundle proc <<<"$row"
    if [[ -n "$(is_installed "$bundle")" ]]; then
      open -a "$name" 2>/dev/null && { echo "ensured: $name (installed, launched)"; return; }
    fi
  done
  echo "ERROR: no known Chromium browser found (Chrome/Dia/Arc/Brave/Edge/Vivaldi/Chromium)" >&2
  exit 2
}

case "${1:-list}" in
  list|"") cmd_list ;;
  ensure)  shift; cmd_ensure "${1:-}" ;;
  *) echo "usage: browser-detect.sh [list | ensure [NAME]]" >&2; exit 1 ;;
esac
