local add = MiniDeps.add
local now = MiniDeps.now
local os_cfg = _G.Config.os
local project = _G.Config.project

local function find_notes_by_alias()
	local Note = require("obsidian.note")
	local mini_pick = require("mini.pick")

	local vault_dir = tostring(Obsidian.dir)
	local daily_folder = Obsidian.opts.daily_notes.folder
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
				text = "(" .. table.concat(aliases, ", ") .. ") | " .. dir .. "/"
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


	nmap_leader('o', '<nop>', 'Obsidian')
	-- Navigation & Search
	nmap_leader("o/", "<cmd>Obsidian search<cr>", "Search Notes")
	nmap_leader("of", find_notes_by_alias, "Find Note")
	nmap_leader("ob", "<cmd>Obsidian backlinks<cr>", "Backlinks")
	nmap_leader("ol", "<cmd>Obsidian links<cr>", "Links")
	nmap_leader("oT", "<cmd>Obsidian tags<cr>", "Tags")

	-- Daily notes
	nmap_leader("od", "<cmd>Obsidian today<cr>", "Today's Note")
	nmap_leader("oy", "<cmd>Obsidian yesterday<cr>", "Yesterday's Note")
	nmap_leader("om", "<cmd>Obsidian tomorrow<cr>", "Tomorrow's Note")
	nmap_leader("oD", "<cmd>Obsidian dailies<cr>", "Daily Notes")

	-- Note operations
	nmap_leader("on", "<cmd>Obsidian new<cr>", "New Note")
	nmap_leader("ot", "<cmd>Obsidian template<cr>", "Insert Template")
	nmap_leader("oN", "<cmd>Obsidian new_from_template<cr>", "New from Template")
	nmap_leader("or", "<cmd>Obsidian rename<cr>", "Rename Note")
	nmap_leader("oc", "<cmd>Obsidian toc<cr>", "Table of Contents")
	nmap_leader("ox", "<cmd>Obsidian toggle_checkbox<cr>", "Toggle Checkbox")
	-- nmap_leader("op", "<cmd>Obsidian paste_img<cr>", "Paste image")

	-- Visual mode
	map("v", "<leader>oe", "<cmd>Obsidian extract_note<cr>", { desc = "Extract to Note" })
	map("v", "<leader>oL", "<cmd>Obsidian link<cr>", { desc = "Link to Note" })
	map("v", "<leader>oK", "<cmd>Obsidian link_new<cr>", { desc = "Link New Note" })
end

now(function()
	if os_cfg.is_linux then
		add({
			source = "obsidian-nvim/obsidian.nvim",
		})
		local obsidian_opts = {
			workspaces = {
				{
					name = "personal",
					path = vim.fn.expand("~") .. "/Documents/obsidian/Personal",
				},
			},
			picker = {
				name = "mini.pick",
			},
			legacy_commands = false,
		}
		require("obsidian").setup(obsidian_opts)
		setup_obsidian_keymaps()
	else
		add({
			source = "obsidian-nvim/obsidian.nvim",
		})
		local obsidian_opts = {
			workspaces = {
				{
					name = "personal",
					path = vim.fn.expand("~") .. "/Documents/misc/obsidian/Default",
				},
			},
			picker = {
				name = "mini.pick",
			},
			legacy_commands = false,
			templates = {
				folder = "Templates/nvim",
				date_format = "%Y-%m-%d",
				time_format = "%H:%M",
				substitutions = {
					yesterday = function()
						return os.date("%Y-%m-%d", os.time() - 86400)
					end,
					tomorrow = function()
						return os.date("%Y-%m-%d", os.time() + 86400)
					end,
					weekday = function()
						return os.date("%A")
					end,
				},
				customizations = {
					["Meeting Note"] = { notes_subdir = "Spaces/Meetings" },
					["Thought"] = { notes_subdir = "Spaces/Random" },
					["Person"] = { notes_subdir = "Spaces/People" },
					["Jira Ticket"] = { notes_subdir = "Spaces/Jira" },
					["Interview"] = { notes_subdir = "Spaces/Docs" },
					["TDD"] = { notes_subdir = "Spaces/Docs" },
					["User Guide"] = { notes_subdir = "Spaces/Docs" },
					["Setup Guide"] = { notes_subdir = "Spaces/Docs" },
					["Operation Guide"] = { notes_subdir = "Spaces/Docs" },
					["Runbook"] = { notes_subdir = "Spaces/Docs" },
				},
			},
		}
		require("obsidian").setup(obsidian_opts)
		setup_obsidian_keymaps()
	end
end)
