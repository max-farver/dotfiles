local add_once = _G.Config.pack_add_once or _G.Config.pack_add

local obsidian_loaded = false
local warned_missing_workspace = false

local function path_exists(path)
	local uv = vim.uv or vim.loop
	local stat = uv.fs_stat(path)
	return stat and stat.type == "directory"
end

local function first_existing_path(candidates)
	for _, candidate in ipairs(candidates) do
		local expanded = vim.fn.expand(candidate)
		if expanded ~= "" and path_exists(expanded) then
			return expanded
		end
	end
	return nil
end

local function resolve_workspace_path()
	local configured = vim.g.obsidian_workspace or vim.env.OBSIDIAN_VAULT
	if type(configured) == "string" and configured ~= "" then
		return vim.fn.expand(configured)
	end

	return first_existing_path({
		"~/Documents/obsidian",
		"~/Documents/notes",
		"~/vault",
	})
end

local function find_notes_by_alias()
	local Note = require("obsidian.note")
	local mini_pick = require("mini.pick")

	local vault_dir = tostring(Obsidian.dir)
	local daily_folder = Obsidian.opts.daily_notes and Obsidian.opts.daily_notes.folder
	local files = vim.fn.globpath(vault_dir, "**/*.md", false, true)

	local items = {}
	for _, file in ipairs(files) do
		local rel_path = file:sub(#vault_dir + 2)
		if daily_folder and vim.startswith(rel_path, daily_folder .. "/") then
			goto continue
		end

		local ok, note = pcall(Note.from_file, file)
		if ok then
			local aliases = note.aliases or {}
			local text
			if #aliases > 0 then
				local dir = vim.fn.fnamemodify(rel_path, ":h")
				text = string.format("(%s) | %s/", table.concat(aliases, ", "), dir)
			else
				text = rel_path
			end

			items[#items + 1] = {
				text = text,
				path = file,
			}
		end

		::continue::
	end

	local entry = mini_pick.start({
		source = {
			name = "Find Note",
			items = items,
			choose = function() end,
		},
	})

	if entry then
		vim.cmd.edit(entry.path)
	end
end

local function setup_obsidian_keymaps()
	local nmap_leader = _G.Config.nmap_leader
	local map = _G.Config.map

	nmap_leader("o", "<nop>", "Obsidian")
	nmap_leader("o/", "<cmd>Obsidian search<cr>", "Search Notes")
	nmap_leader("of", find_notes_by_alias, "Find Note")
	nmap_leader("ob", "<cmd>Obsidian backlinks<cr>", "Backlinks")
	nmap_leader("ol", "<cmd>Obsidian links<cr>", "Links")
	nmap_leader("oT", "<cmd>Obsidian tags<cr>", "Tags")

	nmap_leader("od", "<cmd>Obsidian today<cr>", "Today's Note")
	nmap_leader("oy", "<cmd>Obsidian yesterday<cr>", "Yesterday's Note")
	nmap_leader("om", "<cmd>Obsidian tomorrow<cr>", "Tomorrow's Note")
	nmap_leader("oD", "<cmd>Obsidian dailies<cr>", "Daily Notes")

	nmap_leader("on", "<cmd>Obsidian new<cr>", "New Note")
	nmap_leader("ot", "<cmd>Obsidian template<cr>", "Insert Template")
	nmap_leader("oN", "<cmd>Obsidian new_from_template<cr>", "New from Template")
	nmap_leader("or", "<cmd>Obsidian rename<cr>", "Rename Note")
	nmap_leader("oc", "<cmd>Obsidian toc<cr>", "Table of Contents")
	nmap_leader("ox", "<cmd>Obsidian toggle_checkbox<cr>", "Toggle Checkbox")

	map("v", "<leader>oe", "<cmd>Obsidian extract_note<cr>", { desc = "Extract to Note" })
	map("v", "<leader>oL", "<cmd>Obsidian link<cr>", { desc = "Link to Note" })
	map("v", "<leader>oK", "<cmd>Obsidian link_new<cr>", { desc = "Link New Note" })
end

local function build_obsidian_opts()
	local overrides = vim.g.obsidian_opts or {}
	local has_workspace_override = type(overrides.workspaces) == "table" and #overrides.workspaces > 0

	local workspace = resolve_workspace_path()
	if not workspace and not has_workspace_override then
		return nil
	end

	local defaults = {
		picker = {
			name = "mini.pick",
		},
		legacy_commands = false,
	}

	if workspace then
		defaults.workspaces = {
			{
				name = "main",
				path = workspace,
			},
		}
	end

	return vim.tbl_deep_extend("force", defaults, overrides)
end

local function ensure_obsidian_loaded()
	if obsidian_loaded then
		return
	end

	local opts = build_obsidian_opts()
	if not opts then
		if not warned_missing_workspace then
			warned_missing_workspace = true
			vim.notify(
				"Obsidian not loaded: set vim.g.obsidian_workspace, OBSIDIAN_VAULT, or vim.g.obsidian_opts.workspaces",
				vim.log.levels.INFO
			)
		end
		return
	end

	add_once({ { src = "https://github.com/obsidian-nvim/obsidian.nvim" } })

	local ok, obsidian = pcall(require, "obsidian")
	if not ok then
		vim.notify("Failed to load obsidian.nvim", vim.log.levels.ERROR)
		return
	end

	obsidian.setup(opts)
	setup_obsidian_keymaps()
	obsidian_loaded = true
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
	group = vim.api.nvim_create_augroup("obsidian_lazy_loader", { clear = true }),
	pattern = { "*.md", "*.markdown", "*.mdx" },
	callback = ensure_obsidian_loaded,
})

vim.api.nvim_create_user_command("ObsidianLoad", ensure_obsidian_loaded, {
	desc = "Load obsidian.nvim manually",
})
