import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs

// Lock screen built on ext-session-lock-v1, so the compositor (not this shell)
// is what guarantees the lock is real: while locked it refuses to route input
// anywhere else. Mango implements the protocol.
//
// IMPORTANT: if this ever fails to authenticate you are not stuck. Killing the
// shell releases the lock, because the compositor drops a session lock when its
// client dies. Mango disables its own keybinds while locked, so the way out is
// a TTY: Ctrl+Alt+F2, log in, `pkill qs`, then Ctrl+Alt+F1.
WlSessionLock {
    id: lock

    locked: ShellState.locked

    WlSessionLockSurface {
        id: surface

        color: "transparent"

        property string errorText: ""
        property bool attempting: false

        // Wallpaper shown behind the lock UI, blurred. It is pulled from awww
        // (the same source the wallpaper panel drives) each time the lock
        // surface appears, so it always matches the live wallpaper.
        property string wallpaperPath: ""

        Process {
            id: wallpaperProc

            command: ["awww", "query"]
            running: false

            stdout: StdioCollector {
                onStreamFinished: {
                    // awww prints one line per output:
                    //   : eDP-1: 1920x1080, scale: 1, currently displaying: image: /path
                    // Prefer the line for this surface's output, fall back to
                    // the first one.
                    const want = surface.screen ? surface.screen.name : "";
                    let first = "";
                    for (const line of text.split("\n")) {
                        const m = line.match(/currently displaying: image: (.+)/);
                        if (!m)
                            continue;
                        const path = m[1].trim();
                        if (first === "")
                            first = path;
                        const out = line.match(/^:\s*([^:]+):/);
                        if (out && want.length > 0 && out[1].trim() === want) {
                            surface.wallpaperPath = path;
                            return;
                        }
                    }
                    surface.wallpaperPath = first;
                }
            }
        }

        function focusInput() {
            input.forceActiveFocus(Qt.ActiveWindowFocusReason);
        }

        function submit() {
            if (input.text.length === 0)
                return;
            errorText = "";
            attempting = true;
            // each attempt needs a fresh PAM transaction
            if (pam.active)
                pam.abort();
            pam.active = true;
        }

        function fail(message) {
            console.log("notch-lock: " + message);
            errorText = message;
            attempting = false;
            input.text = "";
            focusInput();
        }

        Component.onCompleted: {
            focusInput();
            wallpaperProc.running = true;
        }
        onVisibleChanged: if (visible) {
            focusInput();
            wallpaperProc.running = true;
        }

        PamContext {
            id: pam

            config: "login"
            user: String(Quickshell.env("USER"))

            onPamMessage: {
                if (pam.responseRequired)
                    pam.respond(input.text);
            }

            onCompleted: result => {
                console.log("notch-lock: pam completed result=" + result);
                if (result === PamResult.Success) {
                    input.text = "";
                    ShellState.locked = false;
                } else if (result === PamResult.MaxTries) {
                    surface.fail("Too many attempts");
                } else {
                    surface.fail("Incorrect password");
                }
            }

            onError: error => {
                console.log("notch-lock: pam error=" + error);
                surface.fail("Authentication error");
            }
        }

        // ---------------- blurred backdrop ----------------
        // The compositor will not blur a session-lock surface (Mango only
        // creates blur nodes for clients/layers and never advertises
        // ext-background-effect-v1), so the frosted glass is rendered here as
        // a blurred copy of the wallpaper.
        Image {
            id: wallpaperImage

            anchors.fill: parent
            source: surface.wallpaperPath.length > 0
                ? "file://" + surface.wallpaperPath
                : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaperImage
            visible: wallpaperImage.status === Image.Ready
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            brightness: -0.2
            saturation: -0.1
        }

        // Dark wash so the clock and password field stay readable over any
        // wallpaper. Fully opaque when there is no wallpaper to blur.
        Rectangle {
            anchors.fill: parent
            color: Theme.crust
            opacity: wallpaperImage.status === Image.Ready ? 0.4 : 1.0
        }

        // ---------------- clock ----------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(parent.height * 0.22)
            spacing: 6

            Text {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                property var now: new Date()

                text: Qt.formatDateTime(clock.now, "HH:mm")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 78

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clock.now = new Date()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.now, "dddd d MMMM")
                color: Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
        }

        // ---------------- unlock ----------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 120
            spacing: 12

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 46
                radius: 12
                color: Theme.mantle
                border.width: 1
                border.color: input.activeFocus ? Theme.mauve : Theme.hairline

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animFast }
                }

                TextInput {
                    id: input

                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    clip: true
                    selectByMouse: true
                    onAccepted: surface.submit()

                    Keys.onEscapePressed: {
                        input.text = "";
                        surface.errorText = "";
                        event.accepted = true;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"
                        color: Theme.surface1
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        visible: input.text.length === 0
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: surface.errorText.length > 0
                    ? surface.errorText
                    : (surface.attempting ? "Authenticating…" : "Enter your password")
                color: surface.errorText.length > 0 ? Theme.red : Theme.overlay0
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
