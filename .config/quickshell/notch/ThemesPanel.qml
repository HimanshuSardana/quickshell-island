import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import "Themes.js" as Themes

// Theme picker. Each card previews a theme's palette; Enter/click applies it
// to the shell and rewrites the kitty/nvim configs.
FocusScope {
    id: root

    property int selectedIndex: 0
    readonly property var ids: Themes.ids()
    readonly property int columns: 3

    function takeInitialFocus() {
        selectedIndex = Math.max(0, ids.indexOf(ThemeManager.currentId));
        grid.positionViewAtIndex(selectedIndex, GridView.Contain);
        root.forceActiveFocus(Qt.TabFocusReason);
    }

    function moveSelection(dx, dy) {
        const n = ids.length;
        if (n === 0)
            return;
        const cols = columns;
        let i = selectedIndex;
        if (dx !== 0) {
            const col = i % cols;
            const nextCol = col + dx;
            if (nextCol >= 0 && nextCol < cols)
                i = i + dx;
        }
        if (dy !== 0) {
            const next = i + dy * cols;
            if (next >= 0 && next < n)
                i = next;
        }
        if (i !== selectedIndex) {
            selectedIndex = i;
            grid.positionViewAtIndex(selectedIndex, GridView.Contain);
        }
    }

    function activateSelection() {
        if (selectedIndex < 0 || selectedIndex >= ids.length)
            return;
        ThemeManager.activate(ids[selectedIndex]);
        ShellState.close();
    }

    onVisibleChanged: {
        if (visible)
            takeInitialFocus();
    }

    Keys.onLeftPressed: moveSelection(-1, 0)
    Keys.onRightPressed: moveSelection(1, 0)
    Keys.onUpPressed: moveSelection(0, -1)
    Keys.onDownPressed: moveSelection(0, 1)
    Keys.onReturnPressed: activateSelection()
    Keys.onEnterPressed: activateSelection()
    Keys.onEscapePressed: ShellState.close()

    Keys.onPressed: event => {
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_N) {
                moveSelection(0, 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_P) {
                moveSelection(0, -1);
                event.accepted = true;
            }
        }
    }

    GridView {
        id: grid

        anchors.fill: parent
        cellWidth: Math.floor(width / root.columns)
        cellHeight: Math.floor(height / 2)
        model: root.ids
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.selectedIndex

        delegate: Item {
            id: cell

            required property var modelData
            required property int index

            readonly property var theme: Themes.get(modelData)
            readonly property var tp: theme.palette
            readonly property bool isCurrent: modelData === ThemeManager.currentId

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                id: card

                anchors.fill: parent
                anchors.margins: 5
                radius: Theme.rowRadius
                color: cell.tp.base
                border.width: 2
                border.color: cell.index === root.selectedIndex
                    ? Theme.mauve
                    : (cell.isCurrent ? Theme.overlay0 : "transparent")

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animFast }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: cell.theme.name
                            color: cell.tp.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: cell.isCurrent
                            text: "\uF00C"
                            color: Theme.mauve
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    // palette: two rows of six
                    Grid {
                        id: swatches

                        Layout.fillWidth: true
                        columns: 6
                        spacing: 4

                        readonly property real sw: (width - (columns - 1) * spacing) / columns

                        Repeater {
                            model: [
                                cell.tp.red, cell.tp.peach, cell.tp.yellow,
                                cell.tp.green, cell.tp.teal, cell.tp.blue,
                                cell.tp.mauve, cell.tp.pink, cell.tp.text,
                                cell.tp.subtext, cell.tp.surface0, cell.tp.surface1
                            ]

                            Rectangle {
                                width: swatches.sw
                                height: 16
                                radius: 4
                                color: modelData
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = cell.index
                    onClicked: {
                        root.selectedIndex = cell.index;
                        root.activateSelection();
                    }
                }
            }
        }
    }
}
