local add_once = _G.Config.pack_add_once or _G.Config.pack_add
local later = _G.Config.later
local icons = _G.Config.icons
local os_cfg = _G.Config.os
local project = _G.Config.project
local nmap = _G.Config.nmap
local nmap_leader = _G.Config.nmap_leader

local neotest_registry = require("util.neotest")

local function with_neotest(fn)
	return function()
		local ok, neotest = pcall(require, "neotest")
		if not ok then
			vim.notify("neotest is not available", vim.log.levels.WARN)
			return
		end
		fn(neotest)
	end
end

later(function()
	add_once({
		{ src = "https://github.com/mfussenegger/nvim-dap" },
		{ src = "https://github.com/theHamsta/nvim-dap-virtual-text" },
	})

	if not os_cfg.is_linux then
		add_once({
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

	local dap = require("dap")
	nmap("<leader>dB", function()
		dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
	end, "Breakpoint Condition")
	nmap("<leader>db", function()
		dap.toggle_breakpoint()
	end, "Toggle Breakpoint")
	nmap("<leader>dl", function()
		dap.run_last()
	end, "Run Last")
	nmap("<leader>ds", function()
		dap.session()
	end, "Session")
	nmap("<leader>dt", function()
		dap.terminate()
	end, "Terminate")
end)

later(function()
	add_once({
		{ src = "https://github.com/mfussenegger/nvim-dap" },
		{ src = "https://github.com/jbyuki/one-small-step-for-vimkind" },
		{ src = "https://github.com/miroshQa/debugmaster.nvim" },
	})
	local dm = require("debugmaster")
	dm.plugins.osv_integration.enabled = true

	nmap_leader("dd", function()
		dm.mode.toggle()
	end, "Toggle Debug Mode")
end)

later(function()
	add_once({
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
	add_once({
		{ src = "https://github.com/nvim-neotest/nvim-nio" },
		{ src = "https://github.com/nvim-lua/plenary.nvim" },
		{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
		{ src = "https://github.com/nvim-neotest/neotest" },
	})

	local default_opts = {
		discovery = { enabled = false, concurrent = 0 },
		running = { concurrent = true },
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

	neotest_registry.setup(opts)

	nmap_leader("tt", with_neotest(function(neotest)
		neotest.run.run(vim.fn.expand("%"))
	end), "Run File")
	nmap_leader("tT", with_neotest(function(neotest)
		neotest.run.run(vim.uv.cwd())
	end), "Run All Files")
	nmap_leader("tr", with_neotest(function(neotest)
		neotest.run.run()
	end), "Run Nearest")
	nmap_leader("tl", with_neotest(function(neotest)
		neotest.run.run_last()
	end), "Run Last")
	nmap_leader("ts", with_neotest(function(neotest)
		neotest.summary.toggle()
	end), "Toggle Summary")
	nmap_leader("to", with_neotest(function(neotest)
		neotest.output.open({ enter = true, auto_close = true })
	end), "Show Output")
	nmap_leader("tO", with_neotest(function(neotest)
		neotest.output_panel.toggle()
	end), "Toggle Output Panel")
	nmap_leader("tS", with_neotest(function(neotest)
		neotest.run.stop()
	end), "Stop Tests")
	nmap_leader("tw", with_neotest(function(neotest)
		neotest.watch.toggle(vim.fn.expand("%"))
	end), "Toggle Watch")
	nmap_leader("td", with_neotest(function(neotest)
		neotest.run.run({ strategy = "dap" })
	end), "Debug Nearest")
end)
