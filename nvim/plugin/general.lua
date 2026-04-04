local add_once = _G.Config.pack_add_once or _G.Config.pack_add
local now, later = _G.Config.now, _G.Config.later
local map = _G.Config.map
local nmap_leader = _G.Config.nmap_leader
local root = _G.Config.root.get

-- Mini editing & textobjects
later(function()
	require("mini.operators").setup({
		replace = {
			prefix = "<s-r>",
			reindent_linewise = true,
		},
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
	require("mini.cursorword").setup()
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

	map("n", "<leader>la", function()
		local label = vim.fn.input("Label: ")
		if label ~= "" then
			MiniVisits.add_label(label)
		end
	end, { desc = "Add Visit Label" })
	map("n", "<leader>ld", function()
		local label = vim.fn.input("Label: ")
		if label ~= "" then
			MiniVisits.remove_label(label)
		end
	end, { desc = "Remove Visit Label" })
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

-- Mini navigation: files + pick
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

	map("n", "<leader>fE", "<Cmd>lua MiniFiles.open(vim.uv.cwd(), true)<CR>", { desc = "Explorer (cwd)" })
	map("n", "<leader>e", function()
		local file = vim.api.nvim_buf_get_name(0)
		local dir = (file ~= "" and vim.fn.fnamemodify(file, ":h")) or vim.uv.cwd()
		MiniFiles.open(dir, true)
	end, { desc = "Explorer (Current File Dir)" })

	vim.api.nvim_create_autocmd("User", {
		pattern = "MiniFilesBufferCreate",
		callback = function(args)
			local buf = args.data.buf_id

			vim.keymap.set("n", "Q", function()
				pcall(function()
					MiniFiles.synchronize()
				end)
				pcall(function()
					MiniFiles.close()
				end)
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
		vim.schedule(function()
			vim.cmd("copen")
		end)
		return false
	end

	pick.setup({
		mappings = {
			send_to_qf = { char = "<C-q>", func = map_send_to_qf },
		},
	})

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
				vim.notify("MiniPick not available", vim.log.levels.WARN)
				return
			end

			if MiniPick.builtin and type(MiniPick.builtin[fn]) == "function" then
				MiniPick.builtin[fn](opts or {})
				return
			end

			if MiniExtra and MiniExtra.pickers and type(MiniExtra.pickers[fn]) == "function" then
				MiniExtra.pickers[fn](opts or {})
				return
			end

			vim.notify("Picker '" .. tostring(fn) .. "' not available", vim.log.levels.WARN)
		end
	end

	nmap_leader("<leader>", function()
		pick_files({ cwd = root() })
	end, "Find Files (Root Dir)")
	map("n", "<leader>fF", function()
		pick_files({ cwd = vim.uv.cwd() })
	end, { desc = "Find Files (cwd)" })
	map("n", "<leader>fb", with_pick("buffers"), { desc = "Buffers" })
	map("n", "<leader>fo", with_pick("visit_paths", { cwd = root() }), { desc = "Visits (Root Dir)" })
	map("n", "<leader>fV", with_pick("visit_paths", { cwd = "" }), { desc = "Visits (All)" })
	map("n", "<leader>fl", with_pick("visit_labels", { cwd = root() }), { desc = "Visit Labels (Root Dir)" })
	map("n", "<leader>fL", with_pick("visit_labels", { cwd = "" }), { desc = "Visit Labels (All)" })

	map("n", "<leader>/", with_pick("grep_live", { cwd = root() }), { desc = "Search (Live Grep, Root)" })
	map("n", "<leader>?", with_pick("grep_live", { cwd = vim.uv.cwd() }), { desc = "Search (Live Grep, cwd)" })
	map("n", "<leader>sh", with_pick("help"), { desc = "Help Tags" })

	map("n", "<leader>sC", with_pick("commands"), { desc = "Search Commands" })
	map("n", "<leader>sk", with_pick("keymaps"), { desc = "Search Keymaps" })
	map("n", "<leader>sd", with_pick("diagnostics"), { desc = "Search Diagnostics" })
	map("n", "<leader>sn", with_pick("notifications"), { desc = "Search Notifications" })

	map("n", "grr", with_pick("lsp", { scope = "references" }), { desc = "LSP References" })
	map("n", "gri", with_pick("lsp", { scope = "implementation" }), { desc = "LSP Implementations" })
	map("n", "grd", with_pick("lsp", { scope = "definition" }), { desc = "LSP Definitions" })
	map("n", "gd", with_pick("lsp", { scope = "definition" }), { desc = "LSP Definitions" })
	map("n", "grs", with_pick("lsp", { scope = "document_symbol" }), { desc = "LSP Document Symbols" })

	map("n", "<leader>sS", with_pick("git_status"), { desc = "Git Status" })
	map("n", "<leader>sB", with_pick("git_branches"), { desc = "Git Branches" })
	map("n", "<leader>sT", with_pick("git_stash"), { desc = "Git Stash" })
	map("n", "<leader>sF", with_pick("git_log_file"), { desc = "Git File Commits" })
	map("n", "<leader>sG", with_pick("git_log"), { desc = "Git Log" })
end)

now(function()
	add_once({ { src = "https://github.com/christoomey/vim-tmux-navigator" } })

	map('n', '<c-Left>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Tmux Left' })
	map('n', '<c-h>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Tmux Left' })
	map('n', '<c-Down>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Tmux Down' })
	map('n', '<c-j>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Tmux Down' })
	map('n', '<c-Up>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Tmux Up' })
	map('n', '<c-k>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Tmux Up' })
	map('n', '<c-Right>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Tmux Right' })
	map('n', '<c-l>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Tmux Right' })
	map('n', '<c-\\>', '<cmd>TmuxNavigatePrevious<cr>', { desc = 'Tmux Previous' })
