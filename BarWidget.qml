import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Canto Now Playing: what Canto is playing, in the bar. Hidden while Canto is
// not running or has no track, like Omarchy's own media widget.
//   buttons        previous / play-pause / next
//   click the text title mode <-> lyric mode (saved as startMode)
//   middle click   next track
//   right click    the popup (cover, lyric lines, previous / play / next)
//   wheel          up: previous, down: next
// Settings (shell.json entry or the bar settings form): showControls,
// startMode ("title" or "lyric"), maxWidth.
BarWidget {
  id: root
  moduleName: "gusthx.canto"

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  function tr(key, fallback) { return strings.t(key, fallback) }

  // "false" too: shell.json may hold the setting as a string.
  readonly property bool showControls: String(setting("showControls", true)) !== "false"
  readonly property int maxWidth: Style.space(Model.labelWidth(setting("maxWidth", 240), 240))
  readonly property string mode: Model.normalizedMode(setting("startMode", "title"))

  // Clicking the text switches modes and saves the choice in startMode, the
  // way Omarchy's clock saves its format: applied here first so the pill
  // changes on the click, then written to shell.json, which comes back
  // through the bar as the same value. The setting survives restarts.
  function toggleMode() {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.startMode = Model.otherMode(root.mode)
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  property bool popupOpen: false
  readonly property bool opened: popupOpen
  function open() { if (canto.hasTrack) popupOpen = true }
  function close() { popupOpen = false }
  function toggle() { if (popupOpen) close(); else open() }

  CantoSource {
    id: canto
    wantLyric: root.mode === "lyric" || root.popupOpen
  }

  visible: canto.hasTrack
  onVisibleChanged: if (!visible) close()
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
    }
  }
}
