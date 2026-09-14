---@diagnostic disable: undefined-global
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.path:append("**")
vim.opt.clipboard = "unnamedplus"
vim.opt.winborder = "bold"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes:1"
vim.o.cmdheight = 0

-- FOLDING
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldcolumn = "0"
vim.opt.foldtext = ""
vim.opt.foldlevel = 0
vim.opt.foldlevelstart = 99
local folded_ns = vim.api.nvim_create_namespace("user.folded")

local marked_curline = {}
local function clear_curline_mark(buf)
	local lnum = marked_curline[buf]
	if lnum then
		vim.api.nvim_buf_clear_namespace(buf, folded_ns, lnum - 1, lnum)
		marked_curline[buf] = nil
	end
end

local function cursorline_folded(win, buf)
	if not vim.wo[win].cursorline then
		clear_curline_mark(buf)
		return
	end

	local curline = vim.api.nvim_win_get_cursor(win)[1]
	local lnum = marked_curline[buf]
	local foldstart = vim.fn.foldclosed(curline)
	if foldstart == -1 then
		clear_curline_mark(buf)
		return
	end

	local foldend = vim.fn.foldclosedend(curline)
	if lnum then
		if foldstart > lnum or foldend < lnum then
			clear_curline_mark(buf)
		end
	else
		vim.api.nvim_buf_set_extmark(buf, folded_ns, foldstart - 1, 0, {
			-- this is not working with ephemeral for some reason
			line_hl_group = "CursorLine",
			hl_mode = "combine",
			-- ephemeral = true,
		})
		marked_curline[buf] = foldstart
	end
end

-- optional
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("bold_highlight", {}),
	callback = function()
		vim.api.nvim_set_hl(0, "Bold", { bold = true })
	end,
})

local folded_segments = {}
local function render_folded_segments(win, buf, foldstart)
	local foldend = vim.fn.foldclosedend(foldstart)

	local virt_text = {}
	for _, call in ipairs(folded_segments) do
		local chunks = call(buf, foldstart, foldend)
		if chunks then
			vim.list_extend(virt_text, chunks)
		end
	end

	if vim.tbl_isempty(virt_text) then
		return
	end

	local text = vim.api.nvim_buf_get_lines(buf, foldstart - 1, foldstart, false)[1]:match("^(.-)%s*$")
	local wininfo = vim.fn.getwininfo(win)[1]
	local leftcol = wininfo and wininfo.leftcol or 0
	local padding = 3
	local wincol = math.max(0, vim.fn.virtcol({ foldstart, text:len() }) - leftcol)

	vim.api.nvim_buf_set_extmark(buf, folded_ns, foldstart - 1, 0, {
		virt_text = virt_text,
		virt_text_pos = "overlay",
		virt_text_win_col = padding + wincol,
		hl_mode = "combine",
		ephemeral = true,
		priority = 0,
	})

	return foldend
end

local function folded_win_decorator(win, buf, topline, botline)
	cursorline_folded(win, buf)

	local line = topline
	while line <= botline do
		local foldstart = vim.fn.foldclosed(line)
		if foldstart ~= -1 then
			line = render_folded_segments(win, buf, foldstart)
		end
		line = line + 1
	end
end

table.insert(folded_segments, function(_, foldstart, foldend)
	return {
		{ " 󰘕 " .. (foldend - foldstart) .. " ", { "Bold", "MoreMsg" } },
	}
end)

table.insert(folded_segments, function(buf, foldstart, foldend)
	if not vim.o.hlsearch or vim.v.hlsearch == 0 then
		return
	end

	local sucess, matches = pcall(vim.fn.matchbufline, buf, vim.fn.getreg("/"), foldstart, foldend)
	if not sucess then
		return
	end

	local searchcount = #matches
	if searchcount > 0 then
		return { { " " .. searchcount .. " ", { "Bold", "Question" } } }
	end
end)

local diag_icons = {
	[vim.diagnostic.severity.ERROR] = "󰅙",
	[vim.diagnostic.severity.WARN] = "",
	[vim.diagnostic.severity.INFO] = "",
	[vim.diagnostic.severity.HINT] = "󱠃",
}
local diag_hls = {
	[vim.diagnostic.severity.ERROR] = "DiagnosticError",
	[vim.diagnostic.severity.WARN] = "DiagnosticWarn",
	[vim.diagnostic.severity.INFO] = "DiagnosticInfo",
	[vim.diagnostic.severity.HINT] = "DiagnosticHint",
}
table.insert(folded_segments, function(buf, foldstart, foldend)
	local diag_counts = {}
	for lnum = foldstart - 1, foldend - 1 do
		for severity, value in pairs(vim.diagnostic.count(buf, { lnum = lnum })) do
			diag_counts[severity] = value + (diag_counts[severity] or 0)
		end
	end

	local chunks = {}
	for severity = vim.diagnostic.severity.ERROR, vim.diagnostic.severity.HINT do
		if diag_counts[severity] then
			table.insert(chunks, {
				string.format("%s %d ", diag_icons[severity], diag_counts[severity]),
				{ "Bold", diag_hls[severity] },
			})
		end
	end

	return chunks
end)

