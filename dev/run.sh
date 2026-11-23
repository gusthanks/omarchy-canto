#!/usr/bin/env bash
# Run the Canto Now Playing dev harness in its OWN Quickshell instance.
# It never touches the live Omarchy shell or the installed plugin, so the bar
# is not reloaded or restarted while you test or take screenshots. All data
# is mock (dev/MockCanto.qml, dev/mock/): Canto does not need to be running,
# and nothing reads D-Bus/MPRIS or the real Visual Bridge file.
#
#   dev/run.sh preview          the pills and the popup in a window
#   dev/run.sh bar              docs/bar.png              (icon, controls, Title · Artist)
#   dev/run.sh bar-closed       docs/bar-closed.png       (Canto closed: the dimmed icon)
#   dev/run.sh bar-lyric        docs/bar-lyric.png        (lyric mode, a line that fits)
#   dev/run.sh bar-lyric-page1  docs/bar-lyric-page1.png  (a long line, first page)
#   dev/run.sh bar-lyric-page2  docs/bar-lyric-page2.png  (the same line, second page)
#   dev/run.sh panel            docs/panel.png            (mini player layout, liked, 3 lines)
#   dev/run.sh panel-unliked    docs/panel-unliked.png    (not liked, a short line)
#   dev/run.sh panel-hint       docs/panel-hint.png       (the popup with Visual Bridge off)
#   dev/run.sh docs         all of the captures above
#   dev/run.sh check        compile every plugin type, BarWidget.qml included
#                           (declared, never instantiated); run before deploy
#   dev/run.sh test         Model.js + catalog unit tests (node --test, no npm deps)
#
# LANGUAGE picks the shell language for the run (default en), e.g.
# LANGUAGE=pt-BR dev/run.sh panel. Captures render offscreen (HEADLESS=1, the
# default), so nothing shows on the desktop; HEADLESS=0 uses a background
# layer surface instead. DEV_SCALE stands in for the monitor scale (1.6).
# Everything runs at the lowest CPU priority (nice 19).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
omarchy_shell="$OMARCHY_PATH/shell"
export HEADLESS="${HEADLESS:-1}"

# A throwaway Quickshell config: Omarchy's Commons/Ui libraries, this repo as
# "canto", and the harness as shell.qml. The language file is pinned here
# instead of reading ~/.config/omarchy/language.
cfg="${XDG_RUNTIME_DIR:-/tmp}/gusthx-canto-dev"
rm -rf "$cfg"
mkdir -p "$cfg"
ln -s "$omarchy_shell/Commons" "$cfg/Commons"
ln -s "$omarchy_shell/Ui" "$cfg/Ui"
ln -s "$repo" "$cfg/canto"
cp "$repo/dev/Harness.qml" "$cfg/shell.qml"
cp "$repo/dev/LayerStage.qml" "$repo/dev/MockCanto.qml" "$cfg/"
lang="${LANGUAGE:-en}"; lang="${lang%%:*}"
printf '%s\n' "$lang" > "$cfg/language"
export OMARCHY_LANGUAGE_FILE="$cfg/language"

suffix=""; [ "$lang" != en ] && suffix="-$lang"
qs=(nice -n 19 quickshell -n)
noise='atspi|qmlscanner|portal|polkit|QT_QPA_PLATFORM|actually running wayland|window masks|--- WARNING ---|No PanelWindow backend|toplevel-mapping'

render() { # mode out
  local log="$cfg/$1.log"
  local platform=()
  [ "$HEADLESS" = 1 ] && platform=(env QT_QPA_PLATFORM=offscreen QT_SCALE_FACTOR="${DEV_SCALE:-1.6}")
  rm -f "$2"
  MODE="$1" OUT="$2" timeout 30 "${platform[@]}" "${qs[@]}" -p "$cfg/shell.qml" >"$log" 2>&1 || true
  if grep -aE 'WARN|ERROR' "$log" | grep -vE "$noise" | grep -q .; then
    grep -aE 'WARN|ERROR' "$log" | grep -vE "$noise" >&2
  fi
  [ -f "$2" ] && echo "${2#"$repo"/}" || { echo "no image written for $1 (log: $log)" >&2; return 1; }
}

mkdir -p "$repo/docs"
case "${1:-preview}" in
  preview)    MODE=preview "${qs[@]}" -p "$cfg/shell.qml" ;;
  bar)        render bar        "$repo/docs/bar$suffix.png" ;;
  bar-lyric)  render bar-lyric  "$repo/docs/bar-lyric$suffix.png" ;;
  bar-closed|bar-lyric-page1|bar-lyric-page2|panel-unliked) render "$1" "$repo/docs/$1$suffix.png" ;;
  panel)      render panel      "$repo/docs/panel$suffix.png" ;;
  panel-hint) render panel-hint "$repo/docs/panel-hint$suffix.png" ;;
  docs)       for m in bar bar-closed bar-lyric bar-lyric-page1 bar-lyric-page2 panel panel-unliked panel-hint; do "$0" "$m"; done ;;
  test)       nice -n 19 node --test "$repo/dev/tests/" ;;
  check)
    # Compile-only: types are declared inside Components that never get created,
    # so no window opens and no D-Bus/MPRIS connection is made.
    files=$(cd "$repo" && ls *.qml | sed 's/\.qml$//')
    { echo 'import QtQuick'; echo 'import Quickshell'; echo 'import "canto" as W'; echo 'ShellRoot {'
      i=0; for f in $files; do echo "  Component { id: c$i; W.$f {} }"; i=$((i+1)); done
      echo '  Component.onCompleted: {'
      i=0; for f in $files; do echo "    console.warn(\"CHECK $f\", c$i.status === Component.Ready ? \"OK\" : c$i.errorString())"; i=$((i+1)); done
      echo '    Qt.quit()'; echo '  }'; echo '}'; } > "$cfg/shell.qml"
    timeout 20 "${qs[@]}" -p "$cfg/shell.qml" >"$cfg/check.log" 2>&1 || true
    if grep -q 'Failed to load configuration' "$cfg/check.log"; then grep -aE 'ERROR' "$cfg/check.log" >&2; exit 1; fi
    grep -a 'CHECK ' "$cfg/check.log" | sed 's/^.*CHECK /CHECK /'
    grep -a 'CHECK ' "$cfg/check.log" | grep -q . || { echo "check produced no output (log: $cfg/check.log)" >&2; exit 1; }
    ! grep -a 'CHECK ' "$cfg/check.log" | grep -vq ' OK$' ;;
  *) sed -n '2,27p' "$0"; exit 1 ;;
esac
