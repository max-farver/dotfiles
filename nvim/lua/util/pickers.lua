local M = {}

function M.register(pick)
	local builtin = pick.builtin or {}
	local extra_ok, extra = pcall(require, "mini.extra")

	builtin.lines = function(local_opts)
		if extra_ok and extra and extra.pickers and extra.pickers.buf_lines then
			return extra.pickers.buf_lines(vim.tbl_extend("force", { scope = "current" }, local_opts or {}))
		end
		vim.notify("mini.extra buf_lines picker not available", vim.log.levels.WARN)
	end

	builtin.diagnostics = function(local_opts)
		if extra_ok and extra and extra.pickers and extra.pickers.diagnostic then
			return extra.pickers.diagnostic(local_opts or {})
		end
		vim.notify("mini.extra diagnostic picker not available", vim.log.levels.WARN)
	end

	builtin.lsp_code_actions = function(_)
		if vim.lsp and vim.lsp.buf and vim.lsp.buf.code_action then
			vim.lsp.buf.code_action()
			return
		end
		vim.notify("LSP code actions not available", vim.log.levels.WARN)
	end

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
			local lo = vim.tbl_extend("force", { path = "%" }, local_opts or {})
			return extra.pickers.git_commits(lo)
		end
		vim.notify("mini.extra git_commits picker not available", vim.log.levels.WARN)
	end

	builtin.git_status = function(_)
		local function postprocess(lines)
			local items = {}
			for _, line in ipairs(lines) do
				if line ~= "" then
					local status = line:sub(1, 2)
					local rest = vim.trim(line:sub(4))
					local new_path = rest:match("^.+%s->%s(.+)$") or rest
					table.insert(items, { text = status .. " " .. rest, path = new_path })
				end
			end
			return items
		end
		return pick.builtin.cli({
			command = { "git", "status", "--porcelain=v1" },
			postprocess = postprocess,
		})
	end

	builtin.git_stash = function(_)
		local function postprocess(lines)
			local items = {}
			for _, line in ipairs(lines) do
				if line ~= "" then
					table.insert(items, { text = line })
				end
			end
			return items
		end
		return pick.builtin.cli({
			command = { "git", "stash", "list", "--pretty=%gd %h %s" },
			postprocess = postprocess,
		})
	end

	builtin.notifications = function(_)
		local ok_notify, mini_notify = pcall(require, "mini.notify")
		if not ok_notify or not mini_notify or type(mini_notify.get_all) ~= "function" then
			vim.notify("mini.notify history not available", vim.log.levels.WARN)
			return
		end

		local history = mini_notify.get_all() or {}
		if vim.tbl_isempty(history) then
			vim.notify("No notifications recorded", vim.log.levels.INFO)
			return
		end

		local notif_arr = {}
		for id, notif in pairs(history) do
			if notif and notif.msg then
				table.insert(notif_arr, { id = id, notif = notif })
			end
		end

		if #notif_arr == 0 then
			vim.notify("No notifications recorded", vim.log.levels.INFO)
			return
		end

		table.sort(notif_arr, function(a, b)
			local ts_a = a.notif.ts_update or a.notif.ts_add or 0
			local ts_b = b.notif.ts_update or b.notif.ts_add or 0
			if ts_a == ts_b then
				return a.id > b.id
			end
			return ts_a > ts_b
		end)

		local items = {}
		for _, entry in ipairs(notif_arr) do
			local notif = entry.notif
			local lines = vim.split(notif.msg or "", "\n", { plain = true })
			if #lines == 0 then
				lines = { "" }
			end
			local ts = math.floor(notif.ts_update or notif.ts_add or 0)
			local short_ts = vim.fn.strftime("%H:%M:%S", ts)
			local full_ts = vim.fn.strftime("%Y-%m-%d %H:%M:%S", ts)
			local level = notif.level or "INFO"
			local summary = lines[1]
			if #lines > 1 then
				summary = summary .. " …"
			end
			table.insert(items, {
				text = string.format("%s %-5s %s", short_ts, level, summary),
				_lines = lines,
				_ts = full_ts,
				_level = level,
				_msg = notif.msg or "",
				_source = notif.data and notif.data.source or "",
				_id = entry.id,
			})
		end

		local source = {
			name = "Notifications",
			items = items,
			preview = function(buf_id, item)
				if not item then
					vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { "" })
					return
				end
				local lines = vim.deepcopy(item._lines)
				table.insert(lines, 1, string.format("#%d [%s] %s", item._id, item._level, item._ts))
				if item._source ~= "" then
					table.insert(lines, 2, "source: " .. item._source)
				end
				vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
			end,
			choose = function(item)
				if not item then
					return
				end
				local level = vim.log.levels[item._level] or vim.log.levels.INFO
				vim.notify(item._msg, level)
			end,
		}

		pick.start({ source = source })
	end

	builtin.yanky = function(local_opts)
		local ok_hist, hist = pcall(require, "yanky.history")
		local ok_utils, utils = pcall(require, "yanky.utils")
		if not ok_hist or not ok_utils then
			vim.notify("yanky not available", vim.log.levels.WARN)
			return
		end

		local mode = (local_opts and local_opts.mode) or "p"
		local items = {}
		for idx, entry in ipairs(hist.all()) do
			local text = entry.regcontents or ""
			local first = vim.split(text, "\n", { plain = true })[1] or ""
			local summary = string.format("%3d: %s%s", idx, first, (#first < #text) and " …" or "")
			table.insert(items, { text = summary, _entry = entry })
		end

		local source = {
			items = items,
			name = "Yank History",
			preview = function(buf_id, item)
				if not item or not item._entry then
					vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { "" })
					return
				end
				local lines = vim.split(item._entry.regcontents or "", "\n", { plain = true })
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
						cmd = string.format("silent normal! %s", mode)
					end
					local ok_cmd, err = pcall(vim.cmd, cmd)
					if not ok_cmd then
						vim.notify(err, vim.log.levels.WARN)
					end
				end)
			end,
		}

		pick.start({ source = source })
	end

	pick.builtin = builtin
end

return M
