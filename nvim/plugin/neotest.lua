local add = _G.Config.pack_add
local now, later = _G.Config.now, _G.Config.later
local icons = _G.Config.icons
local os_cfg = _G.Config.os
local project = _G.Config.project
local nmap = _G.Config.nmap
local nmap_leader = _G.Config.nmap_leader

later(function()
	add({ { src = "https://github.com/mfussenegger/nvim-dap" } })
	add({ { src = "https://github.com/theHamsta/nvim-dap-virtual-text" } })

	if not os_cfg.is_linux then
		add({
			{ src = "https://github.com/williamboman/mason.nvim" },
			{ src = "https://github.com/jay-babu/mason-nvim-dap.nvim" },
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

later(function()
	add({
		{ src = "https://github.com/mfussenegger/nvim-dap" },
		{ src = "https://github.com/jbyuki/one-small-step-for-vimkind" },
		{ src = "https://github.com/miroshQa/debugmaster.nvim" },
	})
	local dm = require("debugmaster")
	dm.plugins.osv_integration.enabled = true

	nmap_leader('dd', function()
		dm.mode.toggle()
	end, 'Toggle Debug Mode')
end)

later(function()
	add({
		{ src = "https://github.com/nvim-lua/plenary.nvim" },
		{ src = "https://github.com/andythigpen/nvim-coverage" },
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

later(function()
	add({
		{ src = "https://github.com/nvim-neotest/nvim-nio" },
		{ src = "https://github.com/nvim-lua/plenary.nvim" },
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
		{ src = "https://github.com/nvim-neotest/neotest" },
	})

	local default_opts = {
		discovery = { enabled = false, concurrent = 0 },
		running = { concurrent = true },
		-- summary = { animated = true },
		log_level = vim.log.levels.WARN,
		status = { virtual_text = true },
		output = { open_on_run = false },
		quickfix = { enabled = false },
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

	add({
		{ src = "https://github.com/leoluz/nvim-dap-go" },
		{ src = "https://github.com/uga-rosa/utf8.nvim" },
		{ src = "https://github.com/fredrikaverpil/neotest-golang" },
	})
	add({
		{ src = "https://github.com/olimorris/neotest-rspec" },
		{ src = "https://github.com/nvim-neotest/neotest" },
	})
	opts.adapters = {
		require('neotest-golang')({
			go_test_args = function()
				return {
					'-v',
					'-race',
					'-coverprofile=' .. vim.fn.getcwd() .. '/coverage.out',
					vim.env.GO_TEST_FLAGS or '',
				}
			end,
			dap_go_opts = {
				delve = {
					build_flags = { '-tags=unit,integration,endtoendtest' },
				},
			},
			runner = 'gotestsum',
			gotestsum_args = { '--format=standard-verbose' },
			testify_enabled = true,
			log_level = vim.log.levels.TRACE,

			-- experimental
			dev_notifications = true,
		}),
		require("neotest-rspec")
	}
	require('neotest').setup(opts)


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
