import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Reads Canto's Visual Bridge file ($XDG_RUNTIME_DIR/canto/state.json, off by
// default in Canto: Preferences, Integrations, Visual Bridge). Canto replaces
// the file by rename about 15 times a second while playing; the watch follows
// the new file, a missing file means the bridge is off, and a frame that does
// not parse is skipped so the last good one stays.
//
// Only the fields the widget uses are copied out, each into its own property,
// so a new frame with the same lyric notifies nothing downstream.
Item {
  id: root

  property string path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/canto/state.json"
  // Off while nothing needs the lyric (setting off and popup closed, or Canto
  // not running): no watch, no reads.
  property bool watching: true

  readonly property bool available: loaded && active
  property bool loaded: false
  property bool active: false
  property bool playing: false
  property string title: ""
  property string lyric: ""
  property real updatedAt: 0
  // Wall clock for the staleness check, ticking slowly only while watching.
  property real now: 0

  readonly property var frame: ({ active: root.active, playing: root.playing, title: root.title, lyric: root.lyric, updatedAt: root.updatedAt })

  function apply(text) {
    var f = Model.parseBridge(text)
    if (!f) return
    root.loaded = true
    root.active = f.active
    root.playing = f.playing
    root.title = f.title
    root.lyric = f.lyric
    root.updatedAt = f.updatedAt
    root.now = Date.now()
  }

  function clear() {
    root.loaded = false
    root.active = false
    root.lyric = ""
  }

  onWatchingChanged: if (!watching) clear()

  FileView {
    id: file
    path: root.watching ? root.path : ""
    watchChanges: root.watching
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.apply(text())
    onLoadFailed: root.clear()
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.watching && root.available
    onTriggered: root.now = Date.now()
  }
}
