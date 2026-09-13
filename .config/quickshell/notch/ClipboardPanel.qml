import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

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

    // Snapshot of the clipboard history when the panel opens
    Process {
        id: listProc

        command: ["sh", "-c", "cliphist list 2>/dev/null | head -n 200"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const out = [];
                for (const line of lines) {
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const id = line.substring(0, tab);
                    const preview = line.substring(tab + 1);
                    out.push({
                        id: id,
                        preview: preview,
                        isImage: preview.indexOf("[[ binary data") === 0
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
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 10
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                text: "\uF002"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }

            TextInput {
                id: search

                anchors.left: parent.left
                anchors.leftMargin: 38
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
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
                    text: "Search clipboard history…"
                    color: Theme.surface2
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    visible: search.text.length === 0
                }
            }
        }

        // ---------- entries ----------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8

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
                    height: 44
                    radius: 9
                    color: ListView.isCurrentItem ? Theme.surface0 : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        // image thumbnail placeholder / text badge
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: row.modelData.isImage ? 34 : 42
                            implicitHeight: 26
                            radius: 6
                            color: row.modelData.isImage ? Theme.surface1 : Theme.surface0

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.isImage ? "IMG" : "TXT"
                                color: row.modelData.isImage ? Theme.mauve : Theme.blue
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: row.modelData.preview
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 1
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

            // ---------- empty state ----------
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
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        // ---------- footer ----------
        Row {
            Layout.fillWidth: true
            Layout.topMargin: 9
            Layout.preferredHeight: 18
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "↵  copy back"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "ctrl n/p  move"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "ctrl r  refresh"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
    }
}
