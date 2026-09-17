import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Mail inbox. Lists recent mail from `carbon list --json`; Enter or click
// opens the selected mail in the browser (`carbon open <id>` renders HTML).
FocusScope {
    id: root

    property var entries: []
    property int selectedIndex: 0
    property bool loading: false
    property string errorText: ""

    function takeInitialFocus() {
        refresh();
        resultsView.forceActiveFocus(Qt.TabFocusReason);
    }

    function refresh() {
        loading = true;
        errorText = "";
        listProc.running = false;
        listProc.command = ["carbon", "list", "--json"];
        listProc.running = true;
    }

    function unreadCount() {
        let n = 0;
        for (let i = 0; i < entries.length; i++)
            if (entries[i].unread)
                n++;
        return n;
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
        openMail(entries[i].id);
    }

    function openMail(id) {
        Quickshell.execDetached(["carbon", "open", id]);
        ShellState.close();
    }

    onVisibleChanged: {
        if (!visible)
            listProc.running = false;
    }

    Process {
        id: listProc

        command: []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text);
                    root.entries = Array.isArray(arr) ? arr : [];
                } catch (e) {
                    root.entries = [];
                    root.errorText = "Could not parse carbon output.";
                }
                root.loading = false;
                root.selectedIndex = 0;
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.entries.length === 0)
                root.errorText = "carbon failed (exit " + exitCode + "). Is ~/.local/bin/carbon on PATH?";
            root.loading = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- header ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.searchHeight

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                spacing: 10

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "\uF0E0"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Mail"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 8
                    text: root.unreadCount() + " unread"
                    color: Theme.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    visible: root.unreadCount() > 0
                }
            }
        }

        // ---------- list ----------
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

                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onReturnPressed: root.activateSelection()
                Keys.onEnterPressed: root.activateSelection()
                Keys.onEscapePressed: ShellState.close()

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
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 10
                            text: "●"
                            color: Theme.blue
                            font.pixelSize: 9
                            opacity: row.modelData.unread ? 1 : 0
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.subject
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: row.modelData.unread ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    text: row.modelData.date
                                    color: Theme.overlay0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.sender + "  ·  " + row.modelData.snippet
                                color: Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                maximumLineCount: 1
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
                    : (root.loading ? "Loading…" : "No mail.")
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
