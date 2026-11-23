import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "canto" as W
import "canto/Model.js" as Model

// Stand-in for CantoSource.qml in the dev harness: the same properties and
// actions the pill and the popup read. The track is MOCK data (no MPRIS, no
// Canto needed); the lyric goes through the real Bridge.qml and Model.js,
// reading the mock Visual Bridge frame in dev/mock/state.json.
Item {
  id: root

  // A bar host with what the pill and the popup read.
  property QtObject bar: QtObject {
    property color foreground: Commons.Color.foreground
    property color barForeground: Commons.Color.foreground
    property color urgent: Commons.Color.urgent
    property bool foregroundAnimationEnabled: false
    property string fontFamily: Style.font.family
    property bool vertical: false
    property int barSize: Style.bar.sizeHorizontal
    function showTooltip(item, text) {}
    function hideTooltip(item) {}
    function run(cmd) {}
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("canto/i18n")
  }
  function tr(key, fallback) { return strings.t(key, fallback) }

  // Off: as if Visual Bridge were off in Canto (no file to read).
  property bool bridgeOn: true
  // Which mock frame: dev/mock/state.json (a long line, two pages) or
  // state-short.json (a line that fits).
  property string frameFile: "state.json"

  // Off: as if Canto were closed (the pill shows only the dimmed icon).
  property bool running: true
  property bool wantBridge: true
  property bool trackProgress: false

  property string title: running ? "Paper Lanterns" : ""
  property string artist: running ? Model.artistLine(["Lumen Coast", "Ana Vale"]) : ""
  property string album: "Night Ferry"
  property string artUrl: Qt.resolvedUrl("canto/dev/mock/cover.svg")
  readonly property bool hasTrack: title !== "" || artist !== ""
  property bool playing: true

  readonly property bool canPrevious: true
  readonly property bool canNext: true
  readonly property bool canPlayPause: true
  readonly property bool canRaise: running

  readonly property bool bridgeAvailable: bridge.available
  readonly property string lyric: bridge.lyricLine
  readonly property string previousLyric: bridge.previousLine
  readonly property string nextLyric: bridge.nextLine
  readonly property real lyricEndsInMs: bridge.lineEndsInMs
  readonly property real lineMs: bridge.lineMs

  property var likedOverride: null
  readonly property var likedState: likedOverride !== null ? likedOverride : bridge.likedState
  readonly property bool likedKnown: likedState === true || likedState === false
  readonly property bool liked: likedState === true
  readonly property real progress: bridge.progress

  function playPause() { playing = !playing }
  function next() {}
  function previous() {}
  function raise() {}
  function launch() {}
  function raiseOrLaunch() {}
  function toggleLiked() { if (likedKnown) likedOverride = !liked }

  W.Bridge {
    id: bridge
    path: String(Qt.resolvedUrl("canto/dev/mock/" + root.frameFile)).replace(/^file:\/\//, "")
    watching: root.bridgeOn && root.running
    trackTitle: root.title
    trackArtist: root.artist
    trackPlaying: root.playing
    // The mock frame is old on purpose.
    checkStale: false
  }
}