vim.opt.fillchars:append({
	-- fold = '─' -- horizontal line
	fold = " ", -- just show nothing
})

vim.api.nvim_set_decoration_provider(folded_ns, {
	on_win = function(_, win, buf, topline, botline)
		vim.api.nvim_win_call(win, function()
			folded_win_decorator(win, buf, topline, botline)
		end)
	end,
})


vim.opt.undodir = vim.fn.stdpath("data") .. "/undo"
vim.opt.undofile = true

-- Local plugin: ztk.nvim
vim.opt.runtimepath:prepend("/home/himanshu/personal/projects/ztk")

require('vim._core.ui2').enable()

vim.g.mapleader = " "


vim.pack.add({
	"https://github.com/iamcco/markdown-preview.nvim",
	"https://github.com/lewis6991/gitsigns.nvim",
	-- "https://github.com/supermaven-inc/supermaven-nvim",
	"https://github.com/echasnovski/mini.ai",
	"https://github.com/echasnovski/mini.pairs",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/esmuellert/codediff.nvim",
	"https://github.com/CopilotC-Nvim/CopilotChat.nvim",
	"https://github.com/smnatale/coderabbit.nvim",
	"https://github.com/williamboman/mason.nvim",
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/stevearc/oil.nvim",
	"https://github.com/nvim-treesitter/nvim-treesitter",
	"https://github.com/tpope/vim-fugitive",
	"https://github.com/ibhagwan/fzf-lua",
	"https://github.com/Saghen/blink.lib",
	"https://github.com/Saghen/blink.cmp",
	"https://github.com/brenoprata10/nvim-highlight-colors",
	"https://github.com/HakonHarnes/img-clip.nvim",
	"https://github.com/lervag/vimtex",
	"https://github.com/cachebag/jumpy.nvim",
	"https://github.com/fxn/vim-monochrome",
	"https://github.com/stevearc/quicker.nvim",
	"https://github.com/michaelb/sniprun"
})

require("sniprun").setup({
	binary_path = "/usr/sbin/sniprun",
	-- Language-specific interpreters
	selected_interpreters = {
		'Python3_fifo', -- Python with FIFO-based REPL (no klepto dependency)
		'Go_original', -- Go
		'C_original', -- C
		'Cpp_original', -- C++
		'Lua_nvim', -- Lua (with Neovim integration)
	},
	-- Enable REPL mode for languages that support it
	repl_enable = { 'Python3_fifo', 'Lua_nvim' },
	-- Display output in a split terminal (shows code history too)
	display = { "TerminalWithCode" },
	display_options = {
		terminal_scrollback = vim.o.scrollback,
		terminal_line_number = false,
		terminal_signcolumn = false,
		terminal_position = "vertical",
		terminal_width = 45,
	},
})

vim.api.nvim_set_keymap('v', '<leader>r', '<Plug>SnipRun', { silent = true })
-- Additional sniprun mappings for REPL and terminal control
vim.api.nvim_set_keymap('n', '<leader>rr', ':SnipReplMemoryClean<CR>', { silent = true, desc = 'Clear REPL memory' })
vim.api.nvim_set_keymap('n', '<leader>rt', ':SnipClose<CR>', { silent = true, desc = 'Close sniprun terminal' })

dofile(vim.fn.stdpath("config") .. "/theme.lua")
require("mason").setup()
require("coderabbit").setup()
require("oil").setup()
require("mini.ai").setup()
require("CopilotChat").setup()
require("mini.pairs").setup()
require("nvim-highlight-colors").setup()
require("img-clip").setup()
require("quicker").setup()

-- require("markdown-preview").setup()

require("fzf-lua").setup({
	"ivy",
	keymap = {
		fzf = {
			true, -- merge with fzf-lua defaults instead of replacing them
			["ctrl-q"] = "select-all+accept",
			["ctrl-n"] = "down",
			["ctrl-p"] = "up",
		},
	},
})

require("fzf-lua").register_ui_select()

