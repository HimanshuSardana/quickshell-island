pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // "clock" | "launcher" | "clipboard" | "bookmarks" | "youtube" | "mail"
    // | "themes"
    // | "utilities" | "wifi" | "bluetooth" | "wallpapers" | "screenshot" | "power"
    // | "media" | "visualizer" | "screenrecord"
    property string panel: "clock"
    readonly property bool expanded: panel !== "clock"

    // True while a screenshot is being taken: the island hides itself so it
    // does not end up in the capture, and the surface unmaps so it cannot
    // swallow the region drag.
    property bool capturing: false

    // Session lock (ext-session-lock-v1, driven by LockScreen.qml)
    property bool locked: false

    // Caffeine mode: when true, idle/lock is inhibited via IdleInhibitor
    // (shell.qml) + a systemd-inhibit keeper for sleep/idle. Toggled from
    // the utilities menu (SUPER+period).
    property bool caffeine: false

    // Manual hide for the collapsed pill (alt+space). Suppresses only the
    // collapsed state; expanded panels and the OSD still appear.
    property bool notchHidden: false

    // ---- OSD (volume / brightness) ----
    property bool osdVisible: false
    property string osdKind: "volume" // "volume" | "brightness"
    property real osdValue: 0
    property bool osdMuted: false

    function showOsd(kind, value, muted) {
        osdKind = kind;
        osdValue = Math.max(0, Math.min(1, value));
        osdMuted = !!muted;
        osdVisible = true;
        osdTimer.restart();
    }

    // Auto-hide the OSD shortly after the last change.
    Timer {
        id: osdTimer

        interval: 1600
        repeat: false
        onTriggered: ShellState.osdVisible = false
    }

    // The screenshot panel resizes itself between its two stages.
    property int screenshotHeight: 104

    // ---- screen recording (wf-recorder, via ScreenRecordPanel.qml) ----
    property bool recording: false
    property string recordingFile: ""
    property double recordingStart: 0
    property int recordingElapsed: 0

    readonly property string recordingClock: {
        const m = Math.floor(recordingElapsed / 60);
        const s = recordingElapsed % 60;
        return (m < 10 ? "0" + m : "" + m) + ":" + (s < 10 ? "0" + s : "" + s);
    }

    // Elapsed recording clock, ticked while a recording is active.
    Timer {
        id: recTimer

        interval: 1000
        repeat: true
        running: ShellState.recording
        onTriggered: ShellState.recordingElapsed = Math.max(0, Math.round((Date.now() - ShellState.recordingStart) / 1000))
    }

    // ---- region selection (global layout coordinates) ----
    property bool regionSelecting: false
    property bool regionDragging: false
    property real regionStartX: 0
    property real regionStartY: 0
    property real regionCurrentX: 0
    property real regionCurrentY: 0
    property string regionGeom: ""

    readonly property real regionLeft: Math.min(regionStartX, regionCurrentX)
    readonly property real regionTop: Math.min(regionStartY, regionCurrentY)
    readonly property real regionRight: Math.max(regionStartX, regionCurrentX)
    readonly property real regionBottom: Math.max(regionStartY, regionCurrentY)
    readonly property real regionWidth: regionRight - regionLeft
    readonly property real regionHeight: regionBottom - regionTop

    // Wide/tall enough for battery + clock + cpu on the collapsed pill. The
    // height has to clear the 36px icons that flank the 12px clock.
    readonly property int collapsedWidth: recording ? 286 : 206
    readonly property int collapsedHeight: 48
    readonly property int osdHeight: 42
    readonly property int expandedWidth: 588

    // The launcher and themes panels report their own height so the island can
    // shrink to fit a short list instead of always using the full panel height.
    property int launcherHeight: 360
    property int themesHeight: 360

    // Fixed heights per panel. The island animates to a constant target so the
    // tween never fights live content (that was the original stutter), and each
    // panel's list absorbs the slack via Layout.fillHeight.
    readonly property var panelHeights: ({
        launcher: 360,
        clipboard: 360,
        mail: 360,
        bookmarks: 360,
        youtube: 360,
        themes: 360,
        utilities: 360,
        wifi: 360,
        bluetooth: 360,
        wallpapers: 360,
        screenshot: 104,
        screenrecord: 136,
        power: 152,
        media: 200,
        visualizer: 180
    })

    readonly property int targetHeight: !expanded
        ? (osdVisible ? osdHeight : collapsedHeight)
        : (panel === "screenshot"
            ? screenshotHeight
            : (panel === "launcher"
                ? launcherHeight
                : (panel === "themes" ? themesHeight : (panelHeights[panel] || 336))))

    function show(name) {
        if (!isPanel(name)) {
            console.log("notch: unknown panel '" + name + "' ignored");
            return;
        }
        panel = name;
    }

    function toggle(name) {
        if (!isPanel(name)) {
            console.log("notch: unknown panel '" + name + "' ignored");
            return;
        }
        panel = (panel === name) ? "clock" : name;
    }

    // A panel name with no implementation must never expand the island. Expanding
    // grants the surface EXCLUSIVE keyboard focus, so an unknown name would show an
    // empty card that swallows every keystroke in the session, with no panel visible
    // to press Escape in.
    function isPanel(name) {
        return name === "clock" || panelHeights[name] !== undefined;
    }

    function close() {
        capturing = false;
        regionSelecting = false;
        regionDragging = false;
        panel = "clock";
    }

    function beginRegion() {
        regionGeom = "";
        regionDragging = false;
        regionStartX = 0;
        regionStartY = 0;
        regionCurrentX = 0;
        regionCurrentY = 0;
        regionSelecting = true;
    }

    function startRegion(x, y) {
        regionDragging = true;
        regionStartX = x;
        regionStartY = y;
        regionCurrentX = x;
        regionCurrentY = y;
    }

    function updateRegion(x, y) {
        regionCurrentX = x;
        regionCurrentY = y;
    }

    function finishRegion(x, y) {
        regionCurrentX = x;
        regionCurrentY = y;
        regionDragging = false;

        // Compute the geometry BEFORE clearing regionSelecting: that assignment
        // notifies listeners synchronously, and the screenshot panel reads
        // regionGeom to decide between capturing and cancelling.
        const w = Math.round(Math.abs(regionCurrentX - regionStartX));
        const h = Math.round(Math.abs(regionCurrentY - regionStartY));
        if (w < 4 || h < 4)
            regionGeom = "";
        else
            regionGeom = Math.round(regionLeft) + "," + Math.round(regionTop) + " " + w + "x" + h;

        regionSelecting = false;
    }

    function cancelRegion() {
        regionGeom = "";
        regionDragging = false;
        regionSelecting = false;
    }
}
