import QtQuick
import QtQuick.Window
import qs.Commons

// Canto's colorful app icon (assets/canto.png, Canto's own icon, MIT), the
// one the app menu shows, so the bar points at the same app at a glance.
// `dimmed` fades it (Canto closed), as a darker color does to a glyph.
Item {
  id: root

  property color color: "white"
  property bool dimmed: false
  property real size: Style.bar.iconSize

  implicitWidth: size
  implicitHeight: size

  Image {
    anchors.centerIn: parent
    width: root.size
    height: root.size
    source: Qt.resolvedUrl("assets/canto.png")
    // Decoded at twice the device pixels it covers and mipmapped down
    sourceSize.width: px
    sourceSize.height: px
    readonly property int px: Math.max(1, Math.round(root.size * Screen.devicePixelRatio * 2))
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    opacity: root.color.a * (root.dimmed ? 0.45 : 1)
  }
}
