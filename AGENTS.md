# Notes for AI agents (and humans) working on this plugin

## Never work on the live plugin

The copy installed at `~/.config/omarchy/plugins/gusthx.canto/` is the one the user's Omarchy
shell is running. Saving a file there hot-reloads the plugin in the user's bar, and
`omarchy restart shell` restarts the whole bar. Doing that over and over while developing
is disruptive.

- **Edit only this repository** (the working copy in `~/Work/`).
- **Do not** edit, copy into, or `git` anything under `~/.config/omarchy/plugins/`.
- **Do not** run `omarchy restart shell`, `omarchy refresh shell`, `omarchy theme set`,
  or `omarchy-shell` IPC calls to test a change.
- **Do not** take screenshots of the user's desktop (`grim`) to check your work.
- **Do not** drive the user's Canto (play, pause, skip, like, launch) to test: it is their
  music and their Spotify library. Never run `git` or anything else inside
  `~/.config/omarchy/plugins/`: the shell watches it, reloads and can move the widget.

## Test and capture in isolation

`dev/run.sh` starts a **separate** Quickshell instance (config dir
`$XDG_RUNTIME_DIR/gusthx-canto-dev`) with Omarchy's `Commons`/`Ui` libraries, this repo
and `dev/MockCanto.qml`, which feeds `Pill.qml` and `NowPlayingView.qml` a mock track and
the mock Visual Bridge frames in `dev/mock/` (`state.json`, a long line; `state-short.json`),
read through the real `Bridge.qml` and `Model.js`. It never touches the running shell, D-Bus/MPRIS, the real
`$XDG_RUNTIME_DIR/canto/state.json` or `shell.json`, and Canto does not need to run.
Captures render offscreen (Qt's offscreen platform), so they also work with the screen
off; `HEADLESS=0` draws on a background layer surface instead. Everything runs under
`nice -n 19`.

```bash
dev/run.sh check            # compile every type, BarWidget.qml included (deploy runs this too)
dev/run.sh test             # Model.js + i18n catalog tests (node --test, no npm packages)
dev/run.sh bar              # docs/bar.png              icon, controls, Title · Artist
dev/run.sh bar-closed       # docs/bar-closed.png       Canto closed: the dimmed icon
dev/run.sh bar-lyric        # docs/bar-lyric.png        lyric mode, a line that fits
dev/run.sh bar-lyric-page1  # docs/bar-lyric-page1.png  a long line, first page
dev/run.sh bar-lyric-page2  # docs/bar-lyric-page2.png  the same line, second page
dev/run.sh panel            # docs/panel.png            the popup: mini player, liked, 3 lines
dev/run.sh panel-unliked    # docs/panel-unliked.png    not liked, a short line
dev/run.sh panel-hint       # docs/panel-hint.png       the popup with Visual Bridge off
dev/run.sh docs             # all of the captures above
dev/run.sh preview          # the pills and the popup in a window
LANGUAGE=pt-BR dev/run.sh panel-hint   # any capture in another language (docs/<name>-pt-BR.png)
```

QML warnings from the harness are printed by `dev/run.sh`; fix them before going further.
Look at the images you render. Also run `omarchy plugin validate .` (it refuses symlinks,
so never leave a `node_modules/` in the repo).

Motion follows Hyprland: with `animations:enabled` off, Omarchy's `Style.duration()`
returns 0 and the lyric cross-fade is an instant swap. That is intended, not a bug. Lyric
pages change on a Timer, never by a running animation (the user's laptop is weak and
animations are off there).

What the harness cannot render (the real popup window, real MPRIS from Canto, the real
bar) is checked by the user after deploying, not by you on their live shell.

## Deploy once, at the end, and restart the bar

When ALL the requested work is finished, tested in the harness and committed:

```bash
dev/deploy.sh   # validates, compiles, installs HEAD into the live plugin, restarts the shell once
```

If the live plugin is a plain copy (no `.git`), deploy moves it to
`~/Work/backups/gusthx.canto.<timestamp>` and replaces it with a git checkout of this
repo; later deploys fast-forward it. The shell's hot reload is not reliable for plugins
(the old version can stay on screen), so the deploy always ends with one
`omarchy restart shell`. Do not tell the user something is done before this ran. Never use
`omarchy refresh shell` (it resets the bar layout). Never deploy or restart in the middle
of a task.

## Other conventions

- Repo root = plugin root (the layout `omarchy plugin add <url>` expects). Dev tooling
  lives in `dev/`, screenshots in `docs/`.
- Strings go through the plugin's own catalog in `i18n/` (`Commons.Translations`, reached
  through `BarWidget.tr()` and passed to the view as `tr`), never through `Commons.I18n`
  keys, which Omarchy may rename. Add every new key to every catalog (a test checks this).
- `Pill.qml` and `NowPlayingView.qml` read everything from their `source` object. A
  property or action added to `CantoSource.qml` must be added to `dev/MockCanto.qml` too.
- Only Canto: `Model.pickCantoPlayer()` never returns another MPRIS player. Keep it that
  way; Omarchy's own media widget covers every player.
- Keep the bar widget cheap (it must stay light on older laptops): no continuous
  animation; the lyric page timer (1.2 s or slower) runs only while a long line has pages
  left, the progress timer (1 s) only while the popup is open; the bridge file is watched
  only in lyric mode, with the heart in the bar, or with the popup open; the cover is loaded
  only while the popup is open.
- Canto's bridge fields `lyric_previous`, `lyric_next`, `lyric_ends_in_ms` and `liked` are
  newer than the bridge itself: keep the fallbacks for builds that leave them out (no heart
  without `liked`).
- `assets/canto-symbolic.svg` is Canto's own icon (MIT, same author): update it from Canto's
  `data/hicolor/symbolic/apps/` rather than redrawing it.
- Mock data only in the harness and tests: never the user's tracks, config or accounts.
  The mock track, lyric and cover are made up for this repo.
