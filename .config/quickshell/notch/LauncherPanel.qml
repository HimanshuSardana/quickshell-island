import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import "Expression.js" as Expression

// Application launcher, doubling as an inline calculator.
// Borderless search, two-line rows (name over description), no footer chrome.
FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0

    readonly property var answer: Expression.evaluate(query)
    readonly property bool hasAnswer: answer !== null

    // Result rows are capped at the number that fits the default panel; below
    // that the island shrinks so a short result list has no dead space.
    readonly property int maxRows: 5
    readonly property int resultCount: resultsView.count
    readonly property int contentHeight: Theme.padV * 2
        + Theme.searchHeight
        + (hasAnswer ? 49 : 0)
        + Theme.gap
        + Math.min(resultCount, maxRows) * Theme.rowHeight

    function takeInitialFocus() {
        search.text = "";
        query = "";
        selectedIndex = 0;
        search.forceActiveFocus(Qt.TabFocusReason);
    }

    function moveSelection(delta) {
        const n = resultsView.count;
        if (n === 0)
            return;
        selectedIndex = Math.max(0, Math.min(n - 1, selectedIndex + delta));
        resultsView.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activateSelection() {
        if (hasAnswer) {
            Quickshell.clipboardText = String(answer);
            ShellState.close();
            return;
        }
        activateIndex(selectedIndex);
    }

    function activateIndex(i) {
        const values = filtered.values;
        if (i >= 0 && i < values.length) {
            values[i].execute();
            ShellState.close();
        }
    }

    onQueryChanged: selectedIndex = 0
    onContentHeightChanged: ShellState.launcherHeight = contentHeight

    // Clear the search when the launcher closes so it always reopens at full
    // height rather than briefly matching the last query.
    onVisibleChanged: {
        if (!visible) {
            search.text = "";
            selectedIndex = 0;
        }
    }

    Component.onCompleted: {
        ShellState.launcherHeight = contentHeight;
        takeInitialFocus();
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
                color: root.hasAnswer ? Theme.mauve : Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 20

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }
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
                    text: "Search apps or calculate..."
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    visible: search.text.length === 0
                }
            }
        }

        // ---------- inline result ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.hasAnswer ? 48 : 0
            visible: root.hasAnswer
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.query.replace(/\*/g, "×").replace(/\//g, "÷")
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.hasAnswer ? String(root.answer) : ""
                color: Theme.mauve
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.hairline
            visible: root.hasAnswer
        }

        // ---------- results ----------
        ListView {
            id: resultsView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.gap
            clip: true
            currentIndex: root.selectedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds

            model: ScriptModel {
                id: filtered

                values: DesktopEntries.applications.values
                    .filter(entry => {
                        if (entry.noDisplay)
                            return false;
                        const q = root.query.toLowerCase();
                        if (!q)
                            return true;
                        const name = String(entry.name || "").toLowerCase();
                        const generic = String(entry.genericName || "").toLowerCase();
                        const keywords = entry.keywords ? entry.keywords.join(" ").toLowerCase() : "";
                        return name.includes(q) || generic.includes(q) || keywords.includes(q);
                    })
                    .sort((a, b) => String(a.name || "").toLowerCase() < String(b.name || "").toLowerCase() ? -1 : 1)
            }

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
                    anchors.rightMargin: 10
                    spacing: 14

                    IconImage {
                        Layout.alignment: Qt.AlignVCenter
                        source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        implicitSize: Theme.iconSize
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.genericName || row.modelData.comment || ""
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
    }
}
