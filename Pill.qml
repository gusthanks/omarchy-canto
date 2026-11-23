import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// The bar pill: [previous] [play/pause] [next], then the text area.
//
// The text area shows "Title · Artist" (title mode, a music note in front)
// or the current synced lyric line (lyric mode, a microphone in front).
// Clicking it switches modes (toggleRequested). A lyric line wider than
// maxWidth is never cut: it is split into pages at word boundaries, page 1
// first, then the next ones on a timer, timed to end before the next line
// when Canto says when that is. A new line starts again at page 1. With no
// line to show (Visual Bridge off, an instrumental break, unsynced lyrics)
// lyric mode shows the track with the microphone dimmed, so the mode is never
// a mystery.
//
// No continuous animation: pages change on a timer, and the cross-fade
// follows Hyprland's animation setting (an instant swap when it is off).
Item {
  id: root

  property QtObject bar: null
  property var source: null
  property string mode: "title"
  property bool showControls: true
  property int maxWidth: Style.space(240)
  property var tr: function(key, fallback) { return fallback !== undefined ? fallback : key }
  // The host routes these to its mode toggle, popup and wheel guard.
  signal toggleRequested()
  signal popupRequested()
  signal wheelMoved(int delta)

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
  readonly property bool playing: !!source && source.playing
  readonly property bool animate: !bar || bar.foregroundAnimationEnabled !== false
  readonly property color dimColor: Qt.darker(foreground, 1.6)

  readonly property bool lyricMode: Model.normalizedMode(mode) === "lyric"
  readonly property string lyric: source ? source.lyric : ""
  readonly property bool showingLyric: Model.showsLyric(mode, lyric)
  readonly property string trackText: source ? Model.trackLabel(source.title, source.artist) : ""

  // ---- Lyric pages. Measured with the font the line is drawn in.
  FontMetrics {
    id: lyricMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.italic: true
  }
  FontMetrics {
    id: titleMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  property var pages: []
  property int pageIndex: 0
  property int pageMs: 0

  function repaginate() {
    root.pages = root.showingLyric
      ? Model.paginate(root.lyric, root.maxWidth, function(t) { return lyricMetrics.advanceWidth(t) })
      : []
    root.pageIndex = 0
    // Read once, when the line starts: Canto's time-to-next-line counts down
    // in every frame, and a running Timer whose interval changes restarts.
    root.pageMs = source ? Model.pageInterval(root.pages.length, source.lineMs, source.lyricEndsInMs) : 0
  }
  onLyricChanged: repaginate()
  onMaxWidthChanged: repaginate()
  onFontFamilyChanged: repaginate()

  Timer {
    interval: Math.max(1, root.pageMs)
    repeat: true
    running: root.showingLyric && root.pageMs > 0 && root.pageIndex < root.pages.length - 1
    onTriggered: root.pageIndex = Math.min(root.pageIndex + 1, root.pages.length - 1)
  }

  readonly property string text: showingLyric
    ? (pages.length ? pages[Math.min(pageIndex, pages.length - 1)] : lyric)
    : trackText

  // Sticky per track: once a line has shown, the pill keeps its full width
  // (pages and breaks included), so the bar does not shift with each line.
  property bool lyricTrack: false
  readonly property string trackKey: source ? source.title + "\n" + source.artist : ""
  onTrackKeyChanged: lyricTrack = showingLyric
  onShowingLyricChanged: {
    if (showingLyric) lyricTrack = true
    repaginate()
  }

  readonly property real labelWidth: lyricMode && lyricTrack
    ? maxWidth
    : Math.min(maxWidth, Math.ceil(showingLyric ? lyricMetrics.advanceWidth(text) : titleMetrics.advanceWidth(text)))

  implicitWidth: vertical ? playButton.implicitWidth : row.implicitWidth
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Row {
      id: controls
      anchors.verticalCenter: parent.verticalCenter
      visible: root.showControls || root.vertical
      // Transport controls keep previous, play, next in every language.
      LayoutMirroring.enabled: false
      LayoutMirroring.childrenInherit: true

      BarIconButton {
        id: previousButton
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.vertical
        bar: root.bar
        text: "󰒮"
        slotSize: Style.bar.statusSlot
        dimmed: !(root.source && root.source.canPrevious)
        tooltipText: root.tr("canto.previous", "Previous")
        onPressed: function(b) { root.buttonPressed(b, function() { root.source.previous() }) }
        onWheelMoved: function(d) { root.wheelMoved(d) }
      }
      BarIconButton {
        id: playButton
        anchors.verticalCenter: parent.verticalCenter
        bar: root.bar
        text: root.playing ? "󰏤" : "󰐊"
        slotSize: Style.bar.statusSlot
        dimmed: !(root.source && root.source.canPlayPause)
        tooltipText: root.playing ? root.tr("canto.pause", "Pause") : root.tr("canto.play", "Play")
        onPressed: function(b) { root.buttonPressed(b, function() { root.source.playPause() }) }
        onWheelMoved: function(d) { root.wheelMoved(d) }
      }
      BarIconButton {
        id: nextButton
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.vertical
        bar: root.bar
        text: "󰒭"
        slotSize: Style.bar.statusSlot
        dimmed: !(root.source && root.source.canNext)
        tooltipText: root.tr("canto.next", "Next")
        onPressed: function(b) { root.buttonPressed(b, function() { root.source.next() }) }
        onWheelMoved: function(d) { root.wheelMoved(d) }
      }
    }

    // The text area: the mode glyph and the text. Click switches the mode.
    Item {
      id: textArea
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.vertical && root.trackText !== ""
      readonly property real leftPad: controls.visible ? Style.space(11) : Style.space(8)
      readonly property real rightPad: Style.space(8)
      width: leftPad + glyph.implicitWidth + Style.space(7) + root.labelWidth + rightPad
      height: root.implicitHeight

      Text {
        id: glyph
        x: textArea.leftPad
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.lyricMode ? "󰍬" : "󰝚"
        // Lyric mode without a line to show: the microphone dims.
        color: (root.lyricMode && !root.showingLyric) || !root.playing ? root.dimColor : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      FadeText {
        id: label
        x: glyph.x + glyph.implicitWidth + Style.space(7)
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth
        height: root.implicitHeight
        clip: true
        text: root.text
        color: root.playing ? root.foreground : Qt.darker(root.foreground, 1.3)
        fontFamily: root.fontFamily
        pixelSize: Style.font.body
        // A lyric line is set in italic, so it never reads as a title.
        italic: root.showingLyric
        animate: root.animate
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(mouse) {
          if (root.bar) root.bar.hideTooltip(textArea)
          if (mouse.button === Qt.RightButton) root.popupRequested()
          else if (mouse.button === Qt.MiddleButton) { if (root.source) root.source.next() }
          else root.toggleRequested()
        }
        onWheel: function(wheel) { root.wheelMoved(wheel.angleDelta.y) }
        onEntered: if (root.bar) root.bar.showTooltip(textArea, root.tooltip())
        onExited: if (root.bar) root.bar.hideTooltip(textArea)
      }
    }
  }

  // Buttons: left runs the action, right opens the popup, middle skips.
  function buttonPressed(button, action) {
    if (!root.source) return
    if (button === Qt.RightButton) root.popupRequested()
    else if (button === Qt.MiddleButton) root.source.next()
    else action()
  }

  // The track (handy while the text shows a lyric), what a click does, and
  // in lyric mode without the bridge, where to turn it on.
  function tooltip() {
    if (!root.source) return ""
    var lines = [root.trackText]
    lines.push(root.lyricMode ? root.tr("canto.clickForTitle", "Click to show the title")
                              : root.tr("canto.clickForLyric", "Click to show the lyric line"))
    if (root.lyricMode && !root.source.bridgeAvailable)
      lines.push(root.tr("canto.bridgeHint", "Lyrics show here when Visual Bridge is on in Canto (Preferences, Integrations)."))
    return lines.join("\n")
  }
}
