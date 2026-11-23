import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The popup's content: cover, title, artists, album, the lyric (previous,
// current and next line, whole, wrapped) and previous / play-pause / next. Reads everything from `source`
// (CantoSource.qml, or dev/MockCanto.qml in the harness). Clicking the cover
// or the title brings Canto's window up.
Item {
  id: root

  property var source: null
  property var tr: function(key, fallback) { return fallback !== undefined ? fallback : key }
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property bool animate: true
  // Off: no cover is loaded (the host turns it on while the popup is open).
  property bool loadArt: true

  readonly property bool hasTrack: !!source && source.hasTrack
  readonly property string lyric: source ? source.lyric : ""
  readonly property string previousLyric: source ? source.previousLyric : ""
  readonly property string nextLyric: source ? source.nextLyric : ""
  // Shown during an instrumental break too, when Canto knows the next line.
  readonly property bool showLyrics: lyric !== "" || nextLyric !== ""
  readonly property bool showHint: !!source && hasTrack && !source.bridgeAvailable
  readonly property real coverSize: Style.space(76)

  implicitWidth: Style.space(340)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Style.space(14)

    Row {
      id: header
      width: parent.width
      spacing: Style.space(12)

      BorderSurface {
        id: cover
        width: root.coverSize
        height: root.coverSize
        radius: Style.spacing.labelGap
        color: Style.normalFillFor(root.foreground, root.accent)
        borderSpec: Border.controlSpec("normal", root.foreground, root.accent)

        // Decoded at the size it is drawn, not the size Canto serves it at.
        SizedImage {
          id: art
          anchors.fill: parent
          anchors.margins: Style.space(2)
          crop: true
          url: root.loadArt && root.source && root.source.artUrl ? root.source.artUrl : ""
          visible: url != ""
        }

        Text {
          anchors.centerIn: parent
          visible: !art.visible || art.status !== Image.Ready
          text: "󰝚"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.displayLarge
        }

        // On hover: a dimmed cover with an "open" glyph, Canto comes up on click.
        Rectangle {
          anchors.fill: art
          color: Qt.rgba(0, 0, 0, 0.45)
          opacity: coverMouse.containsMouse && root.source && root.source.canRaise ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: Style.duration(140) } }
          Text {
            anchors.centerIn: parent
            text: "󰏌"
            color: "white"
            font.family: root.fontFamily
            font.pixelSize: Style.font.iconLarge
          }
        }

        MouseArea {
          id: coverMouse
          anchors.fill: parent
          hoverEnabled: true
          enabled: !!root.source && root.source.canRaise
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          Accessible.role: Accessible.Button
          Accessible.name: root.tr("canto.open", "Open Canto")
          onClicked: root.source.raise()
        }
      }

      Column {
        id: info
        width: parent.width - root.coverSize - header.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.hasTrack ? root.source.title : root.tr("canto.nothingPlaying", "Nothing playing in Canto")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          elide: Text.ElideRight
          maximumLineCount: 2
          wrapMode: Text.Wrap
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.hasTrack ? root.source.artist : ""
          visible: text !== ""
          color: Qt.darker(root.foreground, 1.3)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.hasTrack ? root.source.album : ""
          visible: text !== ""
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    // The lyric: the line before, the current one (larger, set off by a thin
    // accent rule) and the next one. Whole lines, wrapped, never cut.
    Column {
      id: lyricBlock
      width: parent.width
      visible: root.showLyrics
      spacing: Style.space(6)
      readonly property real indent: Style.space(12)

      Text {
        x: lyricBlock.indent
        width: parent.width - lyricBlock.indent
        visible: text !== ""
        textFormat: Text.PlainText
        text: root.previousLyric
        color: Qt.darker(root.foreground, 1.7)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      Item {
        width: parent.width
        height: currentLine.implicitHeight

        Rectangle {
          width: Math.max(1, Style.space(2))
          height: parent.height
          radius: width / 2
          color: root.accent
        }

        Text {
          id: currentLine
          x: lyricBlock.indent
          width: parent.width - lyricBlock.indent
          textFormat: Text.PlainText
          // A break between verses: a quiet note until the next line.
          text: root.lyric !== "" ? root.lyric : "♪"
          color: root.lyric !== "" ? root.foreground : Qt.darker(root.foreground, 1.7)
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.italic: true
          wrapMode: Text.Wrap
        }
      }

      Text {
        x: lyricBlock.indent
        width: parent.width - lyricBlock.indent
        visible: text !== ""
        textFormat: Text.PlainText
        text: root.nextLyric
        color: Qt.darker(root.foreground, 1.7)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }
    }

    Text {
      width: parent.width
      visible: root.showHint
      textFormat: Text.PlainText
      text: root.tr("canto.bridgeHint", "Lyrics show here when Visual Bridge is on in Canto (Preferences, Integrations).")
      color: Qt.darker(root.foreground, 1.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(6)
      // Transport controls keep previous, play, next in every language.
      LayoutMirroring.enabled: false
      LayoutMirroring.childrenInherit: true

      Button {
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰒮"
        tooltipText: root.tr("canto.previous", "Previous")
        foreground: root.foreground
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        enabled: !!root.source && root.source.canPrevious
        opacity: enabled ? 1.0 : 0.4
        onClicked: root.source.previous()
      }

      Button {
        anchors.verticalCenter: parent.verticalCenter
        iconText: root.source && root.source.playing ? "󰏤" : "󰐊"
        tooltipText: root.source && root.source.playing ? root.tr("canto.pause", "Pause") : root.tr("canto.play", "Play")
        foreground: root.foreground
        horizontalPadding: Style.spacing.panelGap
        verticalPadding: Style.spacing.controlPaddingY
        iconSize: Style.font.iconLarge
        enabled: !!root.source && root.source.canPlayPause
        opacity: enabled ? 1.0 : 0.4
        onClicked: root.source.playPause()
      }

      Button {
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰒭"
        tooltipText: root.tr("canto.next", "Next")
        foreground: root.foreground
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        enabled: !!root.source && root.source.canNext
        opacity: enabled ? 1.0 : 0.4
        onClicked: root.source.next()
      }
    }
  }
}
