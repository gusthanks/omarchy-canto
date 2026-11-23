import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The popup's content, laid out like Canto's own mini player: the cover on
// the left; the title and artist; previous / play (an accent circle) / next,
// then the lyrics toggle and the heart on the right; a thin progress line.
// Below, with the lyrics toggle on, the line before, the current line and
// the next one, whole and wrapped. Reads everything from `source`
// (CantoSource.qml, or dev/MockCanto.qml in the harness). Clicking the cover
// or the title brings Canto's window up.
Item {
  id: root

  property var source: null
  property var tr: function(key, fallback) { return fallback !== undefined ? fallback : key }
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color background: Commons.Color.popups.background
  property string fontFamily: Style.font.family
  property bool animate: true
  // Off: no cover is loaded (the host turns it on while the popup is open).
  property bool loadArt: true
  // The lyrics toggle (saved by the host as popupLyrics).
  property bool showLyrics: true
  signal lyricsToggled()

  readonly property bool hasTrack: !!source && source.hasTrack
  readonly property bool playing: !!source && source.playing
  readonly property string lyric: source ? source.lyric : ""
  readonly property string previousLyric: source ? source.previousLyric : ""
  readonly property string nextLyric: source ? source.nextLyric : ""
  // Shown during an instrumental break too, when Canto knows the next line.
  readonly property bool hasLyrics: lyric !== "" || nextLyric !== ""
  readonly property bool showHint: showLyrics && hasTrack && !!source && !source.bridgeAvailable
  readonly property color dim: Qt.darker(foreground, 1.7)
  readonly property real coverSize: Style.space(64)

  implicitWidth: Style.space(360)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: 0

    Row {
      id: header
      width: parent.width
      spacing: Style.space(12)

      BorderSurface {
        id: cover
        anchors.verticalCenter: parent.verticalCenter
        width: root.coverSize
        height: root.coverSize
        // Omarchy's control radius: the square art sits inside it cleanly.
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
          Accessible.name: root.tr("canto.openAlbum", "Open the album in Canto")
          onClicked: root.source.openAlbum()
        }
      }

      Column {
        id: info
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - root.coverSize - header.spacing
        spacing: Style.space(2)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.hasTrack ? root.source.title : root.tr("canto.nothingPlaying", "Nothing playing in Canto")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          elide: Text.ElideRight
          MouseArea {
            anchors.fill: parent
            enabled: !!root.source && root.source.canRaise
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.source.raise()
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.hasTrack ? root.source.artist : ""
          visible: text !== ""
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        // previous / play / next on the left, lyrics and heart on the right.
        Item {
          width: parent.width
          height: playCircle.height + Style.space(4)
          // Transport controls keep previous, play, next in every language.
          LayoutMirroring.enabled: false
          LayoutMirroring.childrenInherit: true

          Row {
            anchors.left: parent.left
            anchors.leftMargin: -Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Button {
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰒮"
              tooltipText: root.tr("canto.previous", "Previous")
              foreground: root.foreground
              horizontalPadding: Style.space(7)
              verticalPadding: Style.space(5)
              enabled: !!root.source && root.source.canPrevious
              opacity: enabled ? 1.0 : 0.4
              onClicked: root.source.previous()
            }

            // Play / pause: an accent-filled circle, as in Canto.
            Item {
              id: playCircle
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(30)
              height: width
              opacity: root.source && root.source.canPlayPause ? 1.0 : 0.4
              readonly property color fill: playMouse.containsMouse ? Qt.lighter(root.accent, 1.12) : root.accent
              onFillChanged: disc.requestPaint()
              // Painted once (and on hover): a smooth disc in every renderer.
              Canvas {
                id: disc
                anchors.fill: parent
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.fillStyle = playCircle.fill
                  ctx.beginPath()
                  ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2)
                  ctx.fill()
                }
              }
              Text {
                anchors.centerIn: parent
                // The play triangle sits optically a hair right of center.
                anchors.horizontalCenterOffset: root.playing ? 0 : Style.space(1)
                text: root.playing ? "󰏤" : "󰐊"
                color: root.background
                font.family: root.fontFamily
                font.pixelSize: Style.font.iconLarge
              }
              MouseArea {
                id: playMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !!root.source && root.source.canPlayPause
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: root.playing ? root.tr("canto.pause", "Pause") : root.tr("canto.play", "Play")
                onClicked: root.source.playPause()
              }
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰒭"
              tooltipText: root.tr("canto.next", "Next")
              foreground: root.foreground
              horizontalPadding: Style.space(7)
              verticalPadding: Style.space(5)
              enabled: !!root.source && root.source.canNext
              opacity: enabled ? 1.0 : 0.4
              onClicked: root.source.next()
            }
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: -Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Button {
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󱀢"
              tooltipText: root.showLyrics ? root.tr("canto.hideLyrics", "Hide the lyrics") : root.tr("canto.showLyrics", "Show the lyrics")
              // On: the accent, as Canto's checked toggle.
              foreground: root.showLyrics ? root.accent : root.foreground
              horizontalPadding: Style.space(7)
              verticalPadding: Style.space(5)
              onClicked: root.lyricsToggled()
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              // Hidden while Canto cannot say (older Canto, not a Spotify track).
              visible: !!root.source && root.source.likedKnown
              iconText: root.source && root.source.liked ? "󰋑" : "󰋕"
              tooltipText: root.source && root.source.liked ? root.tr("canto.unlike", "Remove from Liked Songs") : root.tr("canto.like", "Save to Liked Songs")
              foreground: root.source && root.source.liked ? root.accent : root.foreground
              horizontalPadding: Style.space(7)
              verticalPadding: Style.space(5)
              onClicked: root.source.toggleLiked()
            }
          }
        }
      }
    }

    // The lyric: the line before, the current one (larger, set off by a thin
    // accent rule) and the next one. Whole lines, wrapped, never cut.
    Item { width: 1; height: Style.space(14); visible: lyricBlock.visible || hint.visible }

    Column {
      id: lyricBlock
      width: parent.width
      visible: root.showLyrics && root.hasLyrics
      spacing: Style.space(6)
      readonly property real indent: Style.space(12)

      Text {
        x: lyricBlock.indent
        width: parent.width - lyricBlock.indent
        visible: text !== ""
        textFormat: Text.PlainText
        text: root.previousLyric
        color: root.dim
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
          color: root.lyric !== "" ? root.foreground : root.dim
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
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }
    }

    Text {
      id: hint
      width: parent.width
      visible: root.showHint
      textFormat: Text.PlainText
      text: root.tr("canto.bridgeHint", "Lyrics show here when Visual Bridge is on in Canto (Preferences, Integrations).")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }

    // A thin progress line along the bottom, as on the mini player's edge.
    Item {
      width: parent.width
      height: Style.space(14) + line.height
      visible: !!root.source && root.source.progress >= 0
      Rectangle {
        id: line
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.max(1, Style.space(2))
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, root.source ? root.source.progress : 0))
          height: parent.height
          radius: parent.radius
          color: root.accent
        }
      }
    }
  }
}
