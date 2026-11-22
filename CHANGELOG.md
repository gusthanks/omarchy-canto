# Changelog

## 0.1.0 (2026-11-22)

First version.

- Bar pill with a music note and *Title · Artist* from Canto's MPRIS player, elided past a
  maximum width. Dimmed while paused, hidden while Canto is not running or has no track.
  Only Canto: other MPRIS players are ignored.
- With Canto's Visual Bridge on, the pill can show the current synced lyric line instead
  (setting `showLyric`, on by default), in italic, cross-fading on each new line. The pill
  keeps one width while a track has lyrics, so the bar does not shift.
- Mouse map of Omarchy's media widget: left click play/pause, middle click next, right
  click popup, wheel previous/next (touchpad deltas add up to one skip, with a short
  cooldown).
- Popup with the cover (loaded only while open), title, artists, album, the lyric line and
  previous / play-pause / next. Clicking the cover raises Canto. With Visual Bridge off, a
  hint says where to turn it on.
- The Visual Bridge file is watched only while something shows the lyric. A broken or
  half-written frame is skipped, a missing file means the bridge is off, and a line is shown
  only for the track MPRIS reports and only while the frame keeps updating.
- Settings `showLyric` and `maxWidth` (120 to 600, default 240) in the bar settings form.
- English and Brazilian Portuguese strings.

### Development

- `dev/run.sh`: isolated Quickshell harness with a mock track and a mock Visual Bridge
  frame: `check`, `test`, `bar`, `bar-lyric`, `panel`, `panel-hint`, `docs`, `preview`.
- `dev/tests/`: Model.js and catalog tests (`node --test`, no npm packages).
- `dev/deploy.sh`: installs `HEAD` into the live plugin once and restarts the shell.
