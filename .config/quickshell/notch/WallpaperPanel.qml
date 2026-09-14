import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

// Wallpaper picker, scoped to the active theme.
//
// Only images under ~/personal/pix/walls/<theme-id>/ are listed. A directory
// named after the theme's display name ("Gruvbox") is also accepted as a
// fallback, so either naming convention works. Selecting a wallpaper applies it
// through awww (whose cache makes it the image `awww restore` brings back).
FocusScope {
    id: root

    property int selectedIndex: 0
    property var items: [] // full paths
    property string activePath: "" // what awww currently displays
    property bool loaded: false

    readonly property string wallsBase: String(Quickshell.env("HOME")) + "/personal/pix/walls"
    readonly property string primaryDir: wallsBase + "/" + ThemeManager.currentId
    readonly property string fallbackDir: wallsBase + "/" + ThemeManager.themeName
    readonly property int columns: 3

    function refresh() {
        listProc.running = false;
        listProc.running = true;
        queryProc.running = false;
        queryProc.running = true;
    }

    function takeInitialFocus() {
        selectedIndex = 0;
        root.forceActiveFocus(Qt.TabFocusReason);
        refresh();
    }

    function moveSelection(dx, dy) {
        const n = items.length;
        if (n === 0)
            return;
        let i = selectedIndex;
        if (dx !== 0) {
            const col = i % columns;
            const nextCol = col + dx;
            if (nextCol >= 0 && nextCol < columns)
                i += dx;
        }
        if (dy !== 0) {
            const next = i + dy * columns;
            if (next >= 0 && next < n)
                i = next;
        }
        if (i !== selectedIndex) {
            selectedIndex = i;
            grid.positionViewAtIndex(selectedIndex, GridView.Contain);
        }
    }

    function applyIndex(i) {
        if (i < 0 || i >= items.length)
            return;
        Quickshell.execDetached([
            "awww", "img",
            "--resize", "crop",
            "--transition-type", "grow",
            "--transition-duration", "0.8",
            "--transition-fps", "60",
            items[i]
        ]);
        ShellState.close();
    }

    Keys.onLeftPressed: moveSelection(-1, 0)
    Keys.onRightPressed: moveSelection(1, 0)
    Keys.onUpPressed: moveSelection(0, -1)
    Keys.onDownPressed: moveSelection(0, 1)
    Keys.onReturnPressed: applyIndex(selectedIndex)
    Keys.onEnterPressed: applyIndex(selectedIndex)
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
        } else if (event.key === Qt.Key_R && (event.modifiers === Qt.NoModifier)) {
            refresh();
            event.accepted = true;
        }
    }

    // First matching theme directory wins; arguments are passed positionally so
    // theme names containing spaces need no quoting gymnastics.
    Process {
        id: listProc

        command: ["sh", "-c",
            'for d in "$1" "$2"; do ' +
            '  [ -d "$d" ] || continue; ' +
            '  find "$d" -maxdepth 1 -type f ' +
            '    \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" \\) ' +
            '    -print | sort; ' +
            '  break; ' +
            'done',
            "sh", root.primaryDir, root.fallbackDir]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l.trim().length > 0);
                root.loaded = true;
                root.selectedIndex = 0;
            }
        }
    }

    // Mark whichever image awww is currently displaying.
    Process {
        id: queryProc

        command: ["awww", "query"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/currently displaying: image: (.+)/);
                root.activePath = m ? m[1].trim() : "";
            }
        }
    }

    Item {
        anchors.fill: parent

        GridView {
            id: grid

            anchors.fill: parent
            clip: true
            visible: root.items.length > 0
            cellWidth: Math.floor(width / root.columns)
            cellHeight: 112
            model: root.items
            currentIndex: root.selectedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property bool isCurrent: cell.index === root.selectedIndex
                readonly property bool isActive: root.activePath.length > 0 && cell.modelData === root.activePath

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: frame

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 5
                    height: 84
                    radius: Theme.rowRadius
                    color: Theme.mantle
                    clip: true
                    border.width: cell.isCurrent ? 2 : 1
                    border.color: cell.isCurrent ? Theme.mauve : Theme.hairline

                    Image {
                        anchors.fill: parent
                        anchors.margins: cell.isCurrent ? 2 : 1
                        source: "file://" + cell.modelData
                        // decode downscaled: wallpapers are large and this is an
                        // 84px thumbnail
                        sourceSize.width: 360
                        sourceSize.height: 240
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Rectangle {
                        visible: cell.isActive
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.crust
                        opacity: 0.85

                        Text {
                            anchors.centerIn: parent
                            text: "\uF00C"
                            color: Theme.green
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                Text {
                    anchors.top: frame.bottom
                    anchors.topMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 16
                    text: cell.modelData.split("/").pop()
                    color: cell.isCurrent ? Theme.text : Theme.overlay0
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = cell.index
                    onClicked: root.applyIndex(cell.index)
                }
            }
        }

        // ---------- empty state ----------
        Text {
            anchors.centerIn: parent
            width: parent.width - 40
            visible: root.loaded && root.items.length === 0
            text: "No wallpapers for " + ThemeManager.themeName + "\n\n" + root.primaryDir
            color: Theme.overlay0
            font.family: Theme.fontFamily
            font.pixelSize: 12
            lineHeight: 1.4
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
    }
}
