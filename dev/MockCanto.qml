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

  property string title: "Paper Lanterns"
  property string artist: Model.artistLine(["Lumen Coast", "Ana Vale"])
  property string album: "Night Ferry"
  property string artUrl: Qt.resolvedUrl("canto/dev/mock/cover.svg")
  readonly property bool hasTrack: title !== "" || artist !== ""
  property bool playing: true

  readonly property bool canPrevious: true
  readonly property bool canNext: true
  readonly property bool canPlayPause: true
  readonly property bool canRaise: true

  readonly property bool bridgeAvailable: bridge.available
  // now = 0: the mock frame is old on purpose, skip the staleness check.
  readonly property string lyric: Model.bridgeLyric(bridge.frame, title, playing, 0)

  function playPause() { playing = !playing }
  function next() {}
  function previous() {}
  function raise() {}

  W.Bridge {
    id: bridge
    path: String(Qt.resolvedUrl("canto/dev/mock/state.json")).replace(/^file:\/\//, "")
    watching: root.bridgeOn
  }
}
