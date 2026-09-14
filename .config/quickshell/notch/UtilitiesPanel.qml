import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Utilities menu, opened with SUPER+period. Lists the services that have their
// own panel; picking one switches to it.
//
// State comes from nmcli / bluetoothctl (both already ship on this box:
// NetworkManager and BlueZ are the active daemons).
FocusScope {
    id: root

    property int selectedIndex: 0

    // refreshed every time the menu opens
    property string wifiRadio: "" // enabled | disabled
    property string wifiSsid: ""
    property string btState: "" // on | off | blocked
    property int btDeviceCount: 0

    readonly property string wifiStatus: {
        if (wifiRadio === "enabled")
            return wifiSsid.length > 0 ? "on · " + wifiSsid : "on";
        return wifiRadio === "disabled" ? "off" : "";
    }

    readonly property string btStatus: {
        if (btState === "on")
            return btDeviceCount > 0 ? "on · " + btDeviceCount + " device" + (btDeviceCount === 1 ? "" : "s") : "on";
        if (btState === "blocked")
            return "off · blocked";
        return btState === "off" ? "off" : "";
    }

    readonly property var entries: [
        { key: "wifi", glyph: "\uF1EB", label: "Wi-Fi", status: wifiStatus, accent: Theme.blue },
        { key: "bluetooth", glyph: "\uF293", label: "Bluetooth", status: btStatus, accent: Theme.mauve }
    ]

    function refresh() {
        wifiRadioProc.running = false;
        wifiRadioProc.running = true;
        wifiSsidProc.running = false;
        wifiSsidProc.running = true;
        btShowProc.running = false;
        btShowProc.running = true;
        btDevicesProc.running = false;
        btDevicesProc.running = true;
    }

    function takeInitialFocus() {
        selectedIndex = 0;
        root.forceActiveFocus(Qt.TabFocusReason);
        refresh();
    }

    function moveSelection(delta) {
        const n = entries.length;
        selectedIndex = ((selectedIndex + delta) % n + n) % n;
    }

    function activateIndex(i) {
        if (i < 0 || i >= entries.length)
            return;
        ShellState.show(entries[i].key);
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    Keys.onDownPressed: moveSelection(1)
    Keys.onUpPressed: moveSelection(-1)
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
        }
    }

    Process {
        id: wifiRadioProc

        command: ["nmcli", "radio", "wifi"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.wifiRadio = text.trim()
        }
    }

    Process {
        id: wifiSsidProc

        command: ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let found = "";
                for (const line of text.split("\n")) {
                    if (!line.startsWith("yes:"))
                        continue;
                    // terse mode escapes colons that appear inside the SSID
                    found = line.substring(4).replace(/\\:/g, ":");
                    break;
                }
                root.wifiSsid = found;
            }
        }
    }

    Process {
        id: btShowProc

        command: ["bluetoothctl", "show"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (/Powered:\s*yes/.test(text))
                    root.btState = "on";
                else if (/PowerState:\s*off-blocked/.test(text))
                    root.btState = "blocked";
                else
                    root.btState = "off";
            }
        }
    }

    Process {
        id: btDevicesProc

        command: ["bluetoothctl", "devices"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.btDeviceCount = text.split("\n").filter(l => l.trim().length > 0).length
        }
    }

    ListView {
        id: listView

        anchors.fill: parent
        clip: true
        currentIndex: root.selectedIndex
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            width: listView.width
            height: Theme.rowHeight
            radius: Theme.rowRadius
            color: ListView.isCurrentItem ? Theme.itemSelected : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 10
                spacing: 14

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Theme.iconSize
                    horizontalAlignment: Text.AlignHCenter
                    text: row.modelData.glyph
                    color: row.index === root.selectedIndex ? row.modelData.accent : Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 20

                    Behavior on color {
                        ColorAnimation { duration: Theme.animFast }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: row.modelData.label
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: row.modelData.status
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = row.index
                onClicked: root.activateIndex(row.index)
            }
        }
    }
}
