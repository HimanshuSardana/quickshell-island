pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU usage for the collapsed pill.
//
// Quickshell has no CPU service, and /proc/stat emits no change notifications,
// so this polls: awk prints the aggregate jiffy counters, and the usage is the
// delta between consecutive samples (1 - idle/total). Sampling over a couple of
// seconds keeps the number stable instead of jumping on every scheduler tick.
Singleton {
    id: root

    property real usage: 0 // 0..1
    property bool ready: false

    property real lastTotal: -1
    property real lastIdle: -1

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            proc.running = false;
            proc.running = true;
        }
    }

    Process {
        id: proc

        // Note the space in /^cpu / so the per-core lines (cpu0, cpu1, ...) are
        // skipped. Passed as argv, so awk's $n fields are never shell-expanded.
        command: ["awk", "/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print t, $5; exit}", "/proc/stat"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length < 2)
                    return;
                const total = Number(parts[0]);
                const idle = Number(parts[1]);
                if (root.lastTotal >= 0) {
                    const dTotal = total - root.lastTotal;
                    const dIdle = idle - root.lastIdle;
                    if (dTotal > 0)
                        root.usage = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
                }
                root.lastTotal = total;
                root.lastIdle = idle;
                root.ready = true;
            }
        }
    }
}
