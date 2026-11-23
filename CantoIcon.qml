import QtQuick
import QtQuick.Window
import Quickshell.Io
import qs.Commons

// Canto's symbolic app icon (assets/canto-symbolic.svg, copied from Canto,
// MIT), painted in `color` like the bar's other glyphs. The SVG's black fill
// is swapped for the color and the result handed to Image as a data URL, so
// it stays crisp at any scale and needs no shader.
Item {
  id: root

  property color color: "white"
  property real size: Style.bar.iconSize

  implicitWidth: size
  implicitHeight: size

  FileView {
    id: svgFile
    path: Qt.resolvedUrl("assets/canto-symbolic.svg")
    blockLoading: true
    printErrors: false
  }

  readonly property string svg: svgFile.text()

  // #rrggbb (opacity goes on the Image, the SVG fill stays opaque).
  function hex(c) {
    function two(v) { var h = Math.round(v * 255).toString(16); return h.length < 2 ? "0" + h : h }
    return "#" + two(c.r) + two(c.g) + two(c.b)
  }

  Image {
    anchors.centerIn: parent
    width: root.size
    height: root.size
    // Drawn at twice the device pixels it covers and mipmapped down: sharp
    // on screen, and in 2x captures too.
    sourceSize.width: px
    sourceSize.height: px
    smooth: true
    mipmap: true
    opacity: root.color.a
    // The file declares 16x16 and no viewBox, so a data URL would be drawn at
    // 16 px and scaled up: give it a viewBox and the pixel size it is shown at.
    readonly property int px: Math.max(1, Math.round(root.size * Screen.devicePixelRatio * 2))
    source: root.svg !== ""
      ? "data:image/svg+xml;utf8," + encodeURIComponent(root.svg
          .replace(/width="16"\s+height="16"/, 'width="' + px + '" height="' + px + '" viewBox="0 0 16 16"')
          .replace(/#000000/g, root.hex(root.color)))
      : ""
  }
}
