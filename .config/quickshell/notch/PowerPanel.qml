import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Power menu: four actions in a row.
//
// Icons only (no labels) at the request of the design: power / restart / lock /
// moon, all verified present in Iosevka Nerd Font. The glyph is muted until
// selected, then takes the action's accent colour so the destructive entries
// read as such without shouting when idle.
FocusScope {
    id: root

    property int selectedIndex: 0

    readonly property var actions: [
        { key: "shutdown", glyph: "\uF011", accent: Theme.red,    command: ["systemctl", "poweroff"] },
        { key: "restart",  glyph: "\uF021", accent: Theme.yellow, command: ["systemctl", "reboot"] },
        { key: "lock",     glyph: "\uF023", accent: Theme.blue,   command: null },
        { key: "sleep",    glyph: "\uF186", accent: Theme.mauve,  command: ["systemctl", "suspend"] }
    ]

    function takeInitialFocus() {
        selectedIndex = 0;
        root.forceActiveFocus(Qt.TabFocusReason);
    }

    function moveSelection(delta) {
        const n = actions.length;
        selectedIndex = ((selectedIndex + delta) % n + n) % n;
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    function activateIndex(i) {
        if (i < 0 || i >= actions.length)
            return;
        const action = actions[i];
        console.log("notch-power: " + action.key);
        // close first so the island is gone before the session goes down
        ShellState.close();

        // Lock is handled in-process: the lock screen lives in this shell
        // (ext-session-lock-v1), rather than an external locker.
        if (action.key === "lock") {
            ShellState.locked = true;
            return;
        }

        Quickshell.execDetached(action.command);
    }

    Keys.onLeftPressed: moveSelection(-1)
    Keys.onRightPressed: moveSelection(1)
    Keys.onReturnPressed: activateSelection()
    Keys.onEnterPressed: activateSelection()
    Keys.onEscapePressed: ShellState.close()

    Keys.onPressed: event => {
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_N) {
                moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_P) {
                moveSelection(-1);
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_H) {
            moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_L) {
            moveSelection(1);
            event.accepted = true;
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
            activateIndex(event.key - Qt.Key_1);
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        Repeater {
            model: root.actions

            delegate: Rectangle {
                id: tile

                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.rowRadius
                color: tile.index === root.selectedIndex ? Theme.itemSelected : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Text {
                    anchors.centerIn: parent
                    text: tile.modelData.glyph
                    color: tile.index === root.selectedIndex ? tile.modelData.accent : Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 26

                    Behavior on color {
                        ColorAnimation { duration: Theme.animFast }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = tile.index
                    onClicked: root.activateIndex(tile.index)
                }
            }
        }
    }
}
