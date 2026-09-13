pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // "clock" | "launcher" | "clipboard" | "bookmarks" | "screenshot" | "power"
    property string panel: "clock"
    readonly property bool expanded: panel !== "clock"

    // True while a screenshot is being taken: the island hides itself so it
    // does not end up in the capture, and the surface unmaps so it cannot
    // swallow the region drag.
    property bool capturing: false

    // Session lock (ext-session-lock-v1, driven by LockScreen.qml)
    property bool locked: false

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

    readonly property int collapsedWidth: 104
    readonly property int collapsedHeight: 28
    readonly property int osdHeight: 42
    readonly property int expandedWidth: 588

    // The launcher reports its own height so the island can shrink to fit a
    // short result list instead of always using the full panel height.
    property int launcherHeight: 360

    // Fixed heights per panel. The island animates to a constant target so the
    // tween never fights live content (that was the original stutter), and each
    // panel's list absorbs the slack via Layout.fillHeight.
    readonly property var panelHeights: ({
        launcher: 360,
        clipboard: 360,
        bookmarks: 360,
        youtube: 360,
        screenshot: 104,
        power: 104
    })

    readonly property int targetHeight: !expanded
        ? (osdVisible ? osdHeight : collapsedHeight)
        : (panel === "screenshot"
            ? screenshotHeight
            : (panel === "launcher" ? launcherHeight : (panelHeights[panel] || 336)))

    function show(name) {
        panel = name;
    }

    function toggle(name) {
        panel = (panel === name) ? "clock" : name;
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
