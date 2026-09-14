pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Themes.js" as Themes
import "ThemeGen.js" as ThemeGen

// Source of truth for the active theme. Writes the generated kitty/nvim files
// and pokes kitty to reload; the shell reads colors straight from `palette`.
Singleton {
    readonly property string home: String(Quickshell.env("HOME"))
    readonly property string configDir: home + "/.config"
    readonly property string currentFile: configDir + "/themes/current"

    property string currentId: Themes.defaultId

    readonly property var theme: Themes.get(currentId)
    readonly property var palette: theme.palette
    readonly property string themeName: theme.name

    function setCurrent(id) {
        if (Themes.all[id] !== undefined)
            currentId = id;
    }

    function activate(id) {
        if (Themes.all[id] === undefined)
            return;
        currentId = id;

        const t = Themes.get(id);
        writeFile(currentFile, id + "\n");
        writeFile(configDir + "/kitty/theme.conf", ThemeGen.kitty(t.palette, t.name));
        writeFile(configDir + "/nvim/notch-palette.lua", ThemeGen.nvimPalette(t.palette));
        writeFile(home + "/.tmux-theme.conf", ThemeGen.tmux(t.palette, t.name));
        // A single stable pi theme file: pi hot reloads the active theme file
        // when it is rewritten, so keep the name fixed at "notch".
        writeFile(home + "/.pi/agent/themes/notch.json", ThemeGen.pi(t.palette, "notch"));

        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
        Quickshell.execDetached(["tmux", "source-file", home + "/.tmux-theme.conf"]);
    }

    // Write via a quoted heredoc so arbitrary text survives the shell untouched.
    function writeFile(path, content) {
        const body = content + (content.endsWith("\n") ? "" : "\n");
        const script = "mkdir -p \"$(dirname \"$1\")\"\n"
            + "cat > \"$1\" <<'NOTCH_THEME_EOF'\n"
            + body
            + "NOTCH_THEME_EOF\n";
        Quickshell.execDetached(["sh", "-c", script, "--", path]);
    }

    Process {
        id: loader

        command: ["sh", "-c", "cat \"" + currentFile + "\" 2>/dev/null || true"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: setCurrent(text.trim())
        }
    }
}