end)

later(function()
	add_once({ { src = "https://github.com/folke/flash.nvim" } })
	require("flash").setup()

	-- Flash (jump/search)
	map({ 'n', 'x', 'o' }, 's', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.jump()
		end
	end, { desc = 'Flash' })
	map({ 'n', 'x', 'o' }, 'S', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.treesitter()
		end
	end, { desc = 'Flash Treesitter' })
	map('o', 'r', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.remote()
		end
	end, { desc = 'Remote Flash' })
	map({ 'o', 'x' }, 'R', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.treesitter_search()
		end
	end, { desc = 'Treesitter Search' })
	map('c', '<c-s>', function()
		local ok, f = pcall(require, 'flash')
		if ok then
			f.toggle()
		end
	end, { desc = 'Toggle Flash Search' })
end)

later(function()
	add_once({ { src = "https://github.com/gbprod/yanky.nvim" } })
	require("yanky").setup({
		highlight = { timer = 150 },
	})

	map({ 'n', 'x' }, 'y', '<Plug>(YankyYank)', { desc = 'Yank Text' })
	map({ 'n', 'x' }, 'p', '<Plug>(YankyPutAfter)', { desc = 'Put After' })
	map({ 'n', 'x' }, 'P', '<Plug>(YankyPutBefore)', { desc = 'Put Before' })
	map({ 'n', 'x' }, 'gp', '<Plug>(YankyGPutAfter)', { desc = 'GPut After' })
	map({ 'n', 'x' }, 'gP', '<Plug>(YankyGPutBefore)', { desc = 'GPut Before' })
	map('n', '[y', '<Plug>(YankyCycleForward)', { desc = 'Yank Cycle Fwd' })
	map('n', ']y', '<Plug>(YankyCycleBackward)', { desc = 'Yank Cycle Back' })
	map('n', ']p', '<Plug>(YankyPutIndentAfterLinewise)', { desc = 'Put Indented After (Linewise)' })
	map('n', '[p', '<Plug>(YankyPutIndentBeforeLinewise)', { desc = 'Put Indented Before (Linewise)' })
	map('n', ']P', '<Plug>(YankyPutIndentAfterLinewise)', { desc = 'Put Indented After (Linewise)' })
	map('n', '[P', '<Plug>(YankyPutIndentBeforeLinewise)', { desc = 'Put Indented Before (Linewise)' })
	map('n', '>p', '<Plug>(YankyPutIndentAfterShiftRight)', { desc = 'Put and Indent Right' })
	map('n', '<p', '<Plug>(YankyPutIndentAfterShiftLeft)', { desc = 'Put and Indent Left' })
	map('n', '>P', '<Plug>(YankyPutIndentBeforeShiftRight)', { desc = 'Put Before and Indent Right' })
	map('n', '<P', '<Plug>(YankyPutIndentBeforeShiftLeft)', { desc = 'Put Before and Indent Left' })
	map('n', '=p', '<Plug>(YankyPutAfterFilter)', { desc = 'Put After Filter' })
	map('n', '=P', '<Plug>(YankyPutBeforeFilter)', { desc = 'Put Before Filter' })
	map({ 'n', 'x' }, '<leader>p', function()
		local ok, pick = pcall(require, 'mini.pick')
		if ok and pick.builtin and pick.builtin.yanky then
			pick.builtin.yanky()
			return
		end
		vim.cmd [[YankyRingHistory]]
	end, { desc = 'Open Yank History' })
end)

later(function()
	add_once({ { src = "https://github.com/stevearc/overseer.nvim" } })
	require("overseer").setup()
end)

later(function()
	add_once({ { src = "https://github.com/smjonas/inc-rename.nvim" } })
	require("inc_rename").setup()
end)

later(function()
	add_once({
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = 'main' },
	})

	_G.Config.nvim_ts = require("nvim-treesitter")

	add_once({
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = 'main' },
	})
	require("nvim-treesitter-textobjects").setup({
		select = {
			enable = true,
			lookahead = true,
			keymaps = {
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",
				["al"] = "@loop.outer",
				["il"] = "@loop.inner",
				["aC"] = "@conditional.outer",
				["iC"] = "@conditional.inner",
				["ab"] = "@block.outer",
				["ib"] = "@block.inner",
				["as"] = "@statement.outer",
			},
		},
		move = {
			enable = true,
			set_jumps = true,
			goto_next_start = {
				["]f"] = "@function.outer",
				["]c"] = "@class.outer",
			},
			goto_next_end = {
				["]F"] = "@function.outer",
				["]C"] = "@class.outer",
			},
			goto_previous_start = {
				["[f"] = "@function.outer",
				["[c"] = "@class.outer",
			},
			goto_previous_end = {
				["[F"] = "@function.outer",
				["[C"] = "@class.outer",
			},
		},
		swap = {
			enable = true,
			swap_next = {
				["]a"] = "@parameter.inner",
			},
			swap_previous = {
				["[a"] = "@parameter.inner",
			},
		},
	})
end)
