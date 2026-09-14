import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Screenshot menu.
//
//   stage 1  choose a mode        -> full screen | region
//   stage 2  pick a destination   -> copy to clipboard | save to ~/personal/pix
//
// Region selection is handled in-process by RegionSelector.qml (driven through
// ShellState) rather than by slurp, which never managed to present its overlay
// under Mango. Only grim is used, for the actual capture.
//
// While capturing, the island unmaps and drops keyboard focus; the selector then
// takes over the screen.
FocusScope {
    id: root

    property string stage: "choose" // choose | destination | unavailable | failed
    property int selectedIndex: 0
    property var rows: []

    property string shotPath: ""
    property string shotName: ""
    property string shotGeom: ""
    property string pendingMode: ""
    property string errorText: ""

    readonly property bool showMessage: stage === "unavailable" || stage === "failed"

    readonly property string message: stage === "unavailable"
        ? "grim is required:\n\nsudo pacman -S grim"
        : errorText

    readonly property string saveDir: String(Quickshell.env("HOME")) + "/personal/pix"

    function applyStage() {
        if (stage === "destination") {
            ShellState.screenshotHeight = 314;
            rows = [
                { label: "Copy to clipboard", hint: "", action: "copy" },
                { label: "Save to ~/personal/pix", hint: shotName, action: "save" }
            ];
        } else if (showMessage) {
            ShellState.screenshotHeight = 168;
            rows = [];
        } else {
            ShellState.screenshotHeight = 136;
            rows = [
                { label: "Full screen", hint: "all displays", action: "full" },
                { label: "Region", hint: "drag to select", action: "region" }
            ];
        }
        selectedIndex = 0;
    }

    function reset() {
        ShellState.capturing = false;
        ShellState.cancelRegion();
        stage = "choose";
        shotPath = "";
        shotName = "";
        shotGeom = "";
        pendingMode = "";
        errorText = "";
    }

    function takeInitialFocus() {
        reset();
        applyStage();
        root.forceActiveFocus(Qt.TabFocusReason);
        toolsProc.running = false;
        toolsProc.running = true;
    }

    function moveSelection(delta) {
        if (rows.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta));
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    function activateIndex(i) {
        if (i < 0 || i >= rows.length)
            return;
        const action = rows[i].action;
        console.log("notch-shot: activate index=" + i + " action=" + action);
        if (action === "full" || action === "region") {
            beginCapture(action);
        } else if (action === "copy") {
            copyProc.running = false;
            copyProc.running = true;
        } else if (action === "save") {
            saveProc.running = false;
            saveProc.running = true;
        }
    }

    function beginCapture(mode) {
        const ts = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        shotPath = "/tmp/notch-shot-" + ts + ".png";
        shotName = "screenshot-" + ts + ".png";
        shotGeom = "";
        errorText = "";
        pendingMode = mode;
        ShellState.capturing = true;

        if (mode === "region") {
            // the selector takes over; grim runs once it reports a geometry
            ShellState.beginRegion();
        } else {
            captureDelay.restart();
        }
    }

    function cancel() {
        console.log("notch-shot: cancelled");
        ShellState.capturing = false;
        ShellState.close();
    }

    Component.onCompleted: applyStage()
    onStageChanged: applyStage()

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

    Connections {
        target: ShellState

        function onPanelChanged() {
            if (ShellState.panel !== "screenshot")
                root.reset();
        }

        // The selector closed: either it produced a geometry, or it was cancelled.
        function onRegionSelectingChanged() {
            if (ShellState.regionSelecting)
                return;
            if (ShellState.panel !== "screenshot" || root.pendingMode !== "region")
                return;
            if (ShellState.regionGeom.length > 0) {
                root.shotGeom = ShellState.regionGeom;
                captureDelay.restart();
            } else {
                root.cancel();
            }
        }
    }

    // Let the compositor repaint (unmapping the island and the selector) before
    // grim runs, otherwise they would appear in the shot.
    Timer {
        id: captureDelay

        interval: 160
        repeat: false
        onTriggered: {
            console.log("notch-shot: capturing mode=" + root.pendingMode + " geom='" + root.shotGeom + "'");
            grimProc.running = false;
            grimProc.running = true;
        }
    }

    Process {
        id: toolsProc

        command: ["sh", "-c", "command -v grim >/dev/null 2>&1 && echo ok || echo missing"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "ok")
                    root.stage = "unavailable";
            }
        }
    }

    Process {
        id: grimProc

        command: root.shotGeom.length > 0
            ? ["grim", "-g", root.shotGeom, root.shotPath]
            : ["grim", root.shotPath]
        running: false

        onExited: (exitCode, exitStatus) => {
            console.log("notch-shot: grim exit=" + exitCode + " geom='" + root.shotGeom + "' -> " + root.shotPath);
            if (exitCode === 0) {
                root.stage = "destination";
                ShellState.capturing = false;
                root.forceActiveFocus(Qt.TabFocusReason);
            } else {
                root.errorText = "Capture failed (grim exit " + exitCode + ")";
                root.stage = "failed";
                ShellState.capturing = false;
            }
        }
    }

    Process {
        id: copyProc

        command: ["sh", "-c", "wl-copy < " + root.shotPath + " && rm -f " + root.shotPath]
        running: false
        onExited: (exitCode, exitStatus) => ShellState.close()
    }

    Process {
        id: saveProc

        command: ["sh", "-c", "mkdir -p " + root.saveDir + " && cp " + root.shotPath + " " + root.saveDir + "/" + root.shotName + " && rm -f " + root.shotPath]
        running: false
        onExited: (exitCode, exitStatus) => ShellState.close()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- captured preview ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.stage === "destination" ? 168 : 0
            visible: Layout.preferredHeight > 0

            Rectangle {
                anchors.fill: parent
                radius: Theme.rowRadius
                color: Theme.mantle
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    // only resolve the file once the capture has landed, otherwise
                    // Qt logs "Cannot open" on every stage change
                    source: (root.stage === "destination" && root.shotPath.length > 0)
                        ? "file://" + root.shotPath
                        : ""
                    // show the whole capture rather than cropping it
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    visible: status === Image.Ready
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.stage === "destination" ? 10 : 0
        }

        // ---------- options ----------
        ListView {
            id: optionsView

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: !root.showMessage
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                width: optionsView.width
                height: Theme.rowHeight
                radius: Theme.rowRadius
                color: ListView.isCurrentItem ? Theme.itemSelected : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.hint
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                            visible: text.length > 0
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

        // ---------- message (missing tool / capture failed) ----------
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showMessage
            text: root.message
            color: Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: 11
            lineHeight: 1.4
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
