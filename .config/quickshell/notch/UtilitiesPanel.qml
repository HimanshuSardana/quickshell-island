import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Utilities menu, opened with SUPER+period. A search field sits on top; below
// it are the services that have their own panel (wifi, bluetooth) plus local
// toggles (blue-light filter, VPN/WARP). Picking a service switches to it,
// while a toggle acts in place and updates its own status text.
//
// State comes from nmcli / bluetoothctl (both already ship on this box:
// NetworkManager and BlueZ are the active daemons), from warp-cli for the
// VPN toggle, and from pgrep for the blue-light helper (hyprsunset on
// Hyprland, wlsunset elsewhere).
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

    // ---- VPN / Cloudflare WARP (in-place toggle, warp-cli + ip-api.com) ----
    property string vpnState: "..." // raw warp-cli status line
    property bool vpnConnected: false
    property bool vpnConnecting: false
    property bool vpnBusy: false
    property string vpnCity: ""
    property string vpnCountry: ""

    readonly property string vpnLocation: {
        if (vpnCity.length > 0 && vpnCountry.length > 0)
            return vpnCity + ", " + vpnCountry;
        return vpnCountry;
    }

    readonly property string vpnStatus: {
        const loc = vpnLocation.length > 0 ? " \u00B7 " + vpnLocation : "";
        if (vpnBusy || vpnConnecting)
            return "\u2026";
        if (vpnState === "...")
            return "";
        return (vpnConnected ? "on" : "off") + loc;
    }

    // Static rows: status text is read live via statusFor() in the delegate,
    // so status updates never replace the list model (replacing it reset the
    // view to the top entry, e.g. right after pressing Enter on VPN).
    readonly property var entries: [
        { key: "wifi", glyph: "\uF1EB", label: "Wi-Fi", accent: Theme.blue },
        { key: "bluetooth", glyph: "\uF293", label: "Bluetooth", accent: Theme.mauve },
        { key: "vpn", glyph: "\uF023", label: "VPN \u00B7 WARP", accent: Theme.teal },
        { key: "bluelight", glyph: "\uF186", label: "Blue Light Filter", accent: Theme.peach },
        { key: "caffeine", glyph: "\uF0F4", label: "Caffeine Mode", accent: Theme.yellow },
        { key: "media", glyph: "\uF001", label: "Now Playing", accent: Theme.mauve },
        { key: "visualizer", glyph: "\uF028", label: "Audio Visualizer", accent: Theme.teal }
    ]

    function statusFor(key) {
        if (key === "wifi")
            return wifiStatus;
        if (key === "bluetooth")
            return btStatus;
        if (key === "vpn")
            return vpnStatus;
        if (key === "bluelight")
            return blueLightStatus;
        if (key === "caffeine")
            return ShellState.caffeine ? "on" : "off";
        return "";
    }

    // Search filters the rows by label or status. Rebuilt imperatively on
    // query change only, so async status updates cannot yank the selection.
    property var filtered: []

    function rebuildFiltered() {
        const q = query.toLowerCase();
        if (!q) {
            filtered = entries.slice();
            return;
        }
        filtered = entries.filter(e => e.label.toLowerCase().includes(q) || statusFor(e.key).toLowerCase().includes(q));
    }

    Component.onCompleted: rebuildFiltered()

    function refresh() {
        wifiRadioProc.running = false;
        wifiRadioProc.running = true;
        wifiSsidProc.running = false;
        wifiSsidProc.running = true;
        btShowProc.running = false;
        btShowProc.running = true;
        btDevicesProc.running = false;
        btDevicesProc.running = true;
        vpnStatusProc.running = false;
        vpnStatusProc.running = true;
        vpnIpProc.running = false;
        vpnIpProc.running = true;
        refreshBlueLight();
    }

    function toggleVpn() {
        if (vpnBusy)
            return;
        vpnBusy = true;
        toggleVpnProc.command = (vpnConnected || vpnConnecting)
            ? ["warp-cli", "disconnect"]
            : ["warp-cli", "connect"];
        toggleVpnProc.running = false;
        toggleVpnProc.running = true;
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
        if (entry.key === "vpn") {
            toggleVpn();
            return;
        }
        if (entry.key === "bluelight") {
            toggleBlueLight();
            return;
        }
        if (entry.key === "caffeine") {
            ShellState.caffeine = !ShellState.caffeine;
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

    onQueryChanged: {
        rebuildFiltered();
        selectedIndex = 0;
    }

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

    Process {
        id: vpnStatusProc

        command: ["sh", "-c", "warp-cli status 2>&1"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t.length === 0)
                    return;
                if (/Unable to connect.*daemon/i.test(t)) {
                    root.vpnState = "Daemon offline";
                    root.vpnConnected = false;
                    root.vpnConnecting = false;
                    return;
                }
                const m = t.match(/Status update:\s*(.+)/i);
                const s = (m ? m[1] : t.split("\n")[0]).trim();
                root.vpnState = s;
                root.vpnConnected = /^connected/i.test(s);
                root.vpnConnecting = /^connecting/i.test(s);
            }
        }
    }

    Process {
        id: vpnIpProc

        command: ["sh", "-c", "curl -s --max-time 6 'http://ip-api.com/json/?fields=status,country,city'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text);
                    if (o && o.status === "success") {
                        root.vpnCity = o.city || "";
                        root.vpnCountry = o.country || "";
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: toggleVpnProc

        running: false

        stdout: StdioCollector { id: vpnToggleOut; waitForEnd: true }
        stderr: StdioCollector { id: vpnToggleErr; waitForEnd: true }

        onExited: (code, status) => {
            root.vpnBusy = false;
            vpnSettleTimer.restart();
        }
    }

    // WARP takes a moment to settle after connect/disconnect.
    Timer {
        id: vpnSettleTimer

        interval: 2500
        repeat: false
        onTriggered: root.refresh()
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
                        text: root.statusFor(row.modelData.key)
                        color: ((row.modelData.key === "bluelight" && root.blueLightOn) || (row.modelData.key === "vpn" && root.vpnConnected) || (row.modelData.key === "caffeine" && ShellState.caffeine)) ? Theme.green : Theme.overlay0
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
