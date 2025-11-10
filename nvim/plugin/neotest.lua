local add = MiniDeps.add
local now, later = MiniDeps.now, MiniDeps.later
local icons = _G.Config.icons
local os_cfg = _G.Config.os
local project = _G.Config.project
local nmap = _G.Config.nmap
local nmap_leader = _G.Config.nmap_leader

later(function()
	add("mfussenegger/nvim-dap")
	add("theHamsta/nvim-dap-virtual-text")

	if not os_cfg.is_linux then
		add({
			source = "jay-babu/mason-nvim-dap.nvim",
			depends = { "williamboman/mason.nvim" },
		})
	end

	local ok_mason, mason_dap = pcall(require, "mason-nvim-dap")
	if ok_mason then
		mason_dap.setup({ automatic_installation = true, handlers = {}, ensure_installed = {} })
	end

	local ok_virtual, virtual = pcall(require, "nvim-dap-virtual-text")
	if ok_virtual then
		virtual.setup({})
	end

	vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

	for name, sign in pairs(icons.dap) do
		local text, texthl, linehl, numhl
		if type(sign) == "table" then
			text, texthl, linehl, numhl = sign[1], sign[2], sign[3], sign[4]
		else
			text = sign
		end
		vim.fn.sign_define("Dap" .. name, {
			text = text,
			texthl = texthl or "DiagnosticInfo",
			linehl = linehl,
			numhl = numhl,
		})
	end


	local dap = require('dap')
	nmap('<leader>dB', function()
		dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
	end, 'Breakpoint Condition')
	nmap('<leader>db', function()
		dap.toggle_breakpoint()
	end, 'Toggle Breakpoint')
	nmap('<leader>dl', function()
		dap.run_last()
	end, 'Run Last')
	nmap('<leader>ds', function()
		dap.session()
	end, 'Session')
	nmap('<leader>dt', function()
		dap.terminate()
	end, 'Terminate')
end)

now(function()
	add({
		source = "miroshQa/debugmaster.nvim",
		depends = { "mfussenegger/nvim-dap", "jbyuki/one-small-step-for-vimkind" },
	})
	local dm = require("debugmaster")
	dm.plugins.osv_integration.enabled = true

	nmap_leader('dd', function()
		dm.mode.toggle()
	end, 'Toggle Debug Mode')
end)

later(function()
	add({
		source = "andythigpen/nvim-coverage",
		depends = { "nvim-lua/plenary.nvim" },
	})
	require("coverage").setup({
		auto_reload = true,
		lang = {
			go = {
				coverage_file = vim.fn.getcwd() .. "/coverage.out",
			},
		},
	})
end)

now(function()
	add({
		source = "nvim-neotest/neotest",
		depends = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/neotest-plenary",
			"nvim-neotest/neotest-vim-test",
		}
	})

	local default_opts = {
		discovery = { enabled = true, concurrent = 1 },
		running = { concurrent = true },
		summary = { animated = true },
		log_level = vim.log.levels.WARN,
		adapters = {},
	}
	local opts = project.merge_plugin_opts("nvim-neotest/neotest", default_opts)

	local neotest_ns = vim.api.nvim_create_namespace("neotest")
	vim.diagnostic.config({
		virtual_text = {
			format = function(diagnostic)
				local message = diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
				return message
			end,
		},
	}, neotest_ns)

	if package.loaded["trouble"] then
		opts.consumers = opts.consumers or {}
		opts.consumers.trouble = function(client)
			client.listeners.results = function(adapter_id, results, partial)
				if partial then
					return
				end
				local tree = assert(client:get_position(nil, { adapter = adapter_id }))
				local failed = 0
				for pos_id, result in pairs(results) do
					if result.status == "failed" and tree:get_key(pos_id) then
						failed = failed + 1
					end
				end
				vim.schedule(function()
					local trouble = require("trouble")
					if trouble.is_open() then
						trouble.refresh()
						if failed == 0 then
							trouble.close()
						end
					end
				end)
				return {}
			end
		end
	end

	add({
		source = "fredrikaverpil/neotest-golang",
		depends = {
			"leoluz/nvim-dap-go",
			"uga-rosa/utf8.nvim",
		},
	})
	opts.adapters = {
		require('neotest-golang')({})
	}
	require('neotest').setup(opts)


	-- nmap_leader('t', '<nop>', '+test')
	nmap_leader('tt', function()
		require('neotest').run.run(vim.fn.expand '%')
	end, 'Run File')
	nmap_leader('tT', function()
		require('neotest').run.run(vim.uv.cwd())
	end, 'Run All Files')
	nmap_leader('tr', function()
		require('neotest').run.run()
	end, 'Run Nearest')
	nmap_leader('tl', function()
		require('neotest').run.run_last()
	end, 'Run Last')
	nmap_leader('ts', function()
		require('neotest').summary.toggle()
	end, 'Toggle Summary')
	nmap_leader('to', function()
		require('neotest').output.open { enter = true, auto_close = true }
	end, 'Show Output')
	nmap_leader('tO', function()
		require('neotest').output_panel.toggle()
	end, 'Toggle Output Panel')
	nmap_leader('tS', function()
		require('neotest').run.stop()
	end, 'Stop Tests')
	nmap_leader('tw', function()
		require('neotest').watch.toggle(vim.fn.expand '%')
	end, 'Toggle Watch')
	nmap_leader('td', function()
		require('neotest').run.run { strategy = 'dap' }
	end, 'Debug Nearest')
end)
