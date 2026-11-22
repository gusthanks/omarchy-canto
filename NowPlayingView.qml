import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The popup's content: cover, title, artists, album, the current lyric line
// and previous / play-pause / next. Reads everything from `source`
// (CantoSource.qml, or dev/MockCanto.qml in the harness). Clicking the cover
// or the title brings Canto's window up.
Item {
  id: root

  property var source: null
  property var tr: function(key, fallback) { return fallback !== undefined ? fallback : key }
  property bool showLyric: true
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property bool animate: true

  readonly property bool hasTrack: !!source && source.hasTrack
  readonly property string lyric: showLyric && source ? source.lyric : ""
  readonly property bool showHint: showLyric && !!source && hasTrack && !source.bridgeAvailable
  readonly property real coverSize: Style.space(76)

  implicitWidth: Style.space(340)
  implicitHeight: column.implicitHeight

  FontMetrics {
    id: lyricMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.subtitle
  }

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
          url: root.source && root.source.artUrl ? root.source.artUrl : ""
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

    // The synced line, set off by a thin accent rule. It keeps two lines of
    // room while the track has lyrics, so the popup does not jump between a
    // short line and a long one.
    Item {
      id: lyricBlock
      width: parent.width
      visible: root.lyric !== ""
      height: Math.ceil(lyricMetrics.lineSpacing * 2)

      Rectangle {
        width: Math.max(1, Style.space(2))
        height: parent.height
        radius: width / 2
        color: root.accent
      }

      FadeText {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(12)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        text: root.lyric
        color: root.foreground
        fontFamily: root.fontFamily
        pixelSize: Style.font.subtitle
        italic: true
        wrapMode: Text.Wrap
        maximumLineCount: 2
        animate: root.animate
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
