import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Wi-Fi networks via nmcli (NetworkManager is the active daemon here).
//
// Two stages: the network list, and a password prompt when the chosen network
// is secured and not already known. Escape steps back to the list, then closes.
FocusScope {
    id: root

    property string stage: "list" // list | password
    property string query: ""
    property int selectedIndex: 0

    property var networks: []
    property string radio: ""
    property bool scanning: false
    property bool connecting: false
    property string message: ""
    property string pendingSsid: ""

    readonly property var filtered: networks.filter(n => {
        const q = query.toLowerCase();
        return !q || n.ssid.toLowerCase().includes(q);
    })

    // Row 0 is the radio toggle, so the list is reachable even when Wi-Fi is off.
    readonly property var rows: {
        const out = [{ kind: "radio" }];
        for (const n of filtered)
            out.push({ kind: "ap", ap: n });
        return out;
    }

    function takeInitialFocus() {
        stage = "list";
        // clear the TextInput itself, not just `query`: query is set *from*
        // search.text, so clearing only query left the old text in the box
        search.text = "";
        query = "";
        selectedIndex = 0;
        message = "";
        root.forceActiveFocus(Qt.TabFocusReason);
        refresh();
    }

    function refresh() {
        radioProc.running = false;
        radioProc.running = true;
        listProc.running = false;
        listProc.running = true;
    }

    function rescan() {
        scanning = true;
        message = "";
        listProc.running = false;
        rescanProc.running = false;
        rescanProc.running = true;
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

    function activateIndex(i) {
        if (i < 0 || i >= rows.length)
            return;
        const row = rows[i];
        if (row.kind === "radio") {
            toggleRadioProc.command = ["nmcli", "radio", "wifi", radio === "enabled" ? "off" : "on"];
            toggleRadioProc.running = false;
            toggleRadioProc.running = true;
            return;
        }

        const ap = row.ap;
        if (ap.secured) {
            pendingSsid = ap.ssid;
            stage = "password";
            password.text = "";
            password.forceActiveFocus(Qt.TabFocusReason);
            return;
        }
        connectTo(ap.ssid, "");
    }

    function connectTo(ssid, pw) {
        connecting = true;
        message = "";
        const cmd = ["nmcli", "dev", "wifi", "connect", ssid];
        if (pw.length > 0) {
            cmd.push("password");
            cmd.push(pw);
        }
        connectProc.command = cmd;
        connectProc.running = false;
        connectProc.running = true;
    }

    // nmcli terse mode escapes colons that appear inside a value.
    function splitTerse(line) {
        return line.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"));
    }

    function parseNetworks(raw) {
        const bySsid = {};
        for (const line of raw.split("\n")) {
            if (!line)
                continue;
            const f = splitTerse(line);
            if (f.length < 4)
                continue;
            const ssid = f[1];
            if (!ssid)
                continue;
            const signal = parseInt(f[2], 10);
            const security = f[3].trim();
            const connected = f[0].trim() === "*";
            const existing = bySsid[ssid];
            if (existing === undefined) {
                bySsid[ssid] = { ssid: ssid, signal: signal, security: security, secured: security.length > 0, connected: connected };
            } else {
                // same SSID seen on several BSSIDs: keep the strongest, OR the state
                if (signal > existing.signal)
                    existing.signal = signal;
                if (connected)
                    existing.connected = true;
            }
        }
        const out = Object.keys(bySsid).map(k => bySsid[k]);
        // connected first, then strongest first
        out.sort((a, b) => (a.connected === b.connected) ? (b.signal - a.signal) : (a.connected ? -1 : 1));
        return out;
    }

    onStageChanged: {
        if (stage === "list")
            root.forceActiveFocus(Qt.TabFocusReason);
    }

    // Escape steps back to the utilities menu rather than closing outright, so
    // the nested panels behave like a stack (SUPER+period closes from there).
    Keys.onEscapePressed: ShellState.show("utilities")

    Process {
        id: radioProc

        command: ["nmcli", "radio", "wifi"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                // a restart can deliver an empty chunk first; keep the last known value
                if (text.trim().length === 0)
                    return;
                root.radio = text.trim();
            }
        }
    }

    Process {
        id: listProc

        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0)
                    return;
                root.networks = root.parseNetworks(text);
            }
        }
    }

    Process {
        id: rescanProc

        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.networks = root.parseNetworks(text);
                root.scanning = false;
            }
        }
    }

    Process {
        id: toggleRadioProc

        running: false

        onExited: (code, status) => {
            root.message = code === 0 ? "" : "Could not toggle Wi-Fi";
            root.refresh();
        }
    }

    Process {
        id: connectProc

        running: false

        stdout: StdioCollector {
            id: connectOut
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: connectErr
            waitForEnd: true
        }

        onExited: (code, status) => {
            root.connecting = false;
            if (code === 0) {
                root.stage = "list";
                root.query = "";
                root.message = "";
                root.refresh();
            } else {
                // nmcli reports the reason on stderr, but a few paths use stdout
                const detail = (connectErr.text.trim() || connectOut.text.trim()).replace(/^Error:\s*/i, "");
                root.message = detail.length > 0 ? detail : "Could not connect";
                if (root.stage === "password")
                    root.stage = "list";
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- search / password ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.searchHeight

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.stage === "password" ? "\uF023" : "\uF002"
                color: root.stage === "password" ? Theme.mauve : Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 20
            }

            TextInput {
                id: search

                visible: root.stage === "list"
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
                            root.rescan();
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search networks"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: search.text.length === 0
                }
            }

            TextInput {
                id: password

                visible: root.stage === "password"
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                echoMode: TextInput.Password
                passwordCharacter: "•"
                clip: true
                onAccepted: root.connectTo(root.pendingSsid, password.text)
                Keys.onEscapePressed: {
                    root.stage = "list";
                    event.accepted = true;
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password for " + root.pendingSsid
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: password.text.length === 0
                }
            }
        }

        // ---------- networks ----------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.gap

            ListView {
                id: listView

                anchors.fill: parent
                visible: root.stage === "list"
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
                            visible: row.modelData.kind === "radio"
                            text: "\uF1EB"
                            color: root.radio === "enabled" ? Theme.blue : Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.kind === "radio" ? "Wi-Fi" : row.modelData.ap.ssid
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: row.modelData.kind === "ap"
                                text: row.modelData.kind === "ap"
                                    ? (row.modelData.ap.signal + "%" + (row.modelData.ap.secured ? " · " + row.modelData.ap.security : " · open"))
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
                                if (row.modelData.kind === "radio")
                                    return root.radio === "enabled" ? "on" : (root.radio === "disabled" ? "off" : "");
                                return row.modelData.ap.connected ? "\uF00C" : "";
                            }
                            color: row.modelData.kind === "radio" ? Theme.overlay0 : Theme.green
                            font.family: Theme.fontFamily
                            font.pixelSize: row.modelData.kind === "radio" ? 11 : 14
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

            // ---------- status ----------
            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: root.stage === "list" && root.filtered.length === 0
                text: root.scanning ? "Scanning…" : (root.radio === "disabled" ? "Wi-Fi is off" : "No networks found")
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
