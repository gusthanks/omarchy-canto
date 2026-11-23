import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Canto Now Playing: what Canto is playing, in the bar.
//   Canto icon     raise Canto's window, or start Canto when it is closed
//   buttons        previous / play-pause / next (and the heart, if shown)
//   click the text title mode <-> lyric mode (saved as startMode)
//   middle click   next track
//   right click    the popup (Canto's mini player layout and lyric lines)
//   wheel          up: previous, down: next
// With Canto closed the pill is just the dimmed icon (showWhenClosed), or
// hidden. Settings (shell.json entry or the bar settings form):
// showControls, showLike, showWhenClosed, startMode, popupLyrics, maxWidth.
BarWidget {
  id: root
  moduleName: "gusthx.canto"

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  function tr(key, fallback) { return strings.t(key, fallback) }

  // "false" too: shell.json may hold the setting as a string.
  function flag(name, fallback) {
    var v = setting(name, fallback)
    return String(v) !== "false" && v !== false
  }
  readonly property bool showControls: flag("showControls", true)
  readonly property bool showLike: flag("showLike", false)
  readonly property bool showWhenClosed: flag("showWhenClosed", true)
  readonly property bool popupLyrics: flag("popupLyrics", true)
  readonly property int maxWidth: Style.space(Model.labelWidth(setting("maxWidth", 240), 240))
  readonly property string mode: Model.normalizedMode(setting("startMode", "title"))

  // Clicks that change a setting (the text's mode, the popup's lyrics
  // toggle) save it the way Omarchy's clock saves its format: applied here
  // first so the change shows on the click, then written to shell.json, which
  // comes back through the bar as the same value. It survives restarts.
  function saveSetting(name, value) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry[name] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }
  function toggleMode() { saveSetting("startMode", Model.otherMode(root.mode)) }
  function toggleLyrics() { saveSetting("popupLyrics", !root.popupLyrics) }

  property bool popupOpen: false
  readonly property bool opened: popupOpen
  function open() { if (canto.hasTrack) popupOpen = true }
  function close() { popupOpen = false }
  function toggle() { if (popupOpen) close(); else open() }

  CantoSource {
    id: canto
    wantBridge: root.mode === "lyric" || root.popupOpen || root.showLike
    trackProgress: root.popupOpen
  }

  visible: canto.hasTrack || root.showWhenClosed
  onVisibleChanged: if (!visible) close()
  // The popup is about a track: it closes when there is none.
  Connections {
    target: canto
    function onHasTrackChanged() { if (!canto.hasTrack) root.close() }
  }
  implicitWidth: visible ? pill.implicitWidth : 0
  implicitHeight: barSize

  Pill {
    id: pill
    anchors.fill: parent
    bar: root.bar
    source: canto
    tr: root.tr
    mode: root.mode
    showControls: root.showControls
    showLike: root.showLike
    maxWidth: root.maxWidth
    onToggleRequested: root.toggleMode()
    onPopupRequested: root.toggle()
    onWheelMoved: function(delta) {
      root.wheelState = Model.wheelStep(root.wheelState, delta, Date.now())
      if (root.wheelState.action === "previous") canto.previous()
      else if (root.wheelState.action === "next") canto.next()
    }
  }

  property var wheelState: ({ acc: 0, last: 0 })

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(view.implicitWidth)
    contentHeight: popup.fittedContentHeight(view.implicitHeight)

    NowPlayingView {
      id: view
      anchors.fill: parent
      source: canto
      tr: root.tr
      foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
      fontFamily: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.font.family
      animate: root.popupOpen
      // The cover is fetched only while the popup is open, not on every track change.
      loadArt: root.popupOpen
      showLyrics: root.popupLyrics
      onLyricsToggled: root.toggleLyrics()
    }
  }
}