require("blink.cmp").setup({
	keymap = { preset = "default" },
	appearance = {
		-- use_nvim_cmp_as_default = true,
		nerd_font_variant = "mono",
	},
	sources = {
		default = { "lsp", "path", "snippets", "buffer" },
	},
})

-- require("supermaven-nvim").setup({
-- 	keymaps = {
-- 		accept_suggestion = "<Tab>",
-- 		clear_suggestion = "<C-]>",
-- 		accept_word = "<C-j>",
-- 	},
-- })
require("nvim-treesitter").setup({
	ensure_installed = {
		"lua",
		"python",
		"javascript",
		"typescript",
		"rust",
		"c",
		"cpp",
		"typst",
		"vim",
		"vimdoc",
		"go",
		"json"
	},

	highlight = {
		enable = true,
	},

	indent = {
		enable = true,
	},
})


vim.lsp.enable({ "basedpyright", "gopls", "lua_ls", "ts_ls", "emmet_ls", "tinymist", "rustfmt" })

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.keymap.set("n", "<leader>p", ":PasteImage<CR>")
vim.keymap.set("n", "<Esc>", ":nohl<CR>")
vim.keymap.set("n", "<leader>q", ":bd<CR>")
vim.keymap.set("n", "<leader>fg", require("fzf-lua").live_grep)
-- vim.keymap.set("n", "<leader>fg",
-- 	function()
-- 		require("telescope.builtin").live_grep(require('telescope.themes').get_ivy({}))
-- 	end)
vim.keymap.set("n", "<leader>ff", require("fzf-lua").files)
-- vim.keymap.set("n", "<leader>ff",
-- 	function() require("telescope.builtin").find_files(require('telescope.themes').get_ivy({})) end)
vim.keymap.set("n", "<leader><leader>", require("fzf-lua").buffers)

vim.keymap.set("n", "<leader>ft", ":Oil<CR>")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("n", "<C-e>", "<C-^>")
vim.keymap.set("n", "<C-\\>", function()
	vim.cmd("enew")
	vim.cmd("terminal")
end)
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])
vim.keymap.set("t", "<leader>q", [[<C-\><C-n><cmd>close<CR>]])
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		vim.bo[args.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "typst",
	callback = function()
		vim.bo.makeprg = "typst compile %"
	end,
})

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		vim.api.nvim_create_autocmd("BufWritePre", {
			group = vim.api.nvim_create_augroup("my.lsp", { clear = false }),
			buffer = ev.buf,
			callback = function()
				vim.lsp.buf.format({
					bufnr = ev.buf,
					id = client.id,
					timeout_ms = 1000,
				})
			end,
		})
	end,
})

vim.keymap.set("n", "<leader>dg", function()
	vim.diagnostic.setqflist()
	vim.cmd("copen")
end)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "<leader>gs", "<cmd>Git<CR>")

vim.keymap.set("n", "<leader>z", function()
	local dirs = vim.fn.systemlist("zoxide query -l")

	require("fzf-lua").fzf_exec(dirs, {
		prompt = "Zoxide> ",
		actions = {
			["default"] = function(selected)
				if selected and selected[1] then
					require("oil").open(selected[1])
				end
			end,
		},
	})
end)

vim.keymap.set("n", "<leader>Z", function()
	local dirs = vim.fn.systemlist("zoxide query -l")

	require("fzf-lua").fzf_exec(dirs, {
		prompt = "Zoxide cd> ",
		actions = {
			["default"] = function(selected)
				if selected and selected[1] then
					vim.cmd.cd(vim.fn.fnameescape(selected[1]))
					require("oil").open(selected[1])
				end
			end,
		},
	})
end)

require("gitsigns").setup()

-- require("jumpy").setup(
-- 	{
-- 		provider = "openrouter",
-- 	}
-- )

vim.keymap.set("n", "<leader>ds", ":FzfLua lsp_document_symbols<CR>")

local function copy_buffer_path()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	vim.fn.setreg('+', path)
	print("Copied buffer path: " .. path)
end

vim.keymap.set('n', '<leader>cp', copy_buffer_path, { desc = 'Copy buffer path to clipboard' })
vim.keymap.set('n', '<leader>mp', ":MarkdownPreview<CR>")
vim.keymap.set('n', '<leader>gb', ":Git blame<CR>")

vim.api.nvim_create_autocmd("User", {
	pattern = "PackChanged",
	callback = function(args)
		if args.data.spec.name == "markdown-preview.nvim" then
			vim.fn["mkdp#util#install"]()
		end
	end,
})
