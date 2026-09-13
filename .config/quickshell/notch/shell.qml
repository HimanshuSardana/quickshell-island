import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Notch / dynamic island.
//
//   collapsed : black pill flush to the top edge showing the time
//   expanded  : rounded card that grows into the requested panel
//
// Panels: launcher (SUPER+A), clipboard (SUPER+C), bookmarks (ALT+B),
// youtube (ALT+Y).
// Driven from the compositor:
//   qs -c notch ipc call notch toggle launcher
//   qs -c notch ipc call notch toggle clipboard
//   qs -c notch ipc call notch toggle bookmarks
//   qs -c notch ipc call notch close
ShellRoot {
    id: root

    IpcHandler {
        target: "notch"

        function toggle(name: string) {
            ShellState.toggle(name);
        }

        function show(name: string) {
            ShellState.show(name);
        }

        function close() {
            ShellState.close();
        }

        function lock() {
            ShellState.locked = true;
        }

        function volume(action: string) {
            let cmd = "";
            if (action === "up")
                cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
            else if (action === "down")
                cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            else if (action === "mute")
                cmd = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            if (cmd.length === 0)
                return;
            volumeProc.running = false;
            volumeProc.command = ["sh", "-c", cmd + " >/dev/null 2>&1; wpctl get-volume @DEFAULT_AUDIO_SINK@"];
            volumeProc.running = true;
        }

        function brightness(action: string) {
            const step = action === "down" ? "5%-" : "5%+";
            brightnessProc.running = false;
            brightnessProc.command = ["sh", "-c", "brightnessctl set " + step + " >/dev/null 2>&1; brightnessctl -m"];
            brightnessProc.running = true;
        }
    }

    // ---- volume / brightness changes, reported to the OSD ----
    Process {
        id: volumeProc

        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Volume:\s*([0-9.]+)(\s*\[MUTED\])?/);
                if (m)
                    ShellState.showOsd("volume", parseFloat(m[1]), !!m[2]);
            }
        }
    }

    Process {
        id: brightnessProc

        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/([0-9]+)%/);
                if (m)
                    ShellState.showOsd("brightness", parseInt(m[1], 10) / 100, false);
            }
        }
    }

    LockScreen {}

    // Region selection overlay: one per screen, driven by ShellState so the
    // screenshot panel can consume the geometry.
    Variants {
        model: Quickshell.screens

        RegionSelector {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            // Fixed canvas: only the island inside animates, so the
            // layer surface itself never resizes (keeps it smooth).
            readonly property int canvasWidth: 700
            readonly property int canvasHeight: 520

            anchors {
                top: true
                left: true
            }
            margins.left: Math.round((screen.width - canvasWidth) / 2)

            implicitWidth: canvasWidth
            implicitHeight: canvasHeight
            color: "transparent"
            aboveWindows: true
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore

            // Keyboard focus.
            // Mango only grants automatic keyboard focus to layer surfaces
            // whose keyboard interactivity is EXCLUSIVE; on-demand surfaces
            // stay unfocused until clicked. `focusable` maps to on-demand, so
            // set the layer-shell property directly.
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "notch"
            WlrLayershell.keyboardFocus: (ShellState.expanded && !ShellState.capturing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Hide during capture (so it cannot land in a screenshot) and while
            // the session is locked (the lock surface should own the screen).
            visible: !ShellState.capturing && !ShellState.locked

            // Clicks pass through everywhere except the island
            mask: Region {
                item: island
            }

            // Give the active panel keyboard focus whenever it opens
            Connections {
                target: ShellState

                function onPanelChanged() {
                    if (!ShellState.expanded)
                        return;
                    focusTimer.restart();
                }
            }

            Timer {
                id: focusTimer

                interval: 60
                repeat: false
                onTriggered: {
                    const p = activePanel();
                    if (p)
                        p.takeInitialFocus();
                }
            }

            function activePanel() {
                switch (ShellState.panel) {
                case "launcher":   return launcherPanel;
                case "clipboard":  return clipboardPanel;
                case "bookmarks":  return bookmarksPanel;
                case "youtube":    return youtubePanel;
                case "screenshot": return screenshotPanel;
                case "power":      return powerPanel;
                }
                return null;
            }

            // ---------------- island ----------------
            Item {
                id: island

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                width: ShellState.expanded
                    ? ShellState.expandedWidth
                    : (ShellState.osdVisible ? osdWidth : ShellState.collapsedWidth)
                height: ShellState.targetHeight

                // Notch geometry: `flare` is the concave shoulder that spreads
                // out to the screen edge at the top, `foot` is the convex radius
                // on the bottom corners. The body itself stays `width` wide.
                readonly property int osdWidth: 232
                property real flare: ShellState.expanded ? 16 : 10
                property real foot: ShellState.expanded ? 16 : 12
                property color fill: ShellState.expanded ? Theme.crust : "#000000"
                property color line: ShellState.expanded ? Theme.hairline : "transparent"

                // Hidden during capture so it never lands in the shot
                opacity: ShellState.capturing ? 0 : 1

                Behavior on opacity {
                    enabled: !ShellState.capturing
                    NumberAnimation { duration: Theme.animFast }
                }

                Behavior on width {
                    NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                }
                Behavior on flare {
                    NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                }
                Behavior on foot {
                    NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                }
                Behavior on fill {
                    ColorAnimation { duration: Theme.animFast }
                }

                // One path for the whole notch so the shoulders, straight sides
                // and rounded feet share a single fill and hairline outline.
                Shape {
                    id: islandShape

                    x: -island.flare
                    y: 0
                    width: island.width + island.flare * 2
                    height: island.height
                    antialiasing: true

                    readonly property real bw: island.width
                    readonly property real r: island.flare
                    readonly property real rb: island.foot

                    ShapePath {
                        fillColor: island.fill
                        strokeColor: island.line
                        strokeWidth: 1
                        joinStyle: ShapePath.RoundJoin

                        startX: 0
                        startY: 0

                        // top edge, shoulder tip to shoulder tip
                        PathLine { x: islandShape.bw + islandShape.r * 2; y: 0 }

                        // right shoulder: curves back in to the body
                        PathQuad {
                            x: islandShape.bw + islandShape.r
                            y: islandShape.r
                            controlX: islandShape.bw + islandShape.r
                            controlY: 0
                        }

                        // right side down to the foot
                        PathLine { x: islandShape.bw + islandShape.r; y: islandShape.height - islandShape.rb }

                        PathQuad {
                            x: islandShape.bw + islandShape.r - islandShape.rb
                            y: islandShape.height
                            controlX: islandShape.bw + islandShape.r
                            controlY: islandShape.height
                        }

                        // bottom edge
                        PathLine { x: islandShape.r + islandShape.rb; y: islandShape.height }

                        PathQuad {
                            x: islandShape.r
                            y: islandShape.height - islandShape.rb
                            controlX: islandShape.r
                            controlY: islandShape.height
                        }

                        // left side up, then the left shoulder out to the edge
                        PathLine { x: islandShape.r; y: islandShape.r }

                        PathQuad {
                            x: 0
                            y: 0
                            controlX: islandShape.r
                            controlY: 0
                        }
                    }
                }

                // ---------------- collapsed clock ----------------
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    opacity: (ShellState.expanded || ShellState.osdVisible) ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animFast }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 5
                        radius: 3
                        color: Theme.green
                    }

                    Text {
                        id: clock

                        anchors.verticalCenter: parent.verticalCenter
                        property var now: new Date()

                        text: Qt.formatDateTime(clock.now, "hh:mm")
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.letterSpacing: 0.3

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clock.now = new Date()
                        }
                    }
                }

                // ---------------- OSD (volume / brightness) ----------------
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    opacity: (ShellState.osdVisible && !ShellState.expanded) ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animFast }
                    }

                    Text {
                        id: osdIcon

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: ShellState.osdKind === "volume"
                            ? (ShellState.osdMuted ? "\uF026" : "\uF028")
                            : "\uF185"
                        color: ShellState.osdKind === "volume"
                            ? (ShellState.osdMuted ? Theme.red : Theme.blue)
                            : Theme.yellow
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    Text {
                        id: osdPercent

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(ShellState.osdValue * 100) + "%"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Rectangle {
                        anchors.left: osdIcon.right
                        anchors.right: osdPercent.left
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        radius: 3
                        color: Theme.surface0

                        Rectangle {
                            width: parent.width * ShellState.osdValue
                            height: parent.height
                            radius: 3
                            color: ShellState.osdKind === "volume"
                                ? (ShellState.osdMuted ? Theme.red : Theme.blue)
                                : Theme.yellow

                            Behavior on width {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !ShellState.expanded
                    onClicked: ShellState.show("launcher")
                }

                // ---------------- expanded body ----------------
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padH
                    anchors.rightMargin: Theme.padH
                    anchors.topMargin: Theme.padV
                    anchors.bottomMargin: Theme.padV
                    spacing: 0
                    opacity: ShellState.expanded ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animFast }
                    }

                    // active panel
                    LauncherPanel {
                        id: launcherPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "launcher"
                    }

                    ClipboardPanel {
                        id: clipboardPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "clipboard"
                    }

                    BookmarksPanel {
                        id: bookmarksPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "bookmarks"
                    }

                    YoutubePanel {
                        id: youtubePanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "youtube"
                    }

                    ScreenshotPanel {
                        id: screenshotPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "screenshot"
                    }

                    PowerPanel {
                        id: powerPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "power"
                    }
                }
            }
        }
    }
}
