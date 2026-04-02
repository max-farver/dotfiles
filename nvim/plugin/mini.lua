-- `MiniXxx` table that can be later used to access module's features.
--
-- Every module's `setup()` function accepts an optional `config` table to
-- adjust its behavior. See the structure of this table at `:h MiniXxx.config`.
--
-- See `:h mini.nvim-general-principles` for more general principles.
--
-- Here each module's `setup()` has a brief explanation of what the module is for,
-- its usage examples (uses Leader mappings from 'plugin/20_keymaps.lua'), and
-- possible directions for more info.
-- For more info about a module see its help page (`:h mini.xxx` for 'mini.xxx').

-- To minimize the time until first screen draw, modules are enabled in two steps:
-- - Step one enables everything that is needed for first draw with `now()`.
--   Sometimes is needed only if Neovim is started as `nvim -- path/to/file`.
-- - Everything else is delayed until the first draw with `later()`.
local now, later = MiniDeps.now, MiniDeps.later
local now_if_args = _G.Config.now_if_args
local root = _G.Config.root.get

local map = _G.Config.map
local nmap_leader = _G.Config.nmap_leader

now(function()
	require('mini.basics').setup()
end)

-- Icon provider. Usually no need to use manually. It is used by plugins like
-- 'mini.pick', 'mini.files', 'mini.statusline', and others.
now(function()
	-- Set up to not prefer extension-based icon for some extensions
	local ext3_blocklist = { scm = true, txt = true, yml = true }
	local ext4_blocklist = { json = true, yaml = true }
	require('mini.icons').setup({
		file = {
			[".keep"] = { glyph = "󰊢" },
			["devcontainer.json"] = { glyph = "" },
		},
		filetype = {
			dotenv = { glyph = "" },
		},
		use_file_extension = function(ext, _)
			return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
		end,
	})

	-- Mock 'nvim-tree/nvim-web-devicons' for plugins without 'mini.icons' support.
	-- Not needed for 'mini.nvim' or MiniMax, but might be useful for others.
	later(MiniIcons.mock_nvim_web_devicons)

	-- Add LSP kind icons. Useful for 'mini.completion'.
	later(MiniIcons.tweak_lsp_kind)
end)

now_if_args(function()
	-- Makes `:h MiniMisc.put()` and `:h MiniMisc.put_text()` public
	require('mini.misc').setup()

	-- Change current working directory based on the current file path. It
	-- searches up the file tree until the first root marker ('.git' or 'Makefile')
	-- and sets their parent directory as a current directory.
	-- This is helpful when simultaneously dealing with files from several projects.
	MiniMisc.setup_auto_root()

	-- Restore latest cursor position on file open
	MiniMisc.setup_restore_cursor()

end)

now(function() require('mini.notify').setup() end)

now(function() require('mini.extra').setup() end)

later(function()
	require("mini.operators").setup({
		replace = {
			prefix = "<s-r>",
			reindent_linewise = true,
		}
	})
end)

now(function()
	local function ai_buffer(ai_type)
		local start_line, end_line = 1, vim.fn.line("$")
		if ai_type == "i" then
			local first_nonblank, last_nonblank = vim.fn.nextnonblank(start_line), vim.fn.prevnonblank(end_line)
			if first_nonblank == 0 or last_nonblank == 0 then
				return { from = { line = start_line, col = 1 } }
			end
			start_line, end_line = first_nonblank, last_nonblank
		end

		local to_col = math.max(vim.fn.getline(end_line):len(), 1)
		return { from = { line = start_line, col = 1 }, to = { line = end_line, col = to_col } }
	end

	local ai = require("mini.ai")
	ai.setup({
		custom_textobjects = {
			o = ai.gen_spec.treesitter({
				a = { "@block.outer", "@conditional.outer", "@loop.outer" },
				i = { "@block.inner", "@conditional.inner", "@loop.inner" },
			}),
			f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
			c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
			t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
			d = { "%f[%d]%d+" },
			e = {
				{ "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
				"^().*()$",
			},
			g = ai_buffer,
			u = ai.gen_spec.function_call(),
			U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }),
		},
	})
end)

later(function()
	require("mini.animate").setup({
		scroll = { enable = false },
	})
end)

later(function()
	require('mini.cursorword').setup()
end)

