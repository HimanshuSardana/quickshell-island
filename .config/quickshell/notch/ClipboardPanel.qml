import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Clipboard history via cliphist.
// Text entries show their content; binary entries are rewritten from cliphist's
// raw "[[ binary data ... ]]" form into something legible.
FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0
    property var entries: []
    property bool loaded: false

    readonly property var filtered: entries.filter(entry => {
        const q = query.toLowerCase();
        return !q || entry.preview.toLowerCase().includes(q);
    })

    // "[[ binary data 41 KiB png 1920x1080 ]]" -> "PNG · 1920×1080 · 41 KiB"
    function describeImage(raw) {
        const m = raw.match(/^\[\[\s*binary data\s+(.+?)\s+(\S+)\s+(\d+x\d+)\s*\]\]$/);
        if (!m)
            return "Image";
        return m[2].toUpperCase() + " · " + m[3].replace("x", "×") + " · " + m[1];
    }

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    function takeInitialFocus() {
        search.forceActiveFocus(Qt.TabFocusReason);
        refresh();
    }

    function moveSelection(delta) {
        const n = filtered.length;
        if (n === 0)
            return;
        selectedIndex = Math.max(0, Math.min(n - 1, selectedIndex + delta));
        resultsView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activateIndex(i) {
        const list = filtered;
        if (i < 0 || i >= list.length)
            return;
        decodeProc.entryId = list[i].id;
        decodeProc.running = false;
        decodeProc.running = true;
        ShellState.close();
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    onQueryChanged: selectedIndex = 0

    Process {
        id: listProc

        command: ["sh", "-c", "cliphist list 2>/dev/null | head -n 200"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const preview = line.substring(tab + 1);
                    const isImage = preview.indexOf("[[ binary data") === 0;
                    out.push({
                        id: line.substring(0, tab),
                        isImage: isImage,
                        preview: isImage
                            ? root.describeImage(preview)
                            : preview.replace(/\s+/g, " ").trim(),
                        kind: isImage ? "image" : "text"
                    });
                }
                root.entries = out;
                root.loaded = true;
                root.selectedIndex = 0;
            }
        }
    }

    // Put the selected entry back on the clipboard
    Process {
        id: decodeProc

        property string entryId: ""
        command: ["sh", "-c", "cliphist decode " + decodeProc.entryId + " | wl-copy"]
        running: false
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
                        } else if (event.key === Qt.Key_R) {
                            root.refresh();
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search clipboard history"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: search.text.length === 0
                }
            }
        }

        // ---------- entries ----------
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
                model: root.filtered

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
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.preview
                                color: row.modelData.isImage ? Theme.subtext : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.isImage ? "Image" : "Text"
                                color: Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
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
                visible: root.filtered.length === 0
                text: root.loaded
                    ? "No clipboard history.\nInstall cliphist and run:  wl-paste --watch cliphist store"
                    : "Loading…"
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
