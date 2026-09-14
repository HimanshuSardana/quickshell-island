-- Palette-driven colorscheme for the notch theme selector.
--
-- The palette itself is generated into notch-palette.lua; this file watches
-- that file, so switching theme updates every running nvim instance live.

local M = {}

local function palette()
	local path = vim.fn.stdpath("config") .. "/notch-palette.lua"
	local ok, p = pcall(dofile, path)
	if ok and type(p) == "table" then
		return p
	end
	return {
		bg = "#1e1e2e",
		bg_dark = "#11111b",
		surface = "#313244",
		overlay = "#45475a",
		border = "#232336",
		fg = "#cdd6f4",
		fg_dim = "#a6adc8",
		gray = "#6c7086",
		red = "#f38ba8",
		orange = "#fab387",
		yellow = "#f9e2af",
		green = "#a6e3a1",
		cyan = "#94e2d5",
		blue = "#89b4fa",
		purple = "#cba6f7",
		pink = "#f5c2e7",
		selection = "#313244",
	}
end

function M.apply()
	local p = palette()

	vim.o.termguicolors = true
	vim.o.background = "dark"
	vim.cmd("hi clear")
	if vim.fn.exists("syntax_on") == 1 then
		vim.cmd("syntax reset")
	end
	vim.g.colors_name = "notch"

	local set = function(group, opts)
		vim.api.nvim_set_hl(0, group, opts)
	end

	-- editor chrome
	set("Normal", { fg = p.fg, bg = p.bg })
	set("NormalNC", { fg = p.fg, bg = p.bg })
	set("NormalFloat", { fg = p.fg, bg = p.bg_dark })
	set("FloatBorder", { fg = p.surface, bg = p.bg_dark })
	set("FloatTitle", { fg = p.purple, bg = p.bg_dark })
	set("SignColumn", { bg = p.bg })
	set("CursorLine", { bg = p.selection })
	set("CursorLineNr", { fg = p.purple, bold = true })
	set("LineNr", { fg = p.overlay })
	set("ColorColumn", { bg = p.selection })
	set("WinSeparator", { fg = p.border, bg = p.bg })
	set("VertSplit", { fg = p.border, bg = p.bg })
	set("Folded", { fg = p.gray, bg = p.surface })
	set("FoldColumn", { fg = p.gray, bg = p.bg })
	set("Visual", { bg = p.selection })
	set("Search", { fg = p.bg, bg = p.yellow })
	set("IncSearch", { fg = p.bg, bg = p.orange })
	set("CurSearch", { fg = p.bg, bg = p.orange })
	set("MatchParen", { fg = p.pink, bold = true })
	set("Pmenu", { fg = p.fg, bg = p.bg_dark })
	set("PmenuSel", { fg = p.bg, bg = p.purple })
	set("PmenuSbar", { bg = p.surface })
	set("PmenuThumb", { bg = p.gray })
	set("StatusLine", { fg = p.fg, bg = p.surface })
	set("StatusLineNC", { fg = p.gray, bg = p.bg_dark })
	set("TabLine", { fg = p.gray, bg = p.bg_dark })
	set("TabLineFill", { bg = p.bg_dark })
	set("TabLineSel", { fg = p.bg, bg = p.purple })
	set("WinBar", { fg = p.purple, bg = p.bg })
	set("WinBarNC", { fg = p.gray, bg = p.bg })
	set("Cursor", { fg = p.bg, bg = p.fg })
	set("TermCursor", { fg = p.bg, bg = p.fg })
	set("Directory", { fg = p.blue })
	set("Title", { fg = p.purple, bold = true })
	set("NonText", { fg = p.overlay })
	set("EndOfBuffer", { fg = p.bg })
	set("Whitespace", { fg = p.surface })
	set("SpecialKey", { fg = p.gray })
	set("SpellBad", { undercurl = true, sp = p.red })
	set("SpellCap", { undercurl = true, sp = p.yellow })
	set("SpellLocal", { undercurl = true, sp = p.cyan })
	set("SpellRare", { undercurl = true, sp = p.purple })
	set("ErrorMsg", { fg = p.red })
	set("WarningMsg", { fg = p.yellow })
	set("ModeMsg", { fg = p.green })
	set("MoreMsg", { fg = p.green })
	set("Question", { fg = p.green })
	set("QuickFixLine", { bg = p.selection })

	-- syntax
	set("Comment", { fg = p.gray, italic = true })
	set("Constant", { fg = p.orange })
	set("String", { fg = p.green })
	set("Character", { fg = p.green })
	set("Number", { fg = p.orange })
	set("Float", { fg = p.orange })
	set("Boolean", { fg = p.orange })
	set("Identifier", { fg = p.fg })
	set("Function", { fg = p.blue })
	set("Statement", { fg = p.purple })
	set("Conditional", { fg = p.purple })
	set("Repeat", { fg = p.purple })
	set("Label", { fg = p.purple })
	set("Operator", { fg = p.cyan })
	set("Keyword", { fg = p.purple })
	set("Exception", { fg = p.purple })
	set("PreProc", { fg = p.pink })
	set("Include", { fg = p.purple })
	set("Define", { fg = p.purple })
	set("Macro", { fg = p.pink })
	set("PreCondit", { fg = p.pink })
	set("Type", { fg = p.yellow })
	set("StorageClass", { fg = p.yellow })
	set("Structure", { fg = p.yellow })
	set("Typedef", { fg = p.yellow })
	set("Special", { fg = p.cyan })
	set("SpecialChar", { fg = p.pink })
	set("Tag", { fg = p.yellow })
	set("Delimiter", { fg = p.fg_dim })
	set("SpecialComment", { fg = p.gray, italic = true })
	set("Debug", { fg = p.red })
	set("Underlined", { underline = true })
	set("Ignore", { fg = p.bg })
	set("Error", { fg = p.red })
	set("Todo", { fg = p.bg, bg = p.yellow })

	-- diagnostics
	local function diag(group, color)
		set(group, { fg = color })
		set(group .. "Sign", { fg = color })
		set(group .. "VirtualText", { fg = color })
	end
	diag("DiagnosticError", p.red)
	diag("DiagnosticWarn", p.yellow)
	diag("DiagnosticInfo", p.blue)
	diag("DiagnosticHint", p.cyan)
	set("DiagnosticUnderlineError", { undercurl = true, sp = p.red })
	set("DiagnosticUnderlineWarn", { undercurl = true, sp = p.yellow })
	set("DiagnosticUnderlineInfo", { undercurl = true, sp = p.blue })
	set("DiagnosticUnderlineHint", { undercurl = true, sp = p.cyan })

	-- diff / git
	set("DiffAdd", { bg = p.surface })
	set("DiffChange", { bg = p.surface })
	set("DiffDelete", { fg = p.red, bg = p.surface })
	set("DiffText", { bg = p.overlay })
	set("GitSignsAdd", { fg = p.green })
	set("GitSignsChange", { fg = p.yellow })
	set("GitSignsDelete", { fg = p.red })

	-- treesitter
	local ts = {
		["@comment"] = { link = "Comment" },
		["@keyword"] = { link = "Keyword" },
		["@string"] = { link = "String" },
		["@number"] = { link = "Number" },
		["@function"] = { link = "Function" },
		["@function.call"] = { link = "Function" },
		["@variable"] = { fg = p.fg },
		["@variable.builtin"] = { fg = p.orange },
		["@property"] = { fg = p.cyan },
		["@type"] = { link = "Type" },
		["@constant"] = { link = "Constant" },
		["@operator"] = { link = "Operator" },
		["@punctuation"] = { fg = p.fg_dim },
		["@parameter"] = { fg = p.orange },
		["@tag"] = { fg = p.purple },
	}
	for group, opts in pairs(ts) do
		set(group, opts)
	end

	vim.api.nvim_exec_autocmds("User", { pattern = "NotchTheme" })
end

M.apply()

-- Hot reload when the generated palette changes.
do
	local uv = vim.uv or vim.loop
	local path = vim.fn.stdpath("config") .. "/notch-palette.lua"
	local ok, watcher = pcall(uv.new_fs_event)
	if ok and watcher then
		-- Debounce so the write has finished before we re-read the palette.
		local timer = uv.new_timer()
		watcher:start(path, {}, function()
			timer:start(150, 0, vim.schedule_wrap(function()
				M.apply()
			end))
		end)
	end
end

return M
