import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Power menu: searchable row of actions, each an icon with its label beneath.
//
// The glyphs are power / restart / lock / moon, all verified present in Iosevka
// Nerd Font. An action's glyph is muted until selected, then takes that action's
// accent colour, so the destructive entries read as such without shouting when
// idle.
//
// Note the search field is why there are no single-letter shortcuts here
// (the old h/l and 1-4 bindings): once a TextInput has focus, plain letters are
// typed into it rather than reaching a Keys handler. Navigation is ctrl-n/p.
FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0

    readonly property var actions: [
        { key: "shutdown", label: "Shut down", glyph: "\uF011", accent: Theme.red,    command: ["systemctl", "poweroff"] },
        { key: "restart",  label: "Restart",   glyph: "\uF021", accent: Theme.yellow, command: ["systemctl", "reboot"] },
        { key: "lock",     label: "Lock",      glyph: "\uF023", accent: Theme.blue,   command: null },
        { key: "sleep",    label: "Sleep",     glyph: "\uF186", accent: Theme.mauve,  command: ["systemctl", "suspend"] }
    ]

    readonly property var filtered: actions.filter(a => {
        const q = query.toLowerCase();
        if (!q)
            return true;
        return a.label.toLowerCase().includes(q) || a.key.includes(q);
    })

    function takeInitialFocus() {
        // always start clean, same as the other panels
        search.text = "";
        query = "";
        selectedIndex = 0;
        search.forceActiveFocus(Qt.TabFocusReason);
    }

    onVisibleChanged: {
        if (!visible) {
            search.text = "";
            selectedIndex = 0;
        }
    }

    function moveSelection(delta) {
        const n = filtered.length;
        if (n === 0)
            return;
        selectedIndex = ((selectedIndex + delta) % n + n) % n;
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    function activateIndex(i) {
        if (i < 0 || i >= filtered.length)
            return;
        const action = filtered[i];
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

    onQueryChanged: selectedIndex = 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- search ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.searchHeight

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "\uF002"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 20
            }

            TextInput {
                id: search

                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                clip: true
                selectByMouse: true
                onTextChanged: root.query = text
                Keys.onReturnPressed: root.activateSelection()
                Keys.onEnterPressed: root.activateSelection()
                Keys.onEscapePressed: ShellState.close()

                // Left/Right stay with the cursor -- this is a text field -- so
                // the selection moves with ctrl-n/p like the other panels.
                Keys.onPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_N) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_P) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search power options"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: search.text.length === 0
                }
            }
        }

        // ---------- actions ----------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.gap

            RowLayout {
                anchors.fill: parent
                spacing: Theme.gap
                visible: root.filtered.length > 0

                Repeater {
                    model: root.filtered

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

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.modelData.glyph
                                color: tile.index === root.selectedIndex ? tile.modelData.accent : Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.iconSize

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animFast }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.modelData.label
                                color: tile.index === root.selectedIndex ? Theme.text : Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: 12

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animFast }
                                }
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

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: root.filtered.length === 0
                text: "No matching option"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
