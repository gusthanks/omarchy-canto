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
- **Do not** drive the user's Canto (play, pause, skip) to test: it is their music.

## Test and capture in isolation

`dev/run.sh` starts a **separate** Quickshell instance (config dir
`$XDG_RUNTIME_DIR/gusthx-canto-dev`) with Omarchy's `Commons`/`Ui` libraries, this repo
and `dev/MockCanto.qml`, which feeds `Pill.qml` and `NowPlayingView.qml` a mock track and
the mock Visual Bridge frame in `dev/mock/state.json`, read through the real `Bridge.qml`
and `Model.js`. It never touches the running shell, D-Bus/MPRIS, the real
`$XDG_RUNTIME_DIR/canto/state.json` or `shell.json`, and Canto does not need to run.
Captures render offscreen (Qt's offscreen platform), so they also work with the screen
off; `HEADLESS=0` draws on a background layer surface instead. Everything runs under
`nice -n 19`.

```bash
dev/run.sh check        # compile every type, BarWidget.qml included (deploy runs this too)
dev/run.sh test         # Model.js + i18n catalog tests (node --test, no npm packages)
dev/run.sh bar          # docs/bar.png          the pill: Title · Artist
dev/run.sh bar-lyric    # docs/bar-lyric.png    the pill: the synced lyric line
dev/run.sh panel        # docs/panel.png        the popup: cover, lyric, controls
dev/run.sh panel-hint   # docs/panel-hint.png   the popup with Visual Bridge off
dev/run.sh docs         # all of the captures above
dev/run.sh preview      # both pills and the popup in a window
LANGUAGE=pt-BR dev/run.sh panel   # any capture in another language (docs/<name>-pt-BR.png)
```

QML warnings from the harness are printed by `dev/run.sh`; fix them before going further.
Look at the images you render. Also run `omarchy plugin validate .` (it refuses symlinks,
so never leave a `node_modules/` in the repo).

Motion follows Hyprland: with `animations:enabled` off, Omarchy's `Style.duration()`
returns 0 and the lyric cross-fade is an instant swap. That is intended, not a bug.

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
- Keep the bar widget cheap (it must stay light on older laptops): no timers faster than
  2 s, the bridge file is watched only while something shows the lyric, and the cover is
  loaded only while the popup is open.
- Mock data only in the harness and tests: never the user's tracks, config or accounts.
  The mock track, lyric and cover are made up for this repo.
