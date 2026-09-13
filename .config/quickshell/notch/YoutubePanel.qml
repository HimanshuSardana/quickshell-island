import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs

// YouTube search. Type a query, yt-dlp returns the top matches, and Enter plays
// the selected video in mpv with --ytdl-format=best.
FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0
    property var entries: []
    property bool loading: false
    property bool searched: false
    property string errorText: ""
    property string inflight: ""

    function takeInitialFocus() {
        clear();
        search.forceActiveFocus(Qt.TabFocusReason);
    }

    function clear() {
        search.text = "";
        query = "";
        entries = [];
        loading = false;
        searched = false;
        errorText = "";
        inflight = "";
        selectedIndex = 0;
    }

    function formatDuration(raw) {
        const secs = parseInt(raw, 10);
        if (!isFinite(secs) || secs < 0)
            return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        const pad = n => (n < 10 ? "0" + n : "" + n);
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s);
    }

    function subtitleFor(entry) {
        return [entry.channel, entry.duration].filter(part => part && part.length > 0).join("  ·  ");
    }

    function runSearch() {
        const q = query.trim();
        if (!q) {
            searchProc.running = false;
            inflight = "";
            entries = [];
            loading = false;
            searched = false;
            errorText = "";
            return;
        }
        loading = true;
        errorText = "";
        inflight = q;
        searchProc.running = false;
        searchProc.command = [
            "yt-dlp", "--flat-playlist", "--no-warnings",
            "--print", "%(id)s\t%(title)s\t%(duration)s\t%(channel)s",
            "ytsearch15:" + q
        ];
        searchProc.running = true;
    }

    function moveSelection(delta) {
        const n = entries.length;
        if (n === 0)
            return;
        selectedIndex = Math.max(0, Math.min(n - 1, selectedIndex + delta));
        resultsView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    function activateIndex(i) {
        if (i < 0 || i >= entries.length)
            return;
        const id = entries[i].id;
        Quickshell.execDetached(["mpv", "--ytdl-format=best", "https://www.youtube.com/watch?v=" + id]);
        ShellState.close();
    }

    onQueryChanged: {
        selectedIndex = 0;
        debounce.restart();
    }

    onVisibleChanged: {
        if (!visible) {
            debounce.stop();
            searchProc.running = false;
        }
    }

    Timer {
        id: debounce

        interval: 350
        repeat: false
        onTriggered: root.runSearch()
    }

    Process {
        id: searchProc

        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                // Drop output from a search the user has already moved past.
                if (root.inflight !== root.query.trim())
                    return;
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const parts = line.split("\t");
                    if (parts.length < 2 || !parts[0])
                        continue;
                    out.push({
                        id: parts[0],
                        title: parts[1] || "",
                        duration: root.formatDuration(parts[2] || ""),
                        channel: parts[3] || ""
                    });
                }
                root.entries = out;
                root.loading = false;
                root.searched = true;
                root.selectedIndex = 0;
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.inflight !== root.query.trim())
                return;
            if (exitCode !== 0 && root.entries.length === 0)
                root.errorText = "yt-dlp failed (exit " + exitCode + "). Is it installed?";
            root.loading = false;
            root.searched = true;
        }
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
                    text: "Search YouTube"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: search.text.length === 0
                }
            }
        }

        // ---------- results ----------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.gap

            ListView {
                id: resultsView

                anchors.fill: parent
                clip: true
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                model: root.entries

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    width: resultsView.width
                    height: Theme.rowHeight
                    radius: Theme.rowRadius
                    color: ListView.isCurrentItem ? Theme.itemSelected : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        spacing: 12

                        ClippingRectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 45
                            radius: 6
                            color: Theme.surface0

                            Image {
                                anchors.fill: parent
                                source: "https://i.ytimg.com/vi/" + row.modelData.id + "/mqdefault.jpg"
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize: Qt.size(160, 90)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.subtitleFor(row.modelData)
                                color: Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
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
                anchors.centerIn: parent
                width: parent.width - 40
                visible: root.entries.length === 0
                text: root.errorText.length > 0
                    ? root.errorText
                    : (root.loading
                        ? "Searching…"
                        : (root.searched
                            ? "No results."
                            : "Type to search YouTube. Enter plays in mpv."))
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 11
                lineHeight: 1.4
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