now(function()
	local clue = require("mini.clue")

	local triggers = {
		{ mode = "n", keys = "<Leader>" },
		{ mode = "x", keys = "<Leader>" },
		{ mode = "o", keys = "<Leader>" },
		{ mode = "n", keys = "[" },
		{ mode = "n", keys = "]" },
		{ mode = "n", keys = "g" },
		{ mode = "x", keys = "g" },
		{ mode = "n", keys = "z" },
		{ mode = "x", keys = "z" },
		{ mode = "n", keys = "<C-w>" },
		{ mode = "i", keys = "<C-x>" },
	}

	local clues = {
		clue.gen_clues.builtin_completion(),
		clue.gen_clues.marks(),
		clue.gen_clues.registers(),
		clue.gen_clues.windows(),
		clue.gen_clues.z(),
		clue.gen_clues.g(),
		{ mode = "n", keys = "<Leader>a",     desc = "AI" },
		{ mode = "n", keys = "<Leader>b",     desc = "Buffers" },
		{ mode = "n", keys = "<Leader>c",     desc = "Code" },
		{ mode = "n", keys = "<Leader>d",     desc = "Debug" },
		{ mode = "n", keys = "<Leader>f",     desc = "Find" },
		{ mode = "x", keys = "<Leader>f",     desc = "Find" },
		{ mode = "n", keys = "<Leader>g",     desc = "Git" },
		{ mode = "x", keys = "<Leader>g",     desc = "Git" },
		{ mode = "n", keys = "<Leader>cl",    desc = "LSP" },
		{ mode = "n", keys = "<Leader>o",     desc = "Obsidian" },
		{ mode = "n", keys = "<Leader>x",     desc = "Quickfix" },
		{ mode = "n", keys = "<Leader>s",     desc = "Search" },
		{ mode = "n", keys = "<Leader><Tab>", desc = "Tab" },
		{ mode = "n", keys = "<Leader>t",     desc = "Terminal/Test" },
		{ mode = "n", keys = "<Leader>u",     desc = "UI" },
		{ mode = "n", keys = "<Leader>w",     desc = "Windows" },
	}

	local max_desc = 0
	for _, entry in ipairs(clues) do
		if type(entry) == "table" and type(entry.desc) == "string" then
			if #entry.desc > max_desc then
				max_desc = #entry.desc
			end
		end
	end

	local cols = vim.o.columns
	local computed = max_desc + 22
	local width = math.max(40, math.min(math.floor(cols * 0.6), math.min(100, computed)))

	vim.o.timeoutlen = vim.o.timeoutlen > 0 and vim.o.timeoutlen or 300

	clue.setup({
		window = {
			delay = 100,
			config = { width = width, border = "rounded" },
		},
		triggers = triggers,
		clues = clues,
	})
end)


now(function()
	require("mini.diff").setup({
		view = { style = "number" },
	})
end)

later(function()
	local hipatterns = require("mini.hipatterns")
	hipatterns.setup({
		highlighters = {
			hex_color = hipatterns.gen_highlighter.hex_color(),
		},
	})
end)

later(function()
	require("mini.indentscope").setup({})
end)

later(function()
	require("mini.move").setup({
		mappings = {
			left = "<M-Left>",
			right = "<M-Right>",
			down = "<M-Down>",
			up = "<M-Up>",
			line_left = "<M-Left>",
			line_right = "<M-Right>",
			line_down = "<M-Down>",
			line_up = "<M-Up>",
		},
	})
end)

later(function()
	require("mini.pairs").setup({})
end)

later(function()
	require("mini.visits").setup()

	-- Visit labels (add/remove)
	map('n', '<leader>la', function()
		local label = vim.fn.input('Label: ')
		if label ~= '' then MiniVisits.add_label(label) end
	end, { desc = 'Add Visit Label' })
	map('n', '<leader>ld', function()
		local label = vim.fn.input('Label: ')
		if label ~= '' then MiniVisits.remove_label(label) end
	end, { desc = 'Remove Visit Label' })
end)

now(function()
	require("mini.surround").setup({
		mappings = {
			add = "gsa",
			delete = "gsd",
			find = "gsf",
			find_left = "gsF",
			highlight = "gsh",
			replace = "gsr",
			update_n_lines = "gsn",
		},
	})
end)

now(function()
	local MiniFiles = require("mini.files")
	MiniFiles.setup({
		mappings = {
			close = "q",
			go_in = "l",
			go_in_plus = "<Right>",
			go_out = "h",
			go_out_plus = "<Left>",
			mark_goto = "'",
			mark_set = "m",
			reset = "<BS>",
			reveal_cwd = "@",
			show_help = "g?",
			synchronize = "S",
			trim_left = "<",
			trim_right = ">",
		},
		use_as_default_explorer = true,
		permanent_delete = true,
	})

	map('n', '<leader>fE', '<Cmd>lua MiniFiles.open(vim.uv.cwd(), true)<CR>', { desc = 'Explorer (cwd)' })
	map('n', '<leader>e', function()
		local file = vim.api.nvim_buf_get_name(0)
		local dir = (file ~= '' and vim.fn.fnamemodify(file, ':h')) or vim.uv.cwd()
		MiniFiles.open(dir, true)
	end, { desc = 'Explorer (Current File Dir)' })

	vim.api.nvim_create_autocmd("User", {
		pattern = "MiniFilesBufferCreate",
		callback = function(args)
			local buf = args.data.buf_id

			vim.keymap.set("n", "Q", function()
				pcall(function() MiniFiles.synchronize() end)
				pcall(function() MiniFiles.close() end)
			end, { buffer = buf, desc = "mini.files: Sync and close" })
		end,
	})
end)

