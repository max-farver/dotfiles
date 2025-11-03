return {
	'nvim-mini/mini.pick',
	version = '*',
	dependencies = { 'nvim-mini/mini.extra' },
	opts = {},
	config = function(_, opts)
		local pick_ok, pick = pcall(require, 'mini.pick')
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
				vim.notify('No items to send to quickfix', vim.log.levels.INFO)
				return false
			end
			pick.default_choose_marked(items, { list_type = 'quickfix' })
			return false
		end

		local setup_opts = vim.tbl_deep_extend('force', opts or {}, {
			mappings = {
				send_to_qf = { char = '<C-q>', func = map_send_to_qf },
			},
		})

		pick.setup(setup_opts)

		local builtin = pick.builtin or {}
		local extra_ok, extra = pcall(require, 'mini.extra')

		-- Convenience wrappers for extra pickers to match our keymaps
		builtin.lines = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.buf_lines then
				return extra.pickers.buf_lines(vim.tbl_extend('force', { scope = 'current' }, local_opts or {}))
			end
			vim.notify("mini.extra buf_lines picker not available", vim.log.levels.WARN)
		end

		builtin.diagnostics = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.diagnostic then
				return extra.pickers.diagnostic(local_opts or {})
			end
			vim.notify("mini.extra diagnostic picker not available", vim.log.levels.WARN)
		end

		-- LSP pickers
		builtin.lsp_references = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.lsp then
				return extra.pickers.lsp(vim.tbl_extend('force', { scope = 'references' }, local_opts or {}))
			end
			vim.notify("mini.extra lsp picker not available", vim.log.levels.WARN)
		end

		builtin.lsp_implementations = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.lsp then
				return extra.pickers.lsp(vim.tbl_extend('force', { scope = 'implementation' }, local_opts or {}))
			end
			vim.notify("mini.extra lsp picker not available", vim.log.levels.WARN)
		end

		builtin.lsp_definitions = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.lsp then
				return extra.pickers.lsp(vim.tbl_extend('force', { scope = 'definition' }, local_opts or {}))
			end
			vim.notify("mini.extra lsp picker not available", vim.log.levels.WARN)
		end

		builtin.lsp_type_definitions = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.lsp then
				return extra.pickers.lsp(vim.tbl_extend('force', { scope = 'type_definition' }, local_opts or {}))
			end
			vim.notify("mini.extra lsp picker not available", vim.log.levels.WARN)
		end

		builtin.lsp_code_actions = function(_)
			if vim.lsp and vim.lsp.buf and vim.lsp.buf.code_action then
				vim.lsp.buf.code_action()
				return
			end
			vim.notify("LSP code actions not available", vim.log.levels.WARN)
		end

		-- Git pickers
		builtin.git_branches = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.git_branches then
				return extra.pickers.git_branches(local_opts or {})
			end
			vim.notify("mini.extra git_branches picker not available", vim.log.levels.WARN)
		end

		builtin.git_log = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.git_commits then
				return extra.pickers.git_commits(local_opts or {})
			end
			vim.notify("mini.extra git_commits picker not available", vim.log.levels.WARN)
		end

		builtin.git_log_file = function(local_opts)
			if extra_ok and extra and extra.pickers and extra.pickers.git_commits then
				local lo = vim.tbl_extend('force', { path = '%' }, local_opts or {})
				return extra.pickers.git_commits(lo)
			end
			vim.notify("mini.extra git_commits picker not available", vim.log.levels.WARN)
		end

		builtin.git_status = function(_)
			local function postprocess(lines)
				local items = {}
				for _, line in ipairs(lines) do
					if line ~= '' then
						local status = line:sub(1, 2)
						local rest = vim.trim(line:sub(4))
						local new_path = rest:match('^.+%s->%s(.+)$') or rest
						table.insert(items, { text = status .. ' ' .. rest, path = new_path })
					end
				end
				return items
			end
			return pick.builtin.cli({
				command = { 'git', 'status', '--porcelain=v1' },
				postprocess = postprocess,
			})
		end

		builtin.git_stash = function(_)
			local function postprocess(lines)
				local items = {}
				for _, line in ipairs(lines) do
					if line ~= '' then
						table.insert(items, { text = line })
					end
				end
				return items
			end
			return pick.builtin.cli({
				command = { 'git', 'stash', 'list', '--pretty=%gd %h %s' },
				postprocess = postprocess,
			})
		end

		-- Yanky history picker
		builtin.yanky = function(local_opts)
			local ok_hist, hist = pcall(require, 'yanky.history')
			local ok_utils, utils = pcall(require, 'yanky.utils')
			if not ok_hist or not ok_utils then
				vim.notify('yanky not available', vim.log.levels.WARN)
				return
			end

			local mode = (local_opts and local_opts.mode) or 'p' -- p, P, gp, gP
			local items = {}
			for idx, entry in ipairs(hist.all()) do
				local text = entry.regcontents or ''
				local first = vim.split(text, '\n', { plain = true })[1] or ''
				local tag = entry.regtype or ''
				local summary = string.format('%3d: %s%s', idx, first, (#first < #text) and ' …' or '')
				table.insert(items, { text = summary, _entry = entry })
			end

			local source = {
				items = items,
				name = 'Yank History',
				preview = function(buf_id, item)
					if not item or not item._entry then
						vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { '' })
						return
					end
					local lines = vim.split(item._entry.regcontents or '', '\n', { plain = true })
					vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
				end,
				choose = function(item)
					if not item or not item._entry then
						return
					end
					local register = utils.get_default_register()
					utils.use_temporary_register(register, item._entry, function()
						local cmd
						if register ~= '"' then
							cmd = string.format('silent normal! "%s%s', register, mode)
						else
							cmd = string.format('silent normal! %s', mode)
						end
						local ok, err = pcall(vim.cmd, cmd)
						if not ok then
							vim.notify(err, vim.log.levels.WARN)
						end
					end)
				end,
			}

			pick.start({ source = source })
		end

		-- write back modified builtin
		pick.builtin = builtin
	end,
}
