local add = MiniDeps.add
local now, later = MiniDeps.now, MiniDeps.later
local icons = _G.Config.icons
local nmap_leader = _G.Config.nmap_leader
local map = _G.Config.map

later(function()
	add("lewis6991/gitsigns.nvim")
	require("gitsigns").setup({
		signs = {
			add = { text = icons.git.added },
			change = { text = icons.git.modified },
			delete = { text = icons.git.removed },
			topdelete = { text = icons.git.removed },
			changedelete = { text = icons.git.modified },
		},
		current_line_blame = true,
		preview_config = {
			border = "rounded",
		},
	})

	local function with_gitsigns(fn)
		return function(...)
			local ok, gs = pcall(require, 'gitsigns')
			if not ok then
				vim.notify('gitsigns not available', vim.log.levels.WARN)
				return
			end
			if type(gs[fn]) == 'function' then
				gs[fn](...)
			end
		end
	end

	-- group header
	nmap_leader('g', '<nop>', '+git')

	-- hunk actions
	map('n', '<leader>gs', with_gitsigns 'stage_hunk', { desc = 'Stage Hunk' })
	map('n', '<leader>gr', with_gitsigns 'reset_hunk', { desc = 'Reset Hunk' })
	map('v', '<leader>gs', with_gitsigns 'stage_hunk', { desc = 'Stage Hunk' })
	map('v', '<leader>gr', with_gitsigns 'reset_hunk', { desc = 'Reset Hunk' })
	map('n', '<leader>gu', with_gitsigns 'undo_stage_hunk', { desc = 'Undo Stage Hunk' })
	map('n', '<leader>gS', with_gitsigns 'stage_buffer', { desc = 'Stage Buffer' })
	map('n', '<leader>gR', with_gitsigns 'reset_buffer', { desc = 'Reset Buffer' })
	map('n', '<leader>gp', with_gitsigns 'preview_hunk', { desc = 'Preview Hunk' })

	-- navigation
	map('n', '<leader>gj', with_gitsigns 'next_hunk', { desc = 'Next Hunk' })
	map('n', '<leader>gk', with_gitsigns 'prev_hunk', { desc = 'Prev Hunk' })

	-- toggles and info
	map('n', '<leader>gb', with_gitsigns 'blame_line', { desc = 'Blame Line' })
	map('n', '<leader>gB', with_gitsigns 'toggle_current_line_blame', { desc = 'Toggle Blame' })
	map('n', '<leader>gt', with_gitsigns 'toggle_deleted', { desc = 'Toggle Deleted' })

	-- diff
	map('n', '<leader>gd', with_gitsigns 'diffthis', { desc = 'Diff This' })
	map('n', '<leader>gD', function()
		with_gitsigns 'diffthis' '~'
	end, { desc = 'Diff This (~)' })

	-- select hunk
	map({ 'n', 'v' }, '<leader>gh', with_gitsigns 'select_hunk', { desc = 'Select Hunk' })
end)

later(function()
	add("sindrets/diffview.nvim")
	require("diffview").setup({
		enhanced_diff_hl = true,
	})
end)

later(function()
	add({
		source = "ruifm/gitlinker.nvim",
		depends = { "nvim-lua/plenary.nvim" },
	})
	require("gitlinker").setup({
		mappings = false,
	})


	local function gl_action(action)
		return function()
			local ok, gitlinker = pcall(require, 'gitlinker')
			if not ok then
				vim.notify('gitlinker not available', vim.log.levels.WARN)
				return
			end
			local actions_ok, actions = pcall(require, 'gitlinker.actions')
			if not actions_ok then
				vim.notify('gitlinker.actions not available', vim.log.levels.WARN)
				return
			end
			local cb = (action == 'open') and actions.open_in_browser or actions.copy_to_clipboard
			-- Detect the current mode: 'v' for visual/visual-line, 'n' for normal
			local mode = vim.fn.mode():match('[vV\22]') and 'v' or 'n'
			gitlinker.get_buf_range_url(mode, { action_callback = cb })
		end
	end

	-- open remote in browser
	map({ 'n', 'x' }, '<leader>go', gl_action('open'), { desc = 'Git Browse (open)' })

	-- copy remote URL to clipboard
	map({ 'n', 'x' }, '<leader>gy', gl_action('copy'), { desc = 'Git Browse (copy)' })
end)
