import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Notch / dynamic island.
//
//   collapsed : black pill flush to the top edge showing the time
//   expanded  : rounded card that grows into the requested panel
//
// Panels: launcher (SUPER+A), clipboard (SUPER+C), bookmarks (ALT+B).
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
            WlrLayershell.keyboardFocus: ShellState.expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
                case "launcher":  return launcherPanel;
                case "clipboard": return clipboardPanel;
                case "bookmarks": return bookmarksPanel;
                }
                return null;
            }

            // ---------------- island ----------------
            Rectangle {
                id: island

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: ShellState.expanded ? 9 : 0

                width: ShellState.expanded ? ShellState.expandedWidth : ShellState.collapsedWidth
                height: ShellState.targetHeight

                radius: ShellState.expanded ? 18 : 15
                color: ShellState.expanded ? Theme.crust : "#000000"
                border.width: 1
                border.color: ShellState.expanded ? Theme.surface0 : "transparent"

                Behavior on width {
                    NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                }
                Behavior on anchors.topMargin {
                    NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                // ---------------- collapsed clock ----------------
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    opacity: ShellState.expanded ? 0 : 1
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

                MouseArea {
                    anchors.fill: parent
                    enabled: !ShellState.expanded
                    onClicked: ShellState.show("launcher")
                }

                // ---------------- expanded body ----------------
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 13
                    anchors.bottomMargin: 12
                    spacing: 9
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
                }
            }
        }
    }
}
