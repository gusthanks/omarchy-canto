# Canto Now Playing for Omarchy

**English** · [Português (Brasil)](README.pt-BR.md)

What [Canto](https://github.com/gusthanks/canto) is playing, in the [Omarchy](https://omarchy.org)
bar: previous / play-pause / next, then the title and artist, or the line of the song being
sung right now. Click the text to switch between the two. Right-click for a small popup with
the cover and the lyric around the current line.

<p align="center"><img src="docs/bar.png" width="600" alt="The bar: previous, pause and next buttons, a music note, Paper Lanterns · Lumen Coast"></p>
<p align="center"><img src="docs/bar-lyric.png" width="600" alt="Lyric mode: a microphone and the current synced line in italic"></p>

## What you get

- **Controls and the track**: small previous / play-pause / next buttons, then a music note
  and *Title · Artist* (cut with an ellipsis past the width you choose). Dimmed while
  paused, hidden while Canto is closed or has nothing loaded. The buttons can be turned off.
- **Click the text for the lyric**: the text switches to the synced line being sung, in
  italic and with a microphone in front, so it never reads as a title. Click again for the
  title. The choice is saved and survives a restart.
- **Never cut**: a line wider than the pill is shown in pages that break between words,
  page 1, then page 2, timed to finish before the next line starts. A new line always
  starts at page 1. No scrolling text, no animation running all the time.
- **Never confusing**: with no line to show (Visual Bridge off, an instrumental break, a song
  without synced lyrics) lyric mode shows the title with the microphone dimmed. Hover the
  text for the track, what a click does, and, if needed, where to turn lyrics on.
- **A small popup**: the cover, title, artists and album, the line before, the current line
  (larger) and the next one, whole and wrapped, and previous / play-pause / next. Click the
  cover to bring Canto's window up.
- **Only Canto**: other players (browsers, video) never show up here. Omarchy's media
  widget still covers those.
- **Your theme and language**: colors, font and corner radius come from Omarchy's theme;
  strings follow the language picked in Omarchy's setup (English and Brazilian Portuguese).

<p align="center">
  <img src="docs/bar-lyric-page1.png" width="600" alt="A long lyric line, page 1: we kept the porch light burning">
  <img src="docs/bar-lyric-page2.png" width="600" alt="The same line, page 2: and the tide came in anyway">
</p>

<p align="center">
  <img src="docs/panel.png" width="400" alt="The popup: cover, Paper Lanterns, Lumen Coast, Ana Vale, Night Ferry, the previous line dimmed, the current line larger with an accent rule, the next line dimmed, and previous, pause, next">
  <img src="docs/panel-hint.png" width="400" alt="The popup with Visual Bridge off: a hint says where to turn it on">
</p>

*(Screenshots are rendered from mock data by the dev harness, see [Development](#development).
The track, lyric and cover are made up.)*

## Lyrics need Visual Bridge

Title, artist, cover and controls work as soon as Canto runs. The lyric line needs one
switch in Canto, off by default:

**Canto: Preferences, Integrations, Visual Bridge, turn on "Enable Visual Bridge".**

Canto then writes what is playing, with the current synced line, to
`$XDG_RUNTIME_DIR/canto/state.json`, and this widget reads it. Songs without synced lyrics
simply show the title.

Recent Canto builds also send the lines before and after the current one and when the next
line starts: the popup then shows the next line, and long lines page exactly in time. With
an older Canto the popup shows the line before and the current one, and pages last 1.6 s
each (or follow the length of the previous line).

## Install

```bash
omarchy plugin add https://github.com/gusthanks/omarchy-canto.git --enable
omarchy restart shell
```

It lands just right of the bar's center group (next to the clock in the default layout). Move it with `omarchy bar move`, for
example `omarchy bar move gusthx.canto --section right --index 0`.

Update with `omarchy plugin update gusthx.canto --yes`, then `omarchy restart shell`.

## Use

| On the pill | Does |
|---|---|
| Previous / play-pause / next buttons | What they say |
| Click the text | Switch between the title and the lyric line (saved) |
| Middle click | Next track |
| Right click | Open or close the popup |
| Scroll up / down | Previous / next track (one per touchpad swipe) |
| Hover the text | The track, what a click does, and where to turn lyrics on if needed |

## Configuration

Three settings, in the bar's settings form or from a terminal:

```bash
omarchy bar set gusthx.canto showControls false --json  # text only, no buttons
omarchy bar set gusthx.canto startMode lyric            # start on the lyric line (title is the default)
omarchy bar set gusthx.canto maxWidth 320 --json        # wider text (120 to 600, default 240)
```

Clicking the text in the bar changes `startMode` for you. `maxWidth` is in pixels before
your display scaling: a longer lyric line pages, a longer title gets an ellipsis.

Motion follows Hyprland: with animations turned off there (`animations:enabled = false`),
the lyric changes without the fade.

## Privacy

No account, no telemetry, no logs.

What it **reads**: Canto's MPRIS player on the session D-Bus (track, artists, album, cover
link, playing state), and, only while lyric mode is on or the popup is open,
`$XDG_RUNTIME_DIR/canto/state.json`. It **writes** only its own `startMode` setting to
`~/.config/omarchy/shell.json`, when you click the text, through the shell (as Omarchy's
clock saves its format).

What it **contacts**: nothing on its own. While the popup is open it shows the cover from
the link Canto reports, which for Spotify tracks is Spotify's image server.

## Development

Work in a clone of this repository, never in the installed copy under
`~/.config/omarchy/plugins/` (saving there hot-reloads your bar). `dev/run.sh` starts a
**separate** Quickshell instance with Omarchy's `Commons`/`Ui` libraries, this repo and
mock data from `dev/mock/`: it never touches the running shell, D-Bus or the real bridge
file, and Canto does not need to run. Captures render offscreen, so nothing shows on screen.

```bash
dev/run.sh check     # compile every QML type, BarWidget.qml included
dev/run.sh test      # Model.js and i18n catalog tests (node --test, no npm packages)
dev/run.sh docs      # docs/bar.png, bar-lyric.png, bar-lyric-page1.png, bar-lyric-page2.png,
                     # panel.png, panel-hint.png
dev/run.sh preview   # the pills and the popup in a window
LANGUAGE=pt-BR dev/run.sh panel-hint   # docs/panel-hint-pt-BR.png
omarchy plugin validate .
```

Layout: `BarWidget.qml` (the bar slot: settings, mode toggle, wheel, popup window),
`CantoSource.qml` (Canto's MPRIS player and the actions), `Bridge.qml` (reads the Visual
Bridge file: the lyric, the lines around it, timing), `Pill.qml` (buttons, text, paging), `NowPlayingView.qml` (the popup's content), `FadeText.qml` (the
cross-fading text), `Model.js` (pure helpers), `i18n/*.json` (strings, read through
`Commons.Translations`), `dev/` (harness, mocks, tests, deploy).

When everything is committed and tested, install it into your own bar once:

```bash
dev/deploy.sh   # validates, compiles, installs HEAD into the live plugin, restarts the shell once
```

See [AGENTS.md](AGENTS.md) for the rules AI agents (and humans) follow here.

## Changes

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Gustavo Costa (gusthx).
