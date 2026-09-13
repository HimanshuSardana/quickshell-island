pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // "clock" | "launcher" | "clipboard" | "bookmarks"
    property string panel: "clock"
    readonly property bool expanded: panel !== "clock"

    readonly property int collapsedWidth: 112
    readonly property int collapsedHeight: 30
    readonly property int expandedWidth: 588

    // Fixed heights per panel: the island height animates to a constant
    // target, never against live content (that caused the previous stutter).
    readonly property var panelHeights: ({
        launcher: 388,
        clipboard: 368,
        bookmarks: 368
    })

    readonly property int targetHeight: expanded
        ? (panelHeights[panel] || 376)
        : collapsedHeight

    function show(name) {
        panel = name;
    }

    function toggle(name) {
        panel = (panel === name) ? "clock" : name;
    }

    function close() {
        panel = "clock";
    }
}
