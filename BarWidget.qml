import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Canto Now Playing: what Canto is playing, in the bar. Hidden while Canto is
// not running or has no track, like Omarchy's own media widget, and it follows
// the same mouse map:
//   left click     play / pause
//   middle click   next track
//   right click    the popup (cover, lyric line, previous / play / next)
//   wheel          up: previous, down: next
// Settings (shell.json entry or the bar settings form): showLyric, maxWidth.
BarWidget {
  id: root
  moduleName: "gusthx.canto"

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
  function tr(key, fallback) { return strings.t(key, fallback) }

  // "false" too: shell.json may hold the setting as a string.
  readonly property bool showLyric: String(setting("showLyric", true)) !== "false"
  readonly property int maxWidth: Style.space(Model.labelWidth(setting("maxWidth", 240), 240))

  property bool popupOpen: false
  readonly property bool opened: popupOpen
  function open() { if (canto.hasTrack) popupOpen = true }
  function close() { popupOpen = false }
  function toggle() { if (popupOpen) close(); else open() }

  CantoSource {
    id: canto
    wantLyric: root.showLyric || root.popupOpen
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
    showLyric: root.showLyric
    maxWidth: root.maxWidth
  }

  property var wheelState: ({ acc: 0, last: 0 })

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) canto.next()
      else if (mouse.button === Qt.RightButton) root.toggle()
      else canto.playPause()
    }
    onWheel: function(wheel) {
      root.wheelState = Model.wheelStep(root.wheelState, wheel.angleDelta.y, Date.now())
      if (root.wheelState.action === "previous") canto.previous()
      else if (root.wheelState.action === "next") canto.next()
    }
    // The tooltip names the track, which matters most while the pill shows a
    // lyric line or is cut short.
    onEntered: if (root.bar && !root.popupOpen) root.bar.showTooltip(root, Model.trackLabel(canto.title, canto.artist))
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onPressed: if (root.bar) root.bar.hideTooltip(root)
  }

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
      showLyric: root.showLyric
      foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
      fontFamily: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.font.family
      animate: root.popupOpen
      // The cover is fetched only while the popup is open, not on every track change.
      loadArt: root.popupOpen
    }
  }
}
