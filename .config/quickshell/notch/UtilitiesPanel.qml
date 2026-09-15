import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Utilities menu, opened with SUPER+period. A search field sits on top; below
// it are the services that have their own panel (wifi, bluetooth) plus local
// toggles (blue-light filter). Picking a service switches to it, while a
// toggle acts in place and updates its own status text.
//
// State comes from nmcli / bluetoothctl (both already ship on this box:
// NetworkManager and BlueZ are the active daemons), and from pgrep for the
// blue-light helper (hyprsunset on Hyprland, wlsunset elsewhere).
FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0

    // refreshed every time the menu opens
    property string wifiRadio: "" // enabled | disabled
    property string wifiSsid: ""
    property string btState: "" // on | off | blocked
    property int btDeviceCount: 0
    property bool blueLightOn: false

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

    readonly property string blueLightStatus: blueLightOn ? "on" : "off"

    readonly property var entries: [
        { key: "wifi", glyph: "\uF1EB", label: "Wi-Fi", status: wifiStatus, accent: Theme.blue },
        { key: "bluetooth", glyph: "\uF293", label: "Bluetooth", status: btStatus, accent: Theme.mauve },
        { key: "bluelight", glyph: "\uF186", label: "Blue Light Filter", status: blueLightStatus, accent: Theme.peach },
        { key: "media", glyph: "\uF001", label: "Now Playing", status: "", accent: Theme.mauve },
        { key: "visualizer", glyph: "\uF028", label: "Audio Visualizer", status: "", accent: Theme.teal }
    ]

    // Search filters the rows by label or status. Re-evaluates whenever the
    // query changes or a status property (e.g. blueLightOn) updates.
    readonly property var filtered: entries.filter(e => {
        const q = query.toLowerCase();
        if (!q)
            return true;
        return e.label.toLowerCase().includes(q) || e.status.toLowerCase().includes(q);
    })

    function refresh() {
        wifiRadioProc.running = false;
        wifiRadioProc.running = true;
        wifiSsidProc.running = false;
        wifiSsidProc.running = true;
        btShowProc.running = false;
        btShowProc.running = true;
        btDevicesProc.running = false;
        btDevicesProc.running = true;
        refreshBlueLight();
    }

    function refreshBlueLight() {
        blueLightProc.running = false;
        blueLightProc.running = true;
    }

    function takeInitialFocus() {
        search.text = "";
        query = "";
        selectedIndex = 0;
        search.forceActiveFocus(Qt.TabFocusReason);
        refresh();
    }

    function moveSelection(delta) {
        const n = filtered.length;
        if (n === 0)
            return;
        selectedIndex = ((selectedIndex + delta) % n + n) % n;
    }

    function activateIndex(i) {
        if (i < 0 || i >= filtered.length)
            return;
        const entry = filtered[i];
        if (entry.key === "bluelight") {
            toggleBlueLight();
            return;
        }
        ShellState.show(entry.key);
    }

    // Blue-light filter.
    //
    // hyprsunset needs hyprland-ctm-control-v1, and hyprshade drives hyprctl,
    // so neither can apply anything on a wlroots compositor. On mango the
    // equivalent is wlsunset, which speaks wlr-gamma-control (mango implements
    // it). Pick the tool that matches the running session.
    //
    // All of them apply a warm gamma while they run and restore the display on
    // exit, so "on" is just "make sure it is running" and "off" is "stop it".
    // execDetached keeps the helper alive independently of the shell.
    // Quickshell.env() returns null for unset variables, and String(null) is
    // "null" (not ""), so compare against the actual value instead.
    readonly property bool onHyprland: String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "").length > 0

    readonly property string blueLightBin: onHyprland ? "hyprsunset" : "wlsunset"

    // Fixed warm temperature the toggle applies, regardless of the time of day.
    readonly property int blueLightTemp: 4000

    function toggleBlueLight() {
        if (blueLightOn) {
            Quickshell.execDetached(["pkill", "-x", blueLightBin]);
        } else if (onHyprland) {
            Quickshell.execDetached(["hyprsunset", "-t", String(blueLightTemp)]);
        } else {
            // wlsunset only schedules by default; force it to a constant warm
            // temperature so the filter is time-independent. SIGUSR1 cycles
            // auto -> force-high -> force-low, so send it twice.
            Quickshell.execDetached(["wlsunset", "-t", String(blueLightTemp)]);
            forceLowTimer.remaining = 2;
            forceLowTimer.restart();
        }
        blueLightTimer.restart();
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    onQueryChanged: selectedIndex = 0

    onVisibleChanged: {
        if (!visible) {
            search.text = "";
            selectedIndex = 0;
        }
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

    // Give pkill / the new daemon a moment to settle before re-reading state.
    Timer {
        id: blueLightTimer

        interval: 250
        repeat: false
        onTriggered: root.refreshBlueLight()
    }

    // Pins wlsunset to its forced-low temperature: SIGUSR1 cycles
    // auto -> force-high -> force-low, so two signals are needed. They are
    // spaced out so the kernel does not coalesce them into one.
    Timer {
        id: forceLowTimer

        interval: 400
        repeat: true
        property int remaining: 0

        onTriggered: {
            Quickshell.execDetached(["pkill", "-USR1", "-x", "wlsunset"]);
            remaining -= 1;
            if (remaining <= 0)
                running = false;
        }
    }

    Process {
        id: blueLightProc

        command: ["pgrep", "-x", root.blueLightBin]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.blueLightOn = text.trim().length > 0
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
                Keys.onEscapePressed: ShellState.close()

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
                    text: "Search utilities"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: search.text.length === 0
                }
            }
        }

        // ---------- entries ----------
        ListView {
            id: listView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.gap
            clip: true
            currentIndex: root.selectedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            model: root.filtered

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
                        color: row.modelData.key === "bluelight" && root.blueLightOn ? Theme.green : Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 11

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }
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
}
