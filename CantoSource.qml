import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "Model.js" as Model

// Everything the pill and the popup show, and the actions they call. Track and
// controls come from Canto's MPRIS player (always there while Canto runs); the
// synced lyric line comes from the Visual Bridge file. Other players are
// ignored. dev/MockCanto.qml has the same properties and functions, so the
// harness can render the views without Canto.
Item {
  id: root

  // Set by the host: read the bridge only while something shows the lyric.
  property bool wantLyric: true

  readonly property var player: Model.pickCantoPlayer(Mpris.players ? Mpris.players.values : [])

  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? Model.artistLine(player.trackArtist) : ""
  readonly property string album: player ? (player.trackAlbum || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property bool hasTrack: title !== "" || artist !== ""
  readonly property bool playing: !!player && player.isPlaying

  readonly property bool canPrevious: !!player && player.canGoPrevious
  readonly property bool canNext: !!player && player.canGoNext
  readonly property bool canPlayPause: !!player && (player.canTogglePlaying || player.canPlay || player.canPause)
  readonly property bool canRaise: !!player && player.canRaise

  readonly property bool bridgeAvailable: bridge.available
  readonly property string lyric: bridge.lyricLine
  readonly property string previousLyric: bridge.previousLine
  readonly property string nextLyric: bridge.nextLine
  // ms until the next line, as of the frame that brought the current one.
  readonly property real lyricEndsInMs: bridge.lineEndsInMs
  // How long the previous line lasted: the page timing fallback.
  readonly property real lineMs: bridge.lineMs

  function playPause() {
    if (!player) return
    if (player.isPlaying && player.canPause) player.pause()
    else if (!player.isPlaying && player.canPlay) player.play()
    else if (player.canTogglePlaying) player.togglePlaying()
  }
  function next() { if (player && player.canGoNext) player.next() }
  function previous() { if (player && player.canGoPrevious) player.previous() }
  function raise() { if (player && player.canRaise) player.raise() }

  Bridge {
    id: bridge
    watching: root.player !== null && root.wantLyric
    trackTitle: root.title
    trackArtist: root.artist
    trackPlaying: root.playing
  }
}
