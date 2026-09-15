.pragma library

// Shared theme palettes for the notch shell, kitty and nvim.
//
// Each entry exposes the same keys so every consumer can stay generic:
//   surfaces:  crust mantle base hairline itemHover itemSelected surface0 surface1
//   text:      text subtext overlay0
//   accents:   red peach yellow green teal blue mauve pink

const defaultId = "catppuccin-mocha"

const all = {
	"catppuccin-mocha": {
		name: "Catppuccin Mocha",
		palette: {
			crust: "#11111b",
			mantle: "#181825",
			base: "#1e1e2e",
			hairline: "#232336",
			itemHover: "#1a1a29",
			itemSelected: "#26263a",
			surface0: "#313244",
			surface1: "#45475a",
			text: "#cdd6f4",
			subtext: "#a6adc8",
			overlay0: "#6c7086",
			red: "#f38ba8",
			peach: "#fab387",
			yellow: "#f9e2af",
			green: "#a6e3a1",
			teal: "#94e2d5",
			blue: "#89b4fa",
			mauve: "#cba6f7",
			pink: "#f5c2e7"
		}
	},
	"catppuccin-latte": {
		name: "Catppuccin Latte",
		palette: {
			crust: "#dce0e8",
			mantle: "#e6e9ef",
			base: "#eff1f5",
			hairline: "#ccd0da",
			itemHover: "#e6e9ef",
			itemSelected: "#ccd0da",
			surface0: "#ccd0da",
			surface1: "#bcc0cc",
			text: "#4c4f69",
			subtext: "#6c6f85",
			overlay0: "#9ca0b0",
			red: "#d20f39",
			peach: "#fe640b",
			yellow: "#df8e1d",
			green: "#40a02b",
			teal: "#179299",
			blue: "#1e66f5",
			mauve: "#8839ef",
			pink: "#ea76cb"
		}
	},
	"everforest": {
		name: "Everforest",
		palette: {
			crust: "#232a2e",
			mantle: "#272e33",
			base: "#2d353b",
			hairline: "#3d484d",
			itemHover: "#333c42",
			itemSelected: "#3d484d",
			surface0: "#343f44",
			surface1: "#475258",
			text: "#d3c6aa",
			subtext: "#9da9a0",
			overlay0: "#859289",
			red: "#e67e80",
			peach: "#e69875",
			yellow: "#dbbc7f",
			green: "#a7c080",
			teal: "#83c092",
			blue: "#7fbbb3",
			mauve: "#d699b6",
			pink: "#d699b6"
		}
	},
	"gruvbox": {
		name: "Gruvbox",
		palette: {
			crust: "#1d2021",
			mantle: "#282828",
			base: "#32302f",
			hairline: "#3c3836",
			itemHover: "#2c2c2c",
			itemSelected: "#3c3836",
			surface0: "#3c3836",
			surface1: "#504945",
			text: "#ebdbb2",
			subtext: "#d5c4a1",
			overlay0: "#928374",
			red: "#fb4934",
			peach: "#fe8019",
			yellow: "#fabd2f",
			green: "#b8bb26",
			teal: "#8ec07c",
			blue: "#83a598",
			mauve: "#d3869b",
			pink: "#d3869b"
		}
	},
	"rose-pine": {
		name: "Rosé Pine",
		palette: {
			crust: "#14121f",
			mantle: "#191724",
			base: "#1f1d2e",
			hairline: "#26233a",
			itemHover: "#1f1d2e",
			itemSelected: "#26233a",
			surface0: "#26233a",
			surface1: "#403d52",
			text: "#e0def4",
			subtext: "#908caa",
			overlay0: "#6e6a86",
			red: "#eb6f92",
			peach: "#ebbcba",
			yellow: "#f6c177",
			green: "#31748f",
			teal: "#9ccfd8",
			blue: "#9ccfd8",
			mauve: "#c4a7e7",
			pink: "#eb6f92"
		}
	},
	"tokyo-night": {
		name: "Tokyo Night",
		palette: {
			crust: "#16161e",
			mantle: "#1a1b26",
			base: "#1f2335",
			hairline: "#292e42",
			itemHover: "#1f2335",
			itemSelected: "#292e42",
			surface0: "#292e42",
			surface1: "#3b4261",
			text: "#c0caf5",
			subtext: "#a9b1d6",
			overlay0: "#565f89",
			red: "#f7768e",
			peach: "#ff9e64",
			yellow: "#e0af68",
			green: "#9ece6a",
			teal: "#7dcfff",
			blue: "#7aa2f7",
			mauve: "#bb9af7",
			pink: "#bb9af7"
		}
	},
	"one-dark": {
		name: "One Dark",
		palette: {
			crust: "#21252b",
			mantle: "#282c34",
			base: "#282c34",
			hairline: "#3a3f4b",
			itemHover: "#2c313a",
			itemSelected: "#3a3f4b",
			surface0: "#3a3f4b",
			surface1: "#4b5263",
			text: "#abb2bf",
			subtext: "#9da5b4",
			overlay0: "#5c6370",
			red: "#e06c75",
			peach: "#d19a66",
			yellow: "#e5c07b",
			green: "#98c379",
			teal: "#56b6c2",
			blue: "#61afef",
			mauve: "#c678dd",
			pink: "#c678dd"
		}
	},
	"carbonfox": {
		name: "CarbonFox",
		palette: {
			crust: "#161616",
			mantle: "#1e1e1e",
			base: "#282828",
			hairline: "#2a2a2a",
			itemHover: "#202020",
			itemSelected: "#3a3a3a",
			surface0: "#3a3a3a",
			surface1: "#484848",
			text: "#f2f4f8",
			subtext: "#dfdfe0",
			overlay0: "#7b7b7b",
			red: "#ee5396",
			peach: "#f16da6",
			yellow: "#08bdba",
			green: "#25be6a",
			teal: "#33b1ff",
			blue: "#78a9ff",
			mauve: "#be95ff",
			pink: "#c8a5ff"
		}
	},
	"nord": {
		name: "Nord",
		palette: {
			crust: "#2e3440",
			mantle: "#343b4c",
			base: "#3b4252",
			hairline: "#434c5e",
			itemHover: "#3f475b",
			itemSelected: "#434c5e",
			surface0: "#434c5e",
			surface1: "#4c566a",
			text: "#eceff4",
			subtext: "#d8dee9",
			overlay0: "#7b88a1",
			red: "#bf616a",
			peach: "#d08770",
			yellow: "#ebcb8b",
			green: "#a3be8c",
			teal: "#88c0d0",
			blue: "#81a1c1",
			mauve: "#b48ead",
			pink: "#b48ead"
		}
	}
}

function ids() {
	return Object.keys(all)
}

function get(id) {
	return all[id] || all[defaultId]
}

function name(id) {
	return get(id).name
}
