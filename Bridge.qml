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
  // Newer Canto only (hasNeighbors false on older builds): the lines around
  // the current one, and ms until the next line starts.
  property bool hasNeighbors: false
  property string previous: ""
  property string next: ""
  property real endsInMs: 0
  // Newer Canto: true / false, or null (unknown, not a Spotify track).
  property var liked: null
  property real progressMs: 0
  property real durationMs: 0
  property real updatedAt: 0
  // Wall clock for the staleness check, ticking slowly only while watching.
  property real now: 0

  readonly property var frame: ({ active: root.active, playing: root.playing, title: root.title, lyric: root.lyric, updatedAt: root.updatedAt })

  // ---- What the views use, for the track MPRIS reports (set by the owner).
  property string trackTitle: ""
  property string trackArtist: ""
  property bool trackPlaying: false
  // The harness turns this off: its mock frame is old on purpose.
  property bool checkStale: true

  readonly property bool frameValid: Model.bridgeFrameValid(frame, trackTitle, trackPlaying, checkStale ? now : 0)
  readonly property string lyricLine: frameValid ? lyric : ""
  readonly property string previousLine: neighbors.previous
  readonly property string nextLine: neighbors.next
  // Canto's own neighbors when it sends them; otherwise the line remembered
  // before this one. A repeat of the current line is never shown.
  readonly property var neighbors: Model.neighborLines(lyricLine,
    frameValid && hasNeighbors ? previous : (history ? history.previous : ""),
    frameValid ? next : "")
  readonly property var likedState: frameValid ? liked : null
  // Where the track is, as of the last frame (the popup's progress line).
  readonly property real progress: frameValid ? Model.progressFraction(progressMs, durationMs) : -1
  readonly property real lineEndsInMs: frameValid ? endsInMs : 0
  readonly property real lineMs: history ? history.lineMs : 0

  property var history: null
  function remember() {
    root.history = Model.lyricHistory(root.history, root.lyricLine, root.trackTitle + "\n" + root.trackArtist, Date.now())
  }
  onLyricLineChanged: remember()
  onTrackTitleChanged: remember()


  function apply(text) {
    var f = Model.parseBridge(text)
    if (!f) return
    root.loaded = true
    root.active = f.active
    root.playing = f.playing
    root.title = f.title
    // Timing and neighbors first: whoever reacts to a new lyric reads them.
    root.hasNeighbors = f.hasNeighbors
    root.previous = f.previous
    root.next = f.next
    root.endsInMs = f.endsInMs
    root.liked = f.liked
    root.progressMs = f.progressMs
    root.durationMs = f.durationMs
    root.updatedAt = f.updatedAt
    root.lyric = f.lyric
    root.now = Date.now()
  }

  function clear() {
    root.loaded = false
    root.active = false
    root.lyric = ""
    root.hasNeighbors = false
    root.previous = ""
    root.next = ""
    root.endsInMs = 0
    root.liked = null
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
