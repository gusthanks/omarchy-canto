import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "canto" as W

// Isolated dev harness. Runs in its own Quickshell instance (see dev/run.sh),
// never inside the live Omarchy shell, so testing and screenshots do not
// reload or restart the user's bar. All data is MOCK (dev/MockCanto.qml and
// dev/mock/state.json); Canto does not need to be running.
//
// MODE (env):
//   preview     floating window with the pill and the popup, to play with
//   bar         the pill showing Title · Artist          -> $OUT (png)
//   bar-lyric   the pill showing the synced lyric line   -> $OUT (png)
//   panel       the popup with cover, lyric and controls -> $OUT (png)
//   panel-hint  the popup with Visual Bridge off         -> $OUT (png)
ShellRoot {
  id: shell

  readonly property string mode: Quickshell.env("MODE") || "preview"
  readonly property string out: Quickshell.env("OUT") || ""
  readonly property bool capturing: mode !== "preview"
  readonly property bool headless: Quickshell.env("HEADLESS") === "1"
  property Item stage: null

  function save(item, path, scale, done) {
    item.grabToImage(function(r) {
      r.saveToFile(path)
      if (done) done()
    }, Qt.size(item.width * scale, item.height * scale))
  }

  Component {
    id: stageComponent
    Rectangle {
      id: stageRect
      color: Commons.Color.background
      width: loader.item ? loader.item.width : 10
      height: loader.item ? loader.item.height : 10
      Component.onCompleted: shell.stage = stageRect

      Loader {
        id: loader
        sourceComponent: shell.mode.indexOf("bar") === 0 ? barScene
          : shell.mode.indexOf("panel") === 0 ? panelScene : previewScene
      }
    }
  }

  // HEADLESS=1 (the dev/run.sh default): Qt's offscreen platform, nothing
  // reaches the desktop. Otherwise a background-layer surface below every
  // window. LayerStage is its own file: offscreen has no PanelWindow backend.
  LazyLoader {
    active: shell.capturing && !shell.headless
    source: "LayerStage.qml"
    onItemChanged: if (item) item.content = stageComponent
  }

  FloatingWindow {
    visible: !shell.capturing || shell.headless
    implicitWidth: offLoader.item ? offLoader.item.width : 10
    implicitHeight: offLoader.item ? offLoader.item.height : 10
    color: "transparent"
    Loader { id: offLoader; active: !shell.capturing || shell.headless; sourceComponent: stageComponent }
  }

  Timer {
    running: shell.capturing
    interval: 1200
    onTriggered: shell.save(shell.stage, shell.out, 2, function() { Qt.quit() })
  }

  // ------------------------------------------------------------ scenes

  // A strip of bar: a clock, the pill and a few status glyphs, so the pill is
  // seen at bar height, in the bar's colors, next to its neighbors.
  component BarStrip: Rectangle {
    id: strip
    property bool bridgeOn: true
    width: barRow.implicitWidth + Style.space(28)
    height: Style.bar.sizeHorizontal
    color: Commons.Color.bar.background

    MockCanto { id: mock; bridgeOn: strip.bridgeOn }

    Row {
      id: barRow
      anchors.centerIn: parent
      spacing: Style.space(14)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Sunday 22 Nov  9:41 PM"
        color: Commons.Color.bar.text
        font.family: Style.font.family
        font.pixelSize: Style.bar.iconFont
      }

      W.Pill {
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: implicitHeight
        bar: mock.bar
        source: mock
        showLyric: true
        maxWidth: Style.space(240)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰕾   󰖩   󰁹"
        color: Commons.Color.bar.text
        font.family: Style.font.family
        font.pixelSize: Style.bar.iconFont
      }
    }
  }

  Component {
    id: barScene
    BarStrip { bridgeOn: shell.mode === "bar-lyric" }
  }

  // The popup: NowPlayingView inside a frame shaped like the shell's popups.
  component PopupFrame: Rectangle {
    id: frame
    property bool bridgeOn: true
    readonly property int pad: Style.spacing.popupPadding
    width: view.implicitWidth + pad * 2
    height: view.implicitHeight + pad * 2
    color: Commons.Color.popups.background
    border.width: Math.max(1, Style.space(2))
    border.color: Commons.Color.popups.border
    radius: Style.cornerRadius

    MockCanto { id: popupMock; bridgeOn: frame.bridgeOn }

    W.NowPlayingView {
      id: view
      x: frame.pad
      y: frame.pad
      width: implicitWidth
      height: implicitHeight
      source: popupMock
      tr: popupMock.tr
      foreground: Commons.Color.popups.text
      animate: false
    }
  }

  Component {
    id: panelScene
    PopupFrame { bridgeOn: shell.mode !== "panel-hint" }
  }

  Component {
    id: previewScene
    Column {
      padding: Style.space(16)
      spacing: Style.space(16)
      BarStrip { bridgeOn: true }
      BarStrip { bridgeOn: false }
      PopupFrame { bridgeOn: true }
    }
  }
}
