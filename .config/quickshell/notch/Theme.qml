pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string fontFamily: "Iosevka Nerd Font Mono"

    // Catppuccin Mocha, base tuned darker to match the terminal
    readonly property color crust:    "#11111b"
    readonly property color mantle:   "#181825"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color subtext:  "#a6adc8"
    readonly property color text:     "#cdd6f4"

    readonly property color mauve:    "#cba6f7"
    readonly property color blue:     "#89b4fa"
    readonly property color green:    "#a6e3a1"
    readonly property color red:      "#f38ba8"
    readonly property color yellow:   "#f9e2af"
    readonly property color teal:     "#94e2d5"
    readonly property color peach:    "#fab387"
    readonly property color pink:     "#f5c2e7"

    readonly property int animFast: 130
    readonly property int animMed: 240
}
