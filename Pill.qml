import QtQuick
import qs.Commons
import "Model.js" as Model

// The bar pill: a music glyph and "Title · Artist", or the current synced
// lyric line. A new line cross-fades in, rising a little. While a track has
// synced lyrics the pill keeps its full width, so the bar does not shift with
// every line; otherwise it fits the text up to maxWidth. Vertical bars get the
// glyph alone, like Omarchy's media widget.
Item {
  id: root

  property QtObject bar: null
  property var source: null
  property bool showLyric: true
  property int maxWidth: Style.space(240)

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
  readonly property bool playing: !!source && source.playing
  readonly property bool animate: !bar || bar.foregroundAnimationEnabled !== false
  readonly property color textColor: playing ? foreground : Qt.darker(foreground, 1.3)

  readonly property string lyric: showLyric && source ? source.lyric : ""
  readonly property string text: source ? Model.pillText(showLyric, lyric, source.title, source.artist) : ""
  readonly property bool showingLyric: lyric !== ""

  // Sticky per track: once a line has shown, gaps between lines (an
  // instrumental break) fall back to the track at the same width.
  property bool lyricTrack: false
  readonly property string trackKey: source ? source.title + "\n" + source.artist : ""
  onTrackKeyChanged: lyricTrack = showingLyric
  onShowingLyricChanged: if (showingLyric) lyricTrack = true

  readonly property real labelWidth: vertical ? 0
    : (lyricTrack && showLyric ? maxWidth : Math.min(maxWidth, Math.ceil(metrics.advanceWidth)))

  implicitWidth: vertical ? (bar ? bar.barSize : Style.bar.sizeHorizontal)
    : row.implicitWidth + Style.space(14)
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  TextMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    text: root.text
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: root.vertical ? 0 : Style.space(7)

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "󰝚"
      color: root.playing ? root.foreground : Qt.darker(root.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      Behavior on color {
        enabled: root.animate
        ColorAnimation { duration: Style.duration(160) }
      }
    }

    FadeText {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.vertical && root.text !== ""
      width: root.labelWidth
      height: root.implicitHeight
      clip: true
      text: root.text
      color: root.textColor
      fontFamily: root.fontFamily
      pixelSize: Style.font.body
      // A lyric line is set in italic, so it never reads as a title.
      italic: root.showingLyric
      animate: root.animate

      Behavior on width {
        enabled: root.animate
        NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
      }
    }
  }
}
