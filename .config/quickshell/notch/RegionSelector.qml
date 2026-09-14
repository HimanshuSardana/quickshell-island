import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Fullscreen region selector.
//
// Replaces slurp: one overlay per screen, driven by ShellState so the
// screenshot panel can consume the resulting geometry. Everything outside the
// drag is dimmed by painting four bands around the selection rather than
// masking, which keeps it to plain rectangles.
//
// The geometry handed back is in global layout coordinates, which is what
// `grim -g` expects.
PanelWindow {
    id: root

    // NOTE: modelData is intentionally not declared here. Variants injects it at
    // the instantiation site in shell.qml (required property var modelData);
    // declaring it in both places leaves this one uninitialised and the window
    // never gets created. `screen` is likewise supplied from there.

    visible: ShellState.regionSelecting
    color: "transparent"
    focusable: visible
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notch-region"
    WlrLayershell.keyboardFocus: ShellState.regionSelecting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // selection in this screen's local coordinates, clamped to the screen
    readonly property real selLeft: Math.max(ShellState.regionLeft - screen.x, 0)
    readonly property real selTop: Math.max(ShellState.regionTop - screen.y, 0)
    readonly property real selRight: Math.min(ShellState.regionRight - screen.x, width)
    readonly property real selBottom: Math.min(ShellState.regionBottom - screen.y, height)
    readonly property real selWidth: Math.max(0, selRight - selLeft)
    readonly property real selHeight: Math.max(0, selBottom - selTop)
    readonly property bool hasSelection: ShellState.regionDragging && selWidth > 0 && selHeight > 0

    readonly property color dim: Qt.rgba(0, 0, 0, 0.35)

    FocusScope {
        id: selectionFocus

        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                ShellState.cancelRegion();
                event.accepted = true;
            }
        }

        // ---- dimmed surround ----
        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: root.hasSelection ? root.selTop : parent.height
            color: root.dim
        }
        Rectangle {
            x: 0
            y: root.hasSelection ? root.selBottom : 0
            width: parent.width
            height: root.hasSelection ? Math.max(0, parent.height - root.selBottom) : 0
            color: root.dim
        }
        Rectangle {
            x: 0
            y: root.selTop
            width: root.hasSelection ? root.selLeft : 0
            height: root.hasSelection ? root.selHeight : 0
            color: root.dim
        }
        Rectangle {
            x: root.hasSelection ? root.selRight : 0
            y: root.selTop
            width: root.hasSelection ? Math.max(0, parent.width - root.selRight) : 0
            height: root.hasSelection ? root.selHeight : 0
            color: root.dim
        }

        // ---- selection outline ----
        Rectangle {
            x: root.selLeft
            y: root.selTop
            width: root.selWidth
            height: root.selHeight
            visible: root.hasSelection
            color: "transparent"
            border.width: 1
            border.color: Theme.mauve
        }

        // ---- live dimensions ----
        Rectangle {
            id: dimensions

            readonly property bool shown: root.hasSelection && ShellState.regionWidth > 0 && ShellState.regionHeight > 0
            readonly property real cursorX: ShellState.regionCurrentX - root.screen.x
            readonly property real cursorY: ShellState.regionCurrentY - root.screen.y

            x: Math.max(8, Math.min(root.width - width - 8, cursorX + 14))
            y: Math.max(8, Math.min(root.height - height - 8, cursorY + 14))
            width: dimensionText.implicitWidth + 16
            height: 24
            visible: shown
            radius: 7
            color: Theme.crust
            border.width: 1
            border.color: Theme.hairline

            Text {
                id: dimensionText

                anchors.centerIn: parent
                text: Math.round(ShellState.regionWidth) + " × " + Math.round(ShellState.regionHeight)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        // ---- drag handling ----
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: true

            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    ShellState.cancelRegion();
                    return;
                }
                ShellState.startRegion(root.screen.x + mouse.x, root.screen.y + mouse.y);
            }
            onPositionChanged: mouse => ShellState.updateRegion(root.screen.x + mouse.x, root.screen.y + mouse.y)
            onReleased: mouse => ShellState.finishRegion(root.screen.x + mouse.x, root.screen.y + mouse.y)
            onCanceled: ShellState.cancelRegion()
        }
    }

    // Layer surfaces can take focus a beat after mapping.
    Timer {
        interval: 1
        running: root.visible
        onTriggered: selectionFocus.forceActiveFocus(Qt.ActiveWindowFocusReason)
    }
}
