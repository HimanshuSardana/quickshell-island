import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import "Expression.js" as Expression

FocusScope {
    id: root

    property string query: ""
    property int selectedIndex: 0

    readonly property var answer: Expression.evaluate(query)
    readonly property bool hasAnswer: answer !== null

    function takeInitialFocus() {
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
        const values = filtered.values;
        if (values.length > 0) {
            values[Math.max(0, Math.min(selectedIndex, values.length - 1))].execute();
            ShellState.close();
        }
    }

    function activateIndex(i) {
        const values = filtered.values;
        if (i >= 0 && i < values.length) {
            values[i].execute();
            ShellState.close();
        }
    }

    onQueryChanged: selectedIndex = 0
    Component.onCompleted: takeInitialFocus()

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
                    text: "Search apps or calculate…"
                    color: Theme.surface2
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    visible: search.text.length === 0
                }
            }
        }

        // ---------- inline calculator ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: root.hasAnswer ? 8 : 0
            Layout.preferredHeight: root.hasAnswer ? 60 : 0
            radius: 10
            color: Theme.surface0
            opacity: root.hasAnswer ? 1 : 0
            visible: Layout.preferredHeight > 0
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: root.query.replace(/\*/g, "×").replace(/\//g, "÷")
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
                Text {
                    text: root.hasAnswer ? String(root.answer) : ""
                    color: Theme.mauve
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                text: "↵ copy"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        // ---------- results ----------
        ListView {
            id: resultsView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
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
                height: 44
                radius: 9
                color: ListView.isCurrentItem ? Theme.surface0 : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    IconImage {
                        source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        implicitSize: 22
                        Layout.alignment: Qt.AlignVCenter
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
                            text: row.modelData.genericName || row.modelData.comment || "Application"
                            color: Theme.overlay0
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
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

        // ---------- footer ----------
        Row {
            Layout.fillWidth: true
            Layout.topMargin: 9
            Layout.preferredHeight: 18
            spacing: 14

            Row {
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↵"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "open"
                    color: Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
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
                text: "esc  close"
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
    }
}
