import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "Model.js" as Model

// Everything the pill and the popup show, and the actions they call. Track and
// controls come from Canto's MPRIS player (always there while Canto runs); the
// synced lyric lines, the liked state and the timing come from the Visual
// Bridge file. Other players are ignored. dev/MockCanto.qml has the same
// properties and functions, so the harness can render the views without Canto.
Item {
  id: root

  // Set by the host: read the bridge only while something uses it (lyric
  // mode, the heart in the pill, or the popup).
  property bool wantBridge: true
  // Set by the host while the popup is open: the progress line samples the
  // position once a second, and only then.
  property bool trackProgress: false

  readonly property var player: Model.pickCantoPlayer(Mpris.players ? Mpris.players.values : [])
  readonly property bool running: player !== null

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

  // ---- Liked. Unknown (null) on older Canto or a non-Spotify track: the
  // heart hides. A click flips the heart at once; the flip holds until a
  // bridge frame agrees (Canto saves the like over the network first), or
  // for 4 s at most, after which the bridge's word stands.
  property var likedOverride: null
  readonly property var likedState: likedOverride !== null ? likedOverride : bridge.likedState
  readonly property bool likedKnown: likedState === true || likedState === false
  readonly property bool liked: likedState === true
  Connections {
    target: bridge
    function onLikedStateChanged() {
      if (root.likedOverride !== null && bridge.likedState === root.likedOverride) root.likedOverride = null
    }
  }
  Timer { id: likedHold; interval: 4000; onTriggered: root.likedOverride = null }
  onTitleChanged: { likedOverride = null; likedHold.stop() }

  function toggleLiked() {
    if (!root.running || !root.likedKnown) return
    root.likedOverride = !root.liked
    likedHold.restart()
    Quickshell.execDetached(["busctl", "--user", "call", "org.mpris.MediaPlayer2.canto",
      "/org/mpris/MediaPlayer2", "io.github.gusthanks.Canto.Player", "ToggleLiked"])
  }

  // ---- Progress, 0..1, or -1 when unknown. Bridge frames carry it while
  // the bridge is on; otherwise MPRIS position / length, sampled once a
  // second while the popup is open.
  property real progress: -1
  function sampleProgress() {
    if (bridge.progress >= 0) { root.progress = bridge.progress; return }
    if (player && player.lengthSupported && player.length > 0) {
      player.positionChanged()
      root.progress = Model.progressFraction(player.position, player.length)
    } else root.progress = -1
  }
  Timer {
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: root.trackProgress && root.hasTrack
    onTriggered: root.sampleProgress()
  }

  function playPause() {
    if (!player) return
    if (player.isPlaying && player.canPause) player.pause()
    else if (!player.isPlaying && player.canPlay) player.play()
    else if (player.canTogglePlaying) player.togglePlaying()
  }
  function next() { if (player && player.canGoNext) player.next() }
  function previous() { if (player && player.canGoPrevious) player.previous() }
  function raise() { if (player && player.canRaise) player.raise() }

  // Starts Canto: gtk-launch finds the native or the Flatpak install by its
  // app id; plain `canto` is the fallback.
  function launch() {
    Quickshell.execDetached(["sh", "-c", "gtk-launch io.github.gusthanks.Canto >/dev/null 2>&1 || canto >/dev/null 2>&1 &"])
  }
  function raiseOrLaunch() {
    if (root.canRaise) root.raise()
    else if (!root.running) root.launch()
  }

  Bridge {
    id: bridge
    watching: root.player !== null && (root.wantBridge || root.trackProgress)
    trackTitle: root.title
    trackArtist: root.artist
    trackPlaying: root.playing
  }
}
