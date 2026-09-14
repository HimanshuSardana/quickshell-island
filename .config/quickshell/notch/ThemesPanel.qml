import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import "Themes.js" as Themes

// Theme picker, laid out like the launcher: borderless search, hairline rule,
// one row per theme with the palette on the left and the name beside it.
FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0

    readonly property var ids: Themes.ids()

    readonly property var filtered: ids.filter(id => {
        const q = query.toLowerCase();
        if (!q)
            return true;
        return id.toLowerCase().includes(q) || Themes.name(id).toLowerCase().includes(q);
    })

    // Result rows are capped at the number that fits the default panel; below
    // that the island shrinks so a filtered list has no dead space. Derived from
    // the result count only -- never from the laid-out height, which would feed
    // back into the island height and oscillate.
    readonly property int maxRows: 5
    readonly property int contentHeight: Theme.padV * 2
        + Theme.searchHeight
        + 1
        + Theme.gap
        + Math.min(filtered.length, maxRows) * Theme.rowHeight

    function takeInitialFocus() {
        search.text = "";
        query = "";
        selectedIndex = Math.max(0, ids.indexOf(ThemeManager.currentId));
        resultsView.positionViewAtIndex(selectedIndex, ListView.Contain);
        search.forceActiveFocus(Qt.TabFocusReason);
    }

    function moveSelection(delta) {
        const n = filtered.length;
        if (n === 0)
            return;
        selectedIndex = Math.max(0, Math.min(n - 1, selectedIndex + delta));
        resultsView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activateSelection() {
        activateIndex(selectedIndex);
    }

    function activateIndex(i) {
        if (i < 0 || i >= filtered.length)
            return;
        ThemeManager.activate(filtered[i]);
        ShellState.close();
    }

    onQueryChanged: selectedIndex = 0
    onContentHeightChanged: ShellState.themesHeight = contentHeight

    onVisibleChanged: {
        if (!visible) {
            search.text = "";
            selectedIndex = 0;
        }
    }

    Component.onCompleted: ShellState.themesHeight = contentHeight

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
                    text: "Search themes"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: search.text.length === 0
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.hairline
            visible: false
        }

        // ---------- themes ----------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.gap

            ListView {
                id: resultsView

                anchors.fill: parent
                clip: true
                currentIndex: root.selectedIndex
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                model: root.filtered

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property var theme: Themes.get(row.modelData)
                    readonly property var p: theme.palette
                    readonly property bool isCurrent: row.modelData === ThemeManager.currentId

                    width: resultsView.width
                    height: Theme.rowHeight
                    radius: Theme.rowRadius
                    color: ListView.isCurrentItem ? Theme.itemSelected : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 10
                        spacing: 14

                        // Palette preview: four accent swatches in a single row.
                        // FIXED size on purpose -- a Grid whose size depends on its
                        // children pinned a core at 100% (that was the earlier spin).
                        Grid {
                            Layout.alignment: Qt.AlignVCenter
                            columns: 4
                            spacing: 3

                            Repeater {
                                model: [row.p.mauve, row.p.blue, row.p.green, row.p.red]

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 3
                                    color: modelData
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: row.theme.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData
                                color: Theme.overlay0
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            visible: row.isCurrent
                            text: "\uF00C"
                            color: Theme.mauve
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
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
                text: "No themes match"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
