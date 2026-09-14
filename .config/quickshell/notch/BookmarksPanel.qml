import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Bookmarks from bookmarks.tsv: folder <TAB> name <TAB> url <TAB> tag
// Folder names become quiet section labels; rows are a single line of
// name + host.
FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0
    property var entries: []
    property bool loaded: false

    readonly property string filePath: String(Quickshell.env("HOME")) + "/.config/quickshell/notch/bookmarks.tsv"

    readonly property var filtered: entries.filter(entry => {
        const q = query.toLowerCase();
        return !q
            || entry.name.toLowerCase().includes(q)
            || entry.url.toLowerCase().includes(q)
            || entry.folder.toLowerCase().includes(q)
            || entry.tag.toLowerCase().includes(q);
    })

    // No URL parser needed: strip scheme, then keep everything before the path.
    function hostOf(url) {
        return url.replace(/^[a-z]+:\/\//, "").split("/")[0];
    }

    function refresh() {
        fileProc.running = false;
        fileProc.running = true;
    }

    function takeInitialFocus() {
        // always start from a clean slate: a query typed before the panel was
        // closed must not survive into the next open
        search.text = "";
        query = "";
        selectedIndex = 0;
        search.forceActiveFocus(Qt.TabFocusReason);
        refresh();
    }

    onVisibleChanged: {
        if (!visible) {
            search.text = "";
            selectedIndex = 0;
        }
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
        Quickshell.execDetached(["xdg-open", list[i].url]);
        ShellState.close();
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    onQueryChanged: selectedIndex = 0

    Process {
        id: fileProc

        command: ["cat", root.filePath]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                let lastFolder = "";
                for (const raw of text.split("\n")) {
                    if (!raw || raw.startsWith("#"))
                        continue;
                    const parts = raw.split("\t");
                    if (parts.length < 3)
                        continue;
                    const folder = parts[0].trim();
                    out.push({
                        folder: folder,
                        isFirstOfFolder: folder !== lastFolder,
                        name: parts[1].trim(),
                        url: parts[2].trim(),
                        tag: (parts[3] || "").trim()
                    });
                    lastFolder = folder;
                }
                root.entries = out;
                root.loaded = true;
                root.selectedIndex = 0;
            }
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
                    text: "Search bookmarks"
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

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    // ListView.isCurrentItem is only attached to the delegate root,
                    // so surface it for the child items.
                    readonly property bool isCurrent: ListView.isCurrentItem

                    width: resultsView.width
                    height: (row.modelData.isFirstOfFolder ? 30 : 0) + Theme.rowHeight

                    Text {
                        id: folderLabel

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        height: row.modelData.isFirstOfFolder ? 30 : 0
                        visible: row.modelData.isFirstOfFolder
                        text: row.modelData.folder.toUpperCase()
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1.1
                        verticalAlignment: Text.AlignBottom
                        bottomPadding: 7
                    }

                    Rectangle {
                        anchors.top: folderLabel.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Theme.rowHeight
                        radius: Theme.rowRadius
                        color: row.isCurrent ? Theme.itemSelected : "transparent"

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
                                    text: row.modelData.name
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.hostOf(row.modelData.url)
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
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: root.filtered.length === 0
                text: root.loaded
                    ? "No bookmarks.\nAdd entries to " + root.filePath
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
