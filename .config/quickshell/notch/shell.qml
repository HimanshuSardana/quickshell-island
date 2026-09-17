import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs

// Notch / dynamic island.
//
//   collapsed : black pill flush to the top edge showing the time
//   expanded  : rounded card that grows into the requested panel
//
// Panels: launcher (SUPER+A), clipboard (SUPER+C), bookmarks (ALT+B),
// youtube (ALT+Y), mail (SUPER+E), themes (SUPER+T), screenshot (SUPER+S),
// screenrecord (SUPER+SHIFT+S).
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

        function openMail(id: string) {
            // Same command the mail list's click handler runs; exposed here so
            // the open path can be driven and tested without a pointer.
            Quickshell.execDetached(["carbon", "open", id]);
            ShellState.close();
        }

        function lock() {
            ShellState.locked = true;
        }

        // Caffeine mode: inhibit idle/sleep so the session never auto-locks.
        function caffeine() {
            ShellState.caffeine = !ShellState.caffeine;
        }

        // Toggle the collapsed pill on/off (SUPER+period style manual hide).
        function toggleNotch() {
            ShellState.notchHidden = !ShellState.notchHidden;
        }

        function theme(id: string) {
            ThemeManager.activate(id);
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

    // Caffeine keeper: while ShellState.caffeine is true this holds a
    // logind inhibitor for idle + sleep, so the session neither auto-locks
    // (compositor idle) nor suspends. Killing the shell releases it.
    Process {
        id: caffeineKeeper
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=notch", "--why=Caffeine mode", "sleep", "infinity"]
        running: ShellState.caffeine
    }

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

            // green while charging/full, red when low, otherwise muted
            readonly property color batteryColor: {
                const d = UPower.displayDevice;
                if (d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.FullyCharged)
                    return Theme.green;
                if (d.percentage <= 0.15)
                    return Theme.red;
                return Theme.subtext;
            }

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

            // Mango's scene order (from its Lyr* enum) is:
            //   LyrTile < LyrFloat < LyrTop < LyrFullscreen < ... < LyrOverlay
            // so a fullscreen client covers LyrTop. The island therefore lives on
            // Overlay permanently, which makes expanded panels reachable even
            // when a fullscreen window is focused, and the collapsed pill is
            // suppressed explicitly instead of relying on being covered.
            //
            // (Switching the layer at runtime does not work: Mango only places a
            // layer surface into its scene when the surface is mapped,
            // wl_list_insert(&l->mon->layers[...]), and never re-parents it on a
            // later commit.)
            //
            // Note this is a layer-shell property, not a visibility flag.
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "notch"
            WlrLayershell.keyboardFocus: (ShellState.expanded && !ShellState.capturing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Caffeine mode: Wayland idle-inhibit bound to this surface, so
            // the compositor never considers the session idle while on.
            IdleInhibitor {
                window: win
                enabled: ShellState.caffeine
            }

            // Focused fullscreen client, straight from wlr-foreign-toplevel
            // (Mango implements it), so this is event-driven rather than polled.
            readonly property bool fullscreenFocused: {
                const t = ToplevelManager.activeToplevel;
                return t !== null && t !== undefined && t.fullscreen === true;
            }

            // Only the collapsed pill is ever suppressed, by the manual toggle
            // (alt+space) or by a focused fullscreen window. Expanded panels and
            // the transient OSD always show.
            readonly property bool pillSuppressed: !ShellState.expanded && !ShellState.osdVisible
                && (ShellState.notchHidden || fullscreenFocused)

            // Unmap entirely only for capture (so it cannot land in a screenshot)
            // and while the session is locked. The hide toggle slides the island
            // out instead, so it needs the surface to stay mapped.
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
                    if (!p || !p.visible) {
                        // Expanded with nothing to show: never leave the island
                        // holding the session's keyboard.
                        console.log("notch: no visible panel for '" + ShellState.panel + "', closing");
                        ShellState.close();
                        return;
                    }
                    p.takeInitialFocus();
                    focusVerify.restart();
                }
            }

            // Safety net: expanding takes EXCLUSIVE keyboard focus, so if the
            // panel then fails to take focus, every keystroke in the session
            // would go nowhere with no visible way out. Collapse instead.
            Timer {
                id: focusVerify

                interval: 150
                repeat: false
                onTriggered: {
                    const p = activePanel();
                    const focused = win.activeFocusItem !== null
                        || (p && (p.activeFocus || p.activeFocusItem !== null));
                    if (ShellState.expanded && !focused) {
                        console.log("notch: panel '" + ShellState.panel + "' took no focus, closing");
                        ShellState.close();
                    }
                }
            }

            function activePanel() {
                switch (ShellState.panel) {
                case "launcher":   return launcherPanel;
                case "clipboard":  return clipboardPanel;
                case "mail":       return mailPanel;
                case "bookmarks":  return bookmarksPanel;
                case "youtube":    return youtubePanel;
                case "themes":     return themesPanel;
                case "screenshot": return screenshotPanel;
                case "screenrecord": return screenRecordPanel;
                case "power":      return powerPanel;
                case "media":      return mprisPanel;
                case "visualizer": return visualizerPanel;
                case "utilities":  return utilitiesPanel;
                case "wifi":       return wifiPanel;
                case "bluetooth":  return bluetoothPanel;
                case "wallpapers": return wallpaperPanel;
                }
                return null;
            }

            // ---------------- island ----------------
            Item {
                id: island

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                // Slide up out of view when suppressed -- the manual hide toggle
                // (alt+space) or a focused fullscreen client. The surface stays
                // mapped (unlike capture/lock) so this can animate, and sliding
                // fully clear means the input region goes with it.
                anchors.topMargin: win.pillSuppressed ? -(height + 8) : 0

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
                property color fill: Theme.crust
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
                Behavior on anchors.topMargin {
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

                // ---------------- collapsed: battery · clock · cpu ----------------
                Row {
                    anchors.centerIn: parent
                    spacing: 9
                    opacity: (ShellState.expanded || ShellState.osdVisible) ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animFast }
                    }

                    // recording indicator, left of everything
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        visible: ShellState.recording

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9
                            height: 9
                            radius: 4.5
                            color: Theme.red

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: ShellState.recording
                                NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ShellState.recordingClock
                            color: Theme.red
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    // battery, left of the time
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        visible: UPower.displayDevice.isLaptopBattery

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uF240"
                            color: batteryColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 36
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                            color: batteryColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    // clock icon + time
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uF017"
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 36
                        }

                        Text {
                            id: clock

                            anchors.verticalCenter: parent.verticalCenter
                            property var now: new Date()

                            text: Qt.formatDateTime(clock.now, "hh:mm")
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.letterSpacing: 0.3

                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: {
                                    // The pill only shows hh:mm, so only reassign when the
                                    // displayed minute actually changes. Touching `now`
                                    // every second repainted the island 60x more often
                                    // than needed.
                                    if (Qt.formatDateTime(new Date(), "hh:mm") !== clock.text)
                                        clock.now = new Date();
                                }
                            }
                        }
                    }

                    // cpu, right of the time
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uF2DB"
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 36
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(SysStats.usage * 100) + "%"
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
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
                        font.pixelSize: 20
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
                        height: 8
                        radius: 4
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

                    MailPanel {
                        id: mailPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "mail"
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

                    ThemesPanel {
                        id: themesPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "themes"
                    }

                    ScreenshotPanel {
                        id: screenshotPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "screenshot"
                    }

                    ScreenRecordPanel {
                        id: screenRecordPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "screenrecord"
                    }

                    PowerPanel {
                        id: powerPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "power"
                    }

                    MprisPanel {
                        id: mprisPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "media"
                    }

                    VisualizerPanel {
                        id: visualizerPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "visualizer"
                    }

                    UtilitiesPanel {
                        id: utilitiesPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "utilities"
                    }

                    WifiPanel {
                        id: wifiPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "wifi"
                    }

                    BluetoothPanel {
                        id: bluetoothPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "bluetooth"
                    }

                    WallpaperPanel {
                        id: wallpaperPanel

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ShellState.panel === "wallpapers"
                    }
                }
            }
        }
    }
}
