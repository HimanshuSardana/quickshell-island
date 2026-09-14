import QtQuick
import Quickshell
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

        color: Theme.crust

        property string errorText: ""
        property bool attempting: false

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

        Component.onCompleted: focusInput()
        onVisibleChanged: if (visible) focusInput()

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
