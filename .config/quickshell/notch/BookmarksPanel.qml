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

    readonly property string filePath: String(Quickshell.env("HOME")) + "/.config/quickshell/notch/bookmarks.tsv"

    readonly property var filtered: entries.filter(entry => {
        const q = query.toLowerCase();
        return !q
            || entry.name.toLowerCase().includes(q)
            || entry.url.toLowerCase().includes(q)
            || entry.folder.toLowerCase().includes(q)
            || entry.tag.toLowerCase().includes(q);
    })

    function refresh() {
        fileProc.running = false;
        fileProc.running = true;
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
        Quickshell.execDetached(["xdg-open", list[i].url]);
        ShellState.close();
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    onQueryChanged: selectedIndex = 0

    // bookmarks.tsv: folder <TAB> name <TAB> url <TAB> tag
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
                        showFolder: folder !== lastFolder,
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
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search bookmarks…"
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

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    // Attached properties like ListView.isCurrentItem are only set on
                    // the delegate root, so expose it here for the child items.
                    readonly property bool isCurrent: ListView.isCurrentItem

                    width: resultsView.width
                    height: (row.modelData.showFolder ? 22 : 0) + 44

                    Text {
                        id: folderLabel
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        height: row.modelData.showFolder ? 22 : 0
                        visible: row.modelData.showFolder
                        text: row.modelData.folder.toUpperCase()
                        color: Theme.overlay0
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        anchors.top: folderLabel.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 44
                        radius: 9
                        color: row.isCurrent ? Theme.surface0 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 7
                                color: Theme.surface1

                                Text {
                                    anchors.centerIn: parent
                                    text: row.modelData.name.charAt(0).toUpperCase()
                                    color: Theme.mauve
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

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
                                    text: row.modelData.url
                                    color: Theme.overlay0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                visible: row.modelData.tag.length > 0
                                text: row.modelData.tag
                                color: Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
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
                text: "↵  open in browser"
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
        }
    }
}
