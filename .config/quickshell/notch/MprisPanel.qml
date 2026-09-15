import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs

// Now Playing panel driven by MPRIS.
//
// `Mpris.players` is the list of all registered players. We show the one that
// is currently playing, falling back to the first available. Every property is
// re-read live from the player, so the panel follows track changes, pause/
// resume and seek without extra plumbing.
FocusScope {
    id: root

    readonly property var players: Mpris.players.values

    // Prefer a playing player; otherwise the first one that exists.
    readonly property var player: {
        const ps = players;
        if (!ps || ps.length === 0)
            return null;
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying)
                return ps[i];
        }
        return ps[0];
    }

    readonly property real progress: (player && player.length > 0)
        ? Math.max(0, Math.min(1, player.position / player.length))
        : 0

    readonly property bool hasPlayer: player !== null

    function fmtTime(t) {
        t = Math.max(0, Math.floor(t || 0));
        const h = Math.floor(t / 3600);
        const m = Math.floor((t % 3600) / 60);
        const s = t % 60;
        const mm = (h > 0 && m < 10 ? "0" : "") + m;
        return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" : "") + s;
    }

    function takeInitialFocus() {
        root.forceActiveFocus(Qt.TabFocusReason);
    }

    Keys.onEscapePressed: ShellState.close()

    Keys.onSpacePressed: {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }
    Keys.onLeftPressed: {
        if (player && player.canSeek)
            player.seek(-5);
    }
    Keys.onRightPressed: {
        if (player && player.canSeek)
            player.seek(5);
    }

    // A compact icon button reused for prev / play-pause / next.
    component ControlButton: Rectangle {
        id: btn

        property string glyph
        property color tint: Theme.text
        property bool enabled: false

        signal activated

        implicitWidth: 34
        implicitHeight: 34
        radius: 8
        color: hover.containsMouse && btn.enabled ? Theme.itemHover : "transparent"

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: btn.enabled ? btn.tint : Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: 19

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }
        }

        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.enabled) btn.activated()
        }
    }

    // ---------- empty state ----------
    Text {
        anchors.centerIn: parent
        visible: !root.hasPlayer
        text: "Nothing playing"
        color: Theme.overlay0
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    // ---------- player ----------
    RowLayout {
        anchors.fill: parent
        visible: root.hasPlayer
        spacing: 16

        // album art (rounded, with a glyph placeholder behind it)
        ClippingRectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 116
            Layout.preferredHeight: 116
            radius: 12
            color: Theme.surface0
            border.width: 1
            border.color: Theme.hairline

            Text {
                anchors.centerIn: parent
                text: "\uF001"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 34
            }

            Image {
                anchors.fill: parent
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.player ? (root.player.trackTitle || "Unknown title") : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.player ? (root.player.trackAlbum || "") : ""
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
                visible: text.length > 0
            }

            Item { Layout.fillHeight: true }

            // progress bar (click to seek)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 12

                Rectangle {
                    id: track

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.surface1

                    Rectangle {
                        width: track.width * root.progress
                        height: parent.height
                        radius: parent.radius
                        color: Theme.mauve
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player && root.player.canSeek && root.player.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: mouse => {
                            if (!root.player || !root.player.canSeek || root.player.length <= 0)
                                return;
                            root.player.position = (mouse.x / track.width) * root.player.length;
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2

                Text {
                    text: root.player ? root.fmtTime(root.player.position) : "0:00"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.player && root.player.length > 0 ? root.fmtTime(root.player.length) : "--:--"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: 10

                ControlButton {
                    glyph: "\uF048"
                    tint: Theme.text
                    enabled: root.player && root.player.canGoPrevious
                    onActivated: root.player.previous()
                }

                ControlButton {
                    glyph: root.player && root.player.isPlaying ? "\uF04C" : "\uF04B"
                    tint: Theme.mauve
                    enabled: root.player && root.player.canTogglePlaying
                    onActivated: root.player.togglePlaying()
                }

                ControlButton {
                    glyph: "\uF051"
                    tint: Theme.text
                    enabled: root.player && root.player.canGoNext
                    onActivated: root.player.next()
                }
            }
        }
    }
}
