import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Bluetooth devices via bluetoothctl (BlueZ).
//
// Row 0 is the adapter power toggle. Esc steps back to the utilities menu.
FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0

    property var devices: []
    property bool powered: false
    property bool blocked: false
    property bool scanning: false
    property string message: ""

    readonly property var filtered: devices.filter(d => {
        const q = query.toLowerCase();
        return !q || d.name.toLowerCase().includes(q) || d.mac.toLowerCase().includes(q);
    })

    readonly property var rows: {
        const out = [{ kind: "adapter" }];
        for (const d of filtered)
            out.push({ kind: "device", device: d });
        return out;
    }

    readonly property string adapterStatus: powered ? "on" : (blocked ? "off · blocked" : "off")

    // bluetoothctl devices -> "Device AA:BB:CC:DD:EE:FF Name"
    readonly property string nameOf: ""

    function takeInitialFocus() {
        // clear the TextInput itself, not just `query` (see WifiPanel)
        search.text = "";
        query = "";
        selectedIndex = 0;
        message = "";
        root.forceActiveFocus(Qt.TabFocusReason);
        refresh();
    }

    function refresh() {
        showProc.running = false;
        showProc.running = true;
        devicesProc.running = false;
        devicesProc.running = true;
        pairedProc.running = false;
        pairedProc.running = true;
        connectedProc.running = false;
        connectedProc.running = true;
    }

    function moveSelection(delta) {
        const n = rows.length;
        if (n === 0)
            return;
        selectedIndex = Math.max(0, Math.min(n - 1, selectedIndex + delta));
        listView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    function run(cmd) {
        actionProc.command = cmd;
        actionProc.running = false;
        actionProc.running = true;
    }

    function activateIndex(i) {
        if (i < 0 || i >= rows.length)
            return;
        const row = rows[i];
        if (row.kind === "adapter") {
            run(["bluetoothctl", "power", powered ? "off" : "on"]);
            return;
        }
        // connect/disconnect: BlueZ pairs implicitly for known devices, and
        // `connect` is a no-op-safe way to bring a device up
        const d = row.device;
        run(["bluetoothctl", d.connected ? "disconnect" : "connect", d.mac]);
    }

    function scan() {
        scanning = true;
        message = "";
        run(["bluetoothctl", "--timeout", "8", "scan", "on"]);
    }

    // derive Paired/Connected flags from a MAC list
    function macSet(raw) {
        const set = {};
        for (const line of raw.split("\n")) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 2 && parts[0] === "Device")
                set[parts[1].toUpperCase()] = true;
        }
        return set;
    }

    function rebuild() {
        const raw = devicesOut.text;
        const paired = macSet(pairedOut.text);
        const connected = macSet(connectedOut.text);
        const out = [];
        for (const line of raw.split("\n")) {
            const trimmed = line.trim();
            if (!trimmed)
                continue;
            const parts = trimmed.split(/\s+/);
            if (parts.length < 3 || parts[0] !== "Device")
                continue;
            const mac = parts[1];
            const name = parts.slice(2).join(" ");
            out.push({
                mac: mac,
                name: name,
                paired: paired[mac.toUpperCase()] === true,
                connected: connected[mac.toUpperCase()] === true
            });
        }
        // connected first, then paired, then name
        out.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1;
        });
        root.devices = out;
    }

    Keys.onEscapePressed: ShellState.show("utilities")

    Process {
        id: showProc

        command: ["bluetoothctl", "show"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0)
                    return;
                root.powered = /Powered:\s*yes/.test(text);
                root.blocked = /PowerState:\s*off-blocked/.test(text);
                if (root.blocked && text.indexOf("Powered: yes") < 0)
                    root.message = "Adapter blocked by rfkill — run: rfkill unblock bluetooth";
            }
        }
    }

    Process {
        id: devicesProc

        command: ["bluetoothctl", "devices"]
        running: false

        stdout: StdioCollector {
            id: devicesOut
            waitForEnd: true
            onStreamFinished: root.rebuild()
        }
    }

    Process {
        id: pairedProc

        command: ["bluetoothctl", "devices", "Paired"]
        running: false

        stdout: StdioCollector {
            id: pairedOut
            waitForEnd: true
            onStreamFinished: root.rebuild()
        }
    }

    Process {
        id: connectedProc

        command: ["bluetoothctl", "devices", "Connected"]
        running: false

        stdout: StdioCollector {
            id: connectedOut
            waitForEnd: true
            onStreamFinished: root.rebuild()
        }
    }

    Process {
        id: actionProc

        running: false

        stdout: StdioCollector {
            id: actionOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: actionErr
            waitForEnd: true
        }

        onExited: (code, status) => {
            root.scanning = false;
            if (code !== 0) {
                const detail = (actionErr.text.trim() || actionOut.text.trim()).replace(/^Error:\s*/i, "");
                root.message = detail.length > 0 ? detail.split("\n")[0] : "Command failed";
            }
            root.refresh();
        }
    }

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
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onReturnPressed: root.activateSelection()
                Keys.onEnterPressed: root.activateSelection()
                Keys.onEscapePressed: ShellState.show("utilities")

                Keys.onPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_N) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_P) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_R) {
                            root.scan();
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search devices"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: search.text.length === 0
                }
            }
        }

        // ---------- devices ----------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.gap

            ListView {
                id: listView

                anchors.fill: parent
                clip: true
                currentIndex: root.selectedIndex
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                model: root.rows

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
                            visible: row.modelData.kind === "adapter"
                            text: "\uF293"
                            color: root.powered ? Theme.mauve : Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.kind === "adapter" ? "Bluetooth" : row.modelData.device.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: row.modelData.kind === "device"
                                text: row.modelData.kind === "device"
                                    ? (row.modelData.device.mac
                                        + (row.modelData.device.connected ? " · connected" : (row.modelData.device.paired ? " · paired" : "")))
                                    : ""
                                color: Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: {
                                if (row.modelData.kind === "adapter")
                                    return root.adapterStatus;
                                return row.modelData.device.connected ? "\uF00C" : "";
                            }
                            color: row.modelData.kind === "adapter" ? Theme.overlay0 : Theme.green
                            font.family: Theme.fontFamily
                            font.pixelSize: row.modelData.kind === "adapter" ? 11 : 14
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

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: root.filtered.length === 0
                text: root.scanning ? "Scanning…"
                    : (!root.powered ? "Bluetooth is off" : "No devices found — press ctrl+r to scan")
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width - 20
                visible: root.message.length > 0
                text: root.message
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
