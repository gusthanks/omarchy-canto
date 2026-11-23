# Changelog

## 0.3.0 (2026-11-23)

### Added

- **Canto's icon** first in the pill (its colorful app icon, the one the app menu shows). A click
  raises Canto's window (MPRIS Raise) or starts Canto when it is closed
  (`gtk-launch io.github.gusthanks.Canto`, falling back to `canto`).
- **Canto closed**: the pill shrinks to the dimmed icon instead of disappearing (setting
  `showWhenClosed`, default on).
- **Like**: a heart in the popup, and optionally in the pill (`showLike`, default off). It
  calls Canto's `ToggleLiked` D-Bus method, fills at once and follows the bridge's `liked`
  field; it is hidden when Canto does not say (`liked` null or missing).
- **Progress line** along the bottom of the popup: the bridge's track progress, or MPRIS
  position, sampled once a second only while the popup is open.

### Changed

- The popup follows Canto's mini player: cover on the left, title and artist, previous /
  play (an accent-filled circle) / next, then a lyrics toggle and the heart on the right,
  the three lyric lines below when the toggle is on (remembered as `popupLyrics`), the
  progress line at the bottom.
- Default placement: the bar's left section (after the workspaces).
- The pill's Canto icon is drawn at about 70% of the bar height (18 px on the default bar),
  over an empty icon slot, as the bar's other picture icons are: as a button icon the bar
  fitted it to a 12 px glyph.
- Clicks on the text are swapped: a click opens the popup, a right click switches between
  the title and the lyric line. The tooltip says both. The icon and the buttons still open
  the popup on a right click.
- The pill shows the pointing hand over all of it (the bar's pointer layer showed it only over
  a pressable widget), and the bar no longer draws its accent underline below the whole pill
  while the popup is open.
- A click on the popup's cover opens the album in Canto: the window comes up and Canto gets
  the track's `spotify:track:` link through MPRIS `OpenUri` (Quickshell's `openUri`), which it opens as the track's
  album. The title still just brings the window up.
- The lyrics toggle and lyric mode use Canto's own lyrics icon (a speech bubble with quotes,
  Material Design `comment-quote-outline`) instead of a microphone.

### Fixed

- With an older Canto (no `lyric_previous`), the popup could show the current line as the
  previous one too (after the bridge was read again when the popup opened). A line equal to
  the current one is never shown as its neighbor now.

## 0.2.0 (2026-11-22)

A redesign after trying 0.1.0 on a real bar, where long lyric lines got cut.

### Changed

- The pill is now **previous / play-pause / next** (small bar buttons) followed by the
  text. Left click on the pill no longer plays/pauses: the buttons do. Middle click (next),
  right click (popup) and scroll (previous/next) work as before.
- **Click the text** to switch between *Title · Artist* and the lyric line. The choice is
  saved in the widget's `startMode` setting (through the shell, as Omarchy's clock saves
  its format), so it survives a restart.
- **Lyric lines are never cut**: a line wider than `maxWidth` is shown in pages that break
  between words, advanced by a timer (no continuous animation) and reset to page 1 on each
  new line. Pages share the time until the next line when Canto sends it
  (`lyric_ends_in_ms`), otherwise 1.6 s each (at least 1.2 s), or the previous line's length.
- Lyric mode without a line to show (bridge off, instrumental break, unsynced) shows the
  title with the microphone glyph dimmed; the text's tooltip says what a click does and
  where to turn Visual Bridge on.
- The popup shows **three whole lines**: the previous line, the current one (larger, with
  the accent rule) and the next one, wrapped, never elided. The next line needs a Canto
  build that sends `lyric_next`; older builds get the previous and current lines (the
  previous one remembered by the widget).
- Settings: `showControls` (default on), `startMode` (`title` or `lyric`, default `title`),
  `maxWidth`. `showLyric` is gone (use `startMode`).

### Fixed

- `Pill.qml` and `FadeText.qml` used `Commons.Color` without importing `qs.Commons as
  Commons` (a ReferenceError when no bar host is set).

### Development

- Visual Bridge parsing reads `lyric_previous`, `lyric_next` and `lyric_ends_in_ms`; the
  lyric logic lives in `Bridge.qml`, shared by the real source and the harness mock.
- New captures `bar-lyric-page1` and `bar-lyric-page2`; mock frames with made-up lyrics in
  `dev/mock/state.json` (a long line) and `dev/mock/state-short.json`.
- Tests for modes, paging, page timing, lyric history and the new bridge fields.

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
