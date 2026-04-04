-- Local machine-specific overrides
-- This file is intentionally gitignored.

local uname = (vim.uv or vim.loop).os_uname()
local is_linux = uname and uname.sysname == "Linux"

if is_linux then
	vim.g.obsidian_workspace = "~/Documents/obsidian/Personal"
else
	vim.g.obsidian_workspace = "~/Documents/misc/obsidian/Default"
	vim.g.obsidian_opts = {
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
end
