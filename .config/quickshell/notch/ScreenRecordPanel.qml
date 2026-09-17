import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Screen recording menu (wf-recorder).
//
//   idle       Screen + Audio | Screen -> starts wf-recorder, collapses to the
//                                        pill so the island is not in the way
//   recording  Stop recording         -> SIGINTs wf-recorder, which finalizes
//                                        the mp4 by itself
//
// While a recording is active the collapsed pill shows a blinking red dot.
// Files land in ~/personal/vids/screenrecordings/ as mp4.
FocusScope {
    id: root

    property int selectedIndex: 0
    property var rows: []
    property string stage: "choose" // choose | unavailable
    property bool ownRec: false

    readonly property bool showMessage: stage === "unavailable"
    readonly property string message: "wf-recorder is required:\n\nsudo pacman -S wf-recorder"
    readonly property string saveDir: String(Quickshell.env("HOME")) + "/personal/vids/screenrecordings"

    function refreshRows() {
        if (showMessage) {
            rows = [];
            selectedIndex = 0;
            return;
        }
        if (ShellState.recording) {
            rows = [
                { label: "Stop recording", hint: ShellState.recordingFile + "  ·  " + ShellState.recordingClock, action: "stop" }
            ];
        } else {
            rows = [
                { label: "Screen + Audio", hint: "screen and audio", action: "both" },
                { label: "Screen", hint: "screen only, no audio", action: "video" }
            ];
        }
        selectedIndex = 0;
    }

    function reset() {
        stage = "choose";
        ownRec = false;
        selectedIndex = 0;
    }

    function takeInitialFocus() {
        stage = "choose";
        selectedIndex = 0;
        refreshRows();
        root.forceActiveFocus(Qt.TabFocusReason);
        toolsProc.running = false;
        toolsProc.running = true;
        syncProc.running = false;
        syncProc.running = true;
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
        console.log("notch-rec: activate index=" + i + " action=" + action);
        if (action === "both" || action === "video")
            start(action);
        else if (action === "stop")
            stop();
    }

    function start(mode) {
        const ts = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        const name = "screenrecording-" + ts + ".mp4";
        const file = saveDir + "/" + name;
        const audio = mode === "both" ? "-a " : "";
        ShellState.recordingFile = name;
        ShellState.recordingStart = Date.now();
        ShellState.recordingElapsed = 0;
        ShellState.recording = true;
        ownRec = true;
        recProc.running = false;
        recProc.command = ["sh", "-c", "mkdir -p '" + saveDir + "'; rm -f /tmp/notch-rec.pid /tmp/notch-rec.file; wf-recorder " + audio + "-f '" + file + "' & rp=$!; echo $rp > /tmp/notch-rec.pid; echo '" + name + "' > /tmp/notch-rec.file; wait $rp"];
        recProc.running = true;
        console.log("notch-rec: started mode=" + mode + " -> " + file);
        ShellState.close();
    }

    function stop() {
        stopProc.running = false;
        stopProc.running = true;
    }

    onStageChanged: refreshRows()

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
            if (ShellState.panel !== "screenrecord")
                root.reset();
            else
                root.refreshRows();
        }

        function onRecordingChanged() {
            if (ShellState.panel === "screenrecord")
                root.refreshRows();
        }

        function onRecordingElapsedChanged() {
            if (ShellState.panel === "screenrecord" && ShellState.recording)
                root.refreshRows();
        }
    }

    // wf-recorder must exist for either option.
    Process {
        id: toolsProc

        command: ["sh", "-c", "command -v wf-recorder >/dev/null 2>&1 && echo ok || echo missing"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "ok")
                    root.stage = "unavailable";
            }
        }
    }

    // Adopt a recording that is already running (e.g. quickshell restarted
    // mid-recording). The starter writes the recorder's pid to
    // /tmp/notch-rec.pid; checking it with kill -0 + /proc/<pid>/cmdline can
    // never self-match the way pgrep -f would (its own command line always
    // contains the pattern).
    Process {
        id: syncProc

        command: ["sh", "-c", 'pid=$(cat /tmp/notch-rec.pid 2>/dev/null); if [ -n $pid ] && kill -0 $pid 2>/dev/null && tr "\\0" " " < /proc/$pid/cmdline 2>/dev/null | grep -q wf-recorder; then cat /tmp/notch-rec.file 2>/dev/null; fi']
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out.length === 0) {
                    if (ShellState.recording && !root.ownRec && !recProc.running) {
                        ShellState.recording = false;
                        ShellState.recordingFile = "";
                    }
                    root.refreshRows();
                    return;
                }
                if (!ShellState.recording) {
                    ShellState.recordingFile = out.split("/").pop();
                    ShellState.recordingStart = Date.now();
                    ShellState.recordingElapsed = 0;
                    ShellState.recording = true;
                }
                root.refreshRows();
            }
        }
    }

    // The live recorder. It runs until SIGINT, which makes wf-recorder
    // finalize the mp4 cleanly.
    Process {
        id: recProc

        command: []
        running: false

        onExited: (exitCode, exitStatus) => {
            console.log("notch-rec: wf-recorder exit=" + exitCode);
            if (root.ownRec) {
                root.ownRec = false;
                if (ShellState.recording) {
                    ShellState.recording = false;
                    ShellState.recordingFile = "";
                }
            }
        }
    }

    Process {
        id: stopProc

        command: ["sh", "-c", 'pid=$(cat /tmp/notch-rec.pid 2>/dev/null); [ -n "$pid" ] && kill -INT $pid 2>/dev/null; rm -f /tmp/notch-rec.pid /tmp/notch-rec.file; true']
        running: false

        onExited: (exitCode, exitStatus) => {
            console.log("notch-rec: stop sent, pkill exit=" + exitCode);
            // recProc.onExited clears the flag for our own recording; clear here
            // too for adopted ones, then collapse back to the pill.
            root.ownRec = false;
            ShellState.recording = false;
            ShellState.recordingFile = "";
            ShellState.close();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

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

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: row.modelData.action === "stop" ? "⏺" : "◎"
                        color: row.modelData.action === "stop" ? Theme.red : Theme.mauve
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                    }

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
