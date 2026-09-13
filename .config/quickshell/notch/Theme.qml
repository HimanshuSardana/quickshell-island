pragma Singleton
import QtQuick
import Quickshell

// Design tokens.
//
// The palette is deliberately quiet: surfaces differ by only a few percent
// lightness, and a single accent (mauve) is reserved for the one thing that
// actually wants attention. Everything else is neutral text at three weights
// of emphasis: text -> subtext -> overlay0.
Singleton {
    readonly property string fontFamily: "Iosevka Nerd Font Mono"

    // surfaces, darkest first
    readonly property color crust:        "#11111b"
    readonly property color mantle:       "#181825"
    readonly property color base:         "#1e1e2e"
    readonly property color hairline:     "#232336"
    readonly property color itemHover:    "#1a1a29"
    readonly property color itemSelected: "#26263a"
    readonly property color surface0:     "#313244"
    readonly property color surface1:     "#45475a"

    // text emphasis
    readonly property color text:    "#cdd6f4"
    readonly property color subtext: "#a6adc8"
    readonly property color overlay0: "#6c7086"

    // accent + states
    readonly property color mauve:  "#cba6f7"
    readonly property color blue:   "#89b4fa"
    readonly property color green:  "#a6e3a1"
    readonly property color red:    "#f38ba8"
    readonly property color yellow: "#f9e2af"
    readonly property color teal:   "#94e2d5"
    readonly property color peach:  "#fab387"
    readonly property color pink:   "#f5c2e7"

    // rhythm
    readonly property int searchHeight: 48
    readonly property int rowHeight: 56
    readonly property int iconSize: 28
    readonly property int rowRadius: 10
    readonly property int padH: 14
    readonly property int padV: 12
    readonly property int gap: 8

    readonly property int animFast: 120
    readonly property int animMed: 220
}