now(function()
	local pick_ok, pick = pcall(require, "mini.pick")
	if not pick_ok then
		return
	end

	vim.ui.select = pick.ui_select

	local function map_send_to_qf()
		local matches = pick.get_picker_matches()
		if not matches then
			return false
		end
		local items = {}
		if matches.marked and #matches.marked > 0 then
			items = matches.marked
		elseif matches.all and #matches.all > 0 then
			items = matches.all
		end
		if #items == 0 then
			vim.notify("No items to send to quickfix", vim.log.levels.INFO)
			return false
		end
		pick.default_choose_marked(items, { list_type = "quickfix" })
		vim.schedule(function() vim.cmd("copen") end)
		return false
	end

	local setup_opts = {
		mappings = {
			send_to_qf = { char = "<C-q>", func = map_send_to_qf },
		},
	}

	pick.setup(setup_opts)

	require("util.pickers").register(pick)

	local function pick_files(opts)
		opts = opts or {}
		local show_hidden = true

		local function build_command()
			local cmd = { "rg", "--files", "--color=never" }
			if show_hidden then
				vim.list_extend(cmd, { "--hidden", "--glob", "!.git" })
			end
			return cmd
		end

		local function toggle_hidden()
			show_hidden = not show_hidden
			MiniPick.set_picker_items_from_cli(build_command())
		end

		local show = function(buf_id, items, query)
			MiniPick.default_show(buf_id, items, query, { show_icons = true })
		end

		MiniPick.builtin.cli(
			{ command = build_command(), spawn_opts = { cwd = opts.cwd } },
			{
				source = {
					name = "Files",
					show = show,
					cwd = opts.cwd,
				},
				mappings = {
					toggle_hidden = { char = "<M-h>", func = toggle_hidden },
				},
			}
		)
	end

	local function with_pick(fn, opts)
		return function()
			if not MiniPick or not MiniExtra then
				vim.notify('MiniPick not available', vim.log.levels.WARN)
				return
			end

			-- Prefer builtin pickers
			if MiniPick.builtin and type(MiniPick.builtin[fn]) == 'function' then
				MiniPick.builtin[fn](opts or {})
				return
			end

			-- Fallback to mini.extra pickers
			if MiniExtra and MiniExtra.pickers and type(MiniExtra.pickers[fn]) == 'function' then
				MiniExtra.pickers[fn](opts or {})
				return
			end

			vim.notify("Picker '" .. tostring(fn) .. "' not available", vim.log.levels.WARN)
		end
	end

	-- Files
	nmap_leader('<leader>', function() pick_files({ cwd = root() }) end, 'Find Files (Root Dir)')
	map('n', '<leader>fF', function() pick_files({ cwd = vim.uv.cwd() }) end, { desc = 'Find Files (cwd)' })
	map('n', '<leader>fb', with_pick 'buffers', { desc = 'Buffers' })
	map('n', '<leader>fo', with_pick('visit_paths', { cwd = root() }), { desc = 'Visits (Root Dir)' })
	map('n', '<leader>fV', with_pick('visit_paths', { cwd = '' }), { desc = 'Visits (All)' })
	map('n', '<leader>fl', with_pick('visit_labels', { cwd = root() }), { desc = 'Visit Labels (Root Dir)' })
	map('n', '<leader>fL', with_pick('visit_labels', { cwd = '' }), { desc = 'Visit Labels (All)' })

	-- Search
	map('n', '<leader>/', with_pick('grep_live', { cwd = root() }), { desc = 'Search (Live Grep, Root)' })
	map('n', '<leader>?', with_pick('grep_live', { cwd = vim.uv.cwd() }), { desc = 'Search (Live Grep, cwd)' })
	map('n', '<leader>sh', with_pick 'help', { desc = 'Help Tags' })

	-- Commands and keymaps pickers (mini.pick)
	map('n', '<leader>sC', with_pick 'commands', { desc = 'Search Commands' })
	map('n', '<leader>sk', with_pick 'keymaps', { desc = 'Search Keymaps' })
	map('n', '<leader>sd', with_pick 'diagnostics', { desc = 'Search Diagnostics' })

	-- Notifications
	map('n', '<leader>sn', with_pick 'notifications', { desc = 'Search Notifications' })

	-- LSP pickers (mini.pick custom)
	map('n', 'grr', with_pick('lsp', { scope = 'references' }), { desc = 'LSP References' })
	map('n', 'gri', with_pick('lsp', { scope = 'implementation' }), { desc = 'LSP Implementations' })
	map('n', 'grd', with_pick('lsp', { scope = 'definition' }), { desc = 'LSP Definitions' })
	map('n', 'gd', with_pick('lsp', { scope = 'definition' }), { desc = 'LSP Definitions' })
	map('n', 'grs', with_pick('lsp', { scope = 'document_symbol' }), { desc = 'LSP Document Symbols' })

	-- Git pickers (mini.pick custom)
	map('n', '<leader>sS', with_pick 'git_status', { desc = 'Git Status' })
	map('n', '<leader>sB', with_pick 'git_branches', { desc = 'Git Branches' })
	map('n', '<leader>sT', with_pick 'git_stash', { desc = 'Git Stash' })
	map('n', '<leader>sF', with_pick 'git_log_file', { desc = 'Git File Commits' })
	map('n', '<leader>sG', with_pick 'git_log', { desc = 'Git Log' })
end)
