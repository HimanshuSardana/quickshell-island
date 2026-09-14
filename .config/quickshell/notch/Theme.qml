pragma Singleton
import QtQuick
import Quickshell

// Design tokens.
//
// Colors come from the active palette in ThemeManager, so switching themes
// restyles the whole shell live. Surfaces differ by only a few percent
// lightness and a single accent (mauve) is reserved for the one thing that
// actually wants attention. Everything else is neutral text at three weights
// of emphasis: text -> subtext -> overlay0.
Singleton {
    readonly property string fontFamily: "Iosevka Nerd Font Mono"

    readonly property var p: ThemeManager.palette

    // surfaces, darkest first
    readonly property color crust:        p.crust
    readonly property color mantle:       p.mantle
    readonly property color base:         p.base
    readonly property color hairline:     p.hairline
    readonly property color itemHover:    p.itemHover
    readonly property color itemSelected: p.itemSelected
    readonly property color surface0:     p.surface0
    readonly property color surface1:     p.surface1

    // text emphasis
    readonly property color text:    p.text
    readonly property color subtext: p.subtext
    readonly property color overlay0: p.overlay0

    // accent + states
    readonly property color mauve:  p.mauve
    readonly property color blue:   p.blue
    readonly property color green:  p.green
    readonly property color red:    p.red
    readonly property color yellow: p.yellow
    readonly property color teal:   p.teal
    readonly property color peach:  p.peach
    readonly property color pink:   p.pink

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
