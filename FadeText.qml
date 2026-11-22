import QtQuick
import qs.Commons

// Text that cross-fades when it changes: the new text fades in, rising a
// little, while the old one fades out in place. Two lines swap roles on each
// change; the hidden one takes the new text. Used for the pill label and the
// popup's lyric line.
Item {
  id: root

  property string text: ""
  property color color: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property real pixelSize: Style.font.body
  property bool italic: false
  property int wrapMode: Text.NoWrap
  property int maximumLineCount: 1
  property int horizontalAlignment: Text.AlignLeft
  property real rise: Style.space(5)
  property bool animate: true

  readonly property Text currentLine: flip ? lineB : lineA
  implicitWidth: currentLine.implicitWidth
  implicitHeight: currentLine.implicitHeight

  property bool flip: false
  onTextChanged: {
    if (flip) lineA.text = text
    else lineB.text = text
    flip = !flip
  }
  // The first text shows at once, without a fade.
  Component.onCompleted: lineA.text = text

  Text {
    id: lineA
    readonly property bool current: !root.flip
    width: root.width
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: current ? 0 : root.rise
    opacity: current ? 1 : 0
    textFormat: Text.PlainText
    elide: Text.ElideRight
    wrapMode: root.wrapMode
    maximumLineCount: root.maximumLineCount
    horizontalAlignment: root.horizontalAlignment
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
    font.italic: root.italic
    Behavior on opacity {
      enabled: root.animate
      NumberAnimation { duration: Style.duration(240); easing.type: Easing.InOutQuad }
    }
    Behavior on anchors.verticalCenterOffset {
      enabled: root.animate && lineA.current
      NumberAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic }
    }
  }

  Text {
    id: lineB
    readonly property bool current: root.flip
    width: root.width
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: current ? 0 : root.rise
    opacity: current ? 1 : 0
    textFormat: Text.PlainText
    elide: Text.ElideRight
    wrapMode: root.wrapMode
    maximumLineCount: root.maximumLineCount
    horizontalAlignment: root.horizontalAlignment
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
    font.italic: root.italic
    Behavior on opacity {
      enabled: root.animate
      NumberAnimation { duration: Style.duration(240); easing.type: Easing.InOutQuad }
    }
    Behavior on anchors.verticalCenterOffset {
      enabled: root.animate && lineB.current
      NumberAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic }
    }
  }
}
