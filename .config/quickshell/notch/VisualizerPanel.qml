import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Audio visualizer, fed by cava's raw ASCII output.
//
// cava only runs while this panel is open (`running: root.visible`), so it
// costs nothing the rest of the time. The process writes one frame per line:
// values in 0..ascii_max_range separated by ';'. stdbuf -oL forces line
// buffering, otherwise cava batches frames and the bars arrive in bursts.
FocusScope {
    id: root

    readonly property int barCount: 40
    readonly property int barSpacing: 3
    readonly property real maxLevel: 1000 // matches ascii_max_range in cava.conf

    property var levels: []

    readonly property string cavaConfig: String(Quickshell.env("HOME"))
        + "/.config/quickshell/notch/cava.conf"

    function takeInitialFocus() {
        root.forceActiveFocus(Qt.TabFocusReason);
    }

    // Drop the last frame when closing so reopening doesn't flash stale bars.
    onVisibleChanged: {
        if (!visible)
            levels = [];
    }

    Keys.onEscapePressed: ShellState.close()

    Process {
        id: cavaProc

        command: ["stdbuf", "-oL", "cava", "-p", root.cavaConfig]
        running: root.visible

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";");
                const next = [];
                for (let i = 0; i < parts.length; i++) {
                    const v = parseFloat(parts[i]);
                    // Ignore non-numeric lines (cava prints a terminal title
                    // escape on startup) instead of clobbering the frame.
                    if (!isNaN(v))
                        next.push(Math.max(0, Math.min(1, v / root.maxLevel)));
                }
                if (next.length > 0)
                    root.levels = next;
            }
        }
    }

    Row {
        id: barsRow

        anchors.fill: parent
        spacing: root.barSpacing

        readonly property real barWidth: (width - (root.barCount - 1) * root.barSpacing) / root.barCount

        Repeater {
            model: root.barCount

            delegate: Item {
                required property int index

                width: barsRow.barWidth
                height: barsRow.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    // 2px floor so silent bars stay visible as a baseline.
                    height: Math.max(2, (root.levels[index] || 0) * parent.height)
                    radius: Math.min(width / 2, 4)

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.blue }
                        GradientStop { position: 0.55; color: Theme.mauve }
                        GradientStop { position: 1.0; color: Theme.pink }
                    }
                }
            }
        }
    }
}
